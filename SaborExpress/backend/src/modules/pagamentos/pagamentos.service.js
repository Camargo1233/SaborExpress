
const db = require('../../db');
const AppError = require('../../utils/AppError');

// SaborExpress - pagamentos demonstrativos.
// Nenhuma integracao bancaria e utilizada.

const METODOS_NA_HORA = [
  'dinheiro',
  'na_entrega',
  'no_local',
];

function verificarDono(pedido, req) {
  const perfil = req.perfil || 'cliente';

  if (
    perfil === 'cliente' &&
    pedido.cliente_id !== req.usuario.id
  ) {
    throw AppError.proibido(
      'Este pedido nao pertence a voce.'
    );
  }
}

// Atualiza o status financeiro do pedido.
async function sincronizarStatusPagamento(cliente, pedidoId) {
  const { rows } = await cliente.query(
    `SELECT p.total,
       COALESCE(SUM(pg.valor)
         FILTER (WHERE pg.status = 'aprovado'), 0) AS aprovado,
       COALESCE(SUM(pg.valor)
         FILTER (WHERE pg.status = 'pendente'), 0) AS pendente,
       COALESCE(SUM(pg.valor)
         FILTER (WHERE pg.status = 'estornado'), 0) AS estornado
     FROM pedidos p
     LEFT JOIN pagamentos pg ON pg.pedido_id = p.id
     WHERE p.id = $1
     GROUP BY p.total`,
    [pedidoId]
  );

  if (!rows.length) {
    throw AppError.naoEncontrado('Pedido');
  }

  const { total, aprovado, pendente, estornado } = rows[0];

  let status = 'nao_iniciado';

  if (
    Number(aprovado) >= Number(total) &&
    Number(aprovado) > 0
  ) {
    status = 'pago';
  } else if (Number(aprovado) > 0) {
    status = 'parcial';
  } else if (Number(pendente) > 0) {
    status = 'pendente';
  } else if (Number(estornado) > 0) {
    status = 'estornado';
  }

  await cliente.query(
    `UPDATE pedidos
     SET status_pagamento = $2
     WHERE id = $1`,
    [pedidoId, status]
  );

  return status;
}

// Cria um pagamento demonstrativo, inclusive Pix.
async function criar(restaurante, pedidoId, req, dados) {
  return db.transacao(async (cliente) => {
    const { rows: pedidos } = await cliente.query(
      `SELECT * FROM pedidos
       WHERE restaurante_id = $1 AND id = $2
       FOR UPDATE`,
      [restaurante.id, pedidoId]
    );

    const pedido = pedidos[0];

    if (!pedido) {
      throw AppError.naoEncontrado('Pedido');
    }

    verificarDono(pedido, req);

    // Permite preparar o pagamento antes da
    // confirmacao do pedido.
    if (pedido.status === 'cancelado') {
      throw AppError.regraDeNegocio(
        'Pedido cancelado nao pode receber pagamento.'
      );
    }

    // Reaproveita pagamentos demonstrativos existentes.
    if (dados.idempotencyKey) {
      const { rows } = await cliente.query(
        `SELECT * FROM pagamentos
         WHERE restaurante_id = $1
           AND idempotency_key = $2`,
        [restaurante.id, dados.idempotencyKey]
      );

      if (rows[0]) {
        const existente = rows[0];

        if (
          existente.pedido_id !== pedidoId ||
          existente.metodo !== dados.metodo ||
          (
            dados.valor !== undefined &&
            Number(existente.valor) !== Number(dados.valor)
          )
        ) {
          throw AppError.conflito(
            'Chave de idempotencia usada em outro pagamento.'
          );
        }

        if (existente.provedor !== 'mock') {
          throw AppError.conflito(
            'Existe uma cobranca de outro provedor. ' +
            'Utilize um novo pedido de teste.'
          );
        }

        return {
          pagamento: existente,
          reaproveitado: true,
        };
      }
    }

    if (pedido.status_pagamento === 'pago') {
      throw AppError.conflito(
        'Este pedido ja esta pago.'
      );
    }

    // Verifica se o pedido possui produtos.
    const { rows: itens } = await cliente.query(
      `SELECT COUNT(*)::int AS quantidade
       FROM pedido_itens
       WHERE pedido_id = $1
         AND status <> 'cancelado'`,
      [pedidoId]
    );

    if (itens[0].quantidade === 0) {
      throw AppError.regraDeNegocio(
        'Adicione produtos antes de iniciar o pagamento.'
      );
    }

    const { rows: valores } = await cliente.query(
      `SELECT total
       FROM pedidos
       WHERE id = $1`,
      [pedidoId]
    );

    const totalPedido = Number(valores[0].total);

    if (!Number.isFinite(totalPedido) || totalPedido <= 0) {
      throw AppError.regraDeNegocio(
        'O pedido nao possui um total valido.'
      );
    }

    const { rows: somas } = await cliente.query(
      `SELECT COALESCE(
         SUM(valor) FILTER (
           WHERE status IN ('aprovado', 'pendente')
         ), 0
       ) AS comprometido
       FROM pagamentos
       WHERE pedido_id = $1`,
      [pedidoId]
    );

    const restante =
      totalPedido - Number(somas[0].comprometido);

    const valor = dados.valor === undefined
      ? Number(restante.toFixed(2))
      : Number(dados.valor);

    if (!Number.isFinite(valor) || valor <= 0) {
      throw AppError.regraDeNegocio(
        'Nao ha saldo valido para pagamento.'
      );
    }

    if (valor > restante + 0.001) {
      throw AppError.regraDeNegocio(
        'Valor excede o saldo restante.'
      );
    }

    if (
      dados.metodo === 'dinheiro' &&
      dados.trocoPara != null &&
      Number(dados.trocoPara) < valor
    ) {
      throw AppError.regraDeNegocio(
        'Valor para troco menor que o pagamento.'
      );
    }

    // Nenhuma cobranca real e realizada.
    const { rows } = await cliente.query(
      `INSERT INTO pagamentos (
         restaurante_id,
         pedido_id,
         metodo,
         valor,
         troco_para,
         provedor,
         idempotency_key,
         qr_code,
         registrado_por,
         status,
         resposta_provedor
       )
       VALUES (
         $1, $2, $3, $4, $5,
         'mock', $6, NULL, $7,
         'pendente',
         jsonb_build_object(
           'mock', true,
           'demonstrativo', true
         )
       )
       RETURNING *`,
      [
        restaurante.id,
        pedidoId,
        dados.metodo,
        valor,
        dados.trocoPara ?? null,
        dados.idempotencyKey || null,
        req.usuario.id,
      ]
    );

    const statusPedido =
      await sincronizarStatusPagamento(cliente, pedidoId);

    return {
      pagamento: rows[0],
      reaproveitado: false,
      statusPagamentoPedido: statusPedido,
    };
  });
}

// Mantem compatibilidade com chamadas existentes.
async function criarPix(restaurante, pedidoId, req, dados) {
  return criar(restaurante, pedidoId, req, {
    ...dados,
    metodo: 'pix',
  });
}

// Consulta o status do Pix demonstrativo.
async function consultarStatusPix(restaurante, pagamentoId, req) {
  const { rows } = await db.query(
    `SELECT pg.*, p.cliente_id,
            p.status_pagamento
     FROM pagamentos pg
     JOIN pedidos p ON p.id = pg.pedido_id
     WHERE pg.restaurante_id = $1
       AND pg.id = $2`,
    [restaurante.id, pagamentoId]
  );

  const pagamento = rows[0];

  if (!pagamento) {
    throw AppError.naoEncontrado('Pagamento');
  }

  verificarDono(pagamento, req);

  if (
    pagamento.provedor !== 'mock' ||
    pagamento.metodo !== 'pix'
  ) {
    throw AppError.regraDeNegocio(
      'Este pagamento nao e um Pix demonstrativo.'
    );
  }

  const { status_pagamento, ...dadosPagamento } = pagamento;

  return {
    pagamento: dadosPagamento,
    statusPagamentoPedido: status_pagamento,
  };
}

// Confirma somente pagamentos demonstrativos.
async function confirmar(restaurante, pagamentoId, req) {
  return db.transacao(async (cliente) => {
    const { rows } = await cliente.query(
      `SELECT pg.*, p.cliente_id
       FROM pagamentos pg
       JOIN pedidos p ON p.id = pg.pedido_id
       WHERE pg.restaurante_id = $1
         AND pg.id = $2
       FOR UPDATE OF pg`,
      [restaurante.id, pagamentoId]
    );

    const pagamento = rows[0];

    if (!pagamento) {
      throw AppError.naoEncontrado('Pagamento');
    }

    verificarDono(pagamento, req);

    // Impede aprovacao manual de cobrancas reais.
    if (pagamento.provedor !== 'mock') {
      throw AppError.proibido(
        'Somente pagamentos demonstrativos ' +
        'podem ser confirmados manualmente.'
      );
    }

    if (pagamento.status !== 'pendente') {
      throw AppError.conflito(
        `Pagamento ja esta ${pagamento.status}.`
      );
    }

    const perfil = req.perfil || 'cliente';

    // Dinheiro e pagamento presencial precisam
    // ser confirmados pela equipe.
    if (
      METODOS_NA_HORA.includes(pagamento.metodo) &&
      perfil === 'cliente'
    ) {
      throw AppError.proibido(
        'Pagamento em dinheiro/no local ' +
        'deve ser confirmado pela equipe.'
      );
    }

    const { rows: atualizados } = await cliente.query(
      `UPDATE pagamentos
       SET status = 'aprovado',
           aprovado_em = NOW(),
           resposta_provedor = jsonb_build_object(
             'mock', true,
             'demonstrativo', true,
             'confirmado_por', $2::text
           )
       WHERE id = $1
       RETURNING *`,
      [pagamentoId, req.usuario.id]
    );

    const statusPedido =
      await sincronizarStatusPagamento(
        cliente,
        pagamento.pedido_id
      );

    return {
      pagamento: atualizados[0],
      statusPagamentoPedido: statusPedido,
    };
  });
}

// Estorno de pagamento demonstrativo.
async function estornar(restaurante, pagamentoId, req, motivo) {
  return db.transacao(async (cliente) => {
    const { rows } = await cliente.query(
      `SELECT pg.*, p.cliente_id
       FROM pagamentos pg
       JOIN pedidos p ON p.id = pg.pedido_id
       WHERE pg.restaurante_id = $1
         AND pg.id = $2
       FOR UPDATE OF pg`,
      [restaurante.id, pagamentoId]
    );

    const pagamento = rows[0];

    if (!pagamento) {
      throw AppError.naoEncontrado('Pagamento');
    }

    if (pagamento.provedor !== 'mock') {
      throw AppError.proibido(
        'Estorno de cobranca externa deve ' +
        'ser realizado pelo provedor.'
      );
    }

    if (pagamento.status !== 'aprovado') {
      throw AppError.regraDeNegocio(
        'Somente pagamento aprovado pode ser estornado.'
      );
    }

    // Somente o gerente pode estornar.
    if (req.perfil !== 'gerente') {
      throw AppError.proibido(
        'Somente o gerente pode estornar pagamentos.'
      );
    }

    if (!motivo || !String(motivo).trim()) {
      throw AppError.regraDeNegocio(
        'Informe o motivo do estorno.'
      );
    }

    const { rows: atualizados } = await cliente.query(
      `UPDATE pagamentos
       SET status = 'estornado',
           resposta_provedor =
             COALESCE(resposta_provedor, '{}'::jsonb)
             || jsonb_build_object(
               'estorno_motivo', $2::text,
               'estornado_por', $3::text
             )
       WHERE id = $1
       RETURNING *`,
      [pagamentoId, motivo, req.usuario.id]
    );

    await sincronizarStatusPagamento(
      cliente,
      pagamento.pedido_id
    );

    return atualizados[0];
  });
}

// Lista os pagamentos vinculados ao pedido.
async function listar(restaurante, pedidoId, req) {
  const { rows: pedidos } = await db.query(
    `SELECT cliente_id
     FROM pedidos
     WHERE restaurante_id = $1
       AND id = $2`,
    [restaurante.id, pedidoId]
  );

  const pedido = pedidos[0];

  if (!pedido) {
    throw AppError.naoEncontrado('Pedido');
  }

  verificarDono(pedido, req);

  const { rows } = await db.query(
    `SELECT id,
            metodo,
            status,
            valor,
            troco_para,
            provedor,
            provedor_pagamento_id,
            qr_code,
            criado_em,
            aprovado_em
     FROM pagamentos
     WHERE restaurante_id = $1
       AND pedido_id = $2
     ORDER BY criado_em`,
    [restaurante.id, pedidoId]
  );

  return rows;
}

module.exports = {
  criar,
  criarPix,
  confirmar,
  estornar,
  listar,
  consultarStatusPix,
  sincronizarStatusPagamento,
};
