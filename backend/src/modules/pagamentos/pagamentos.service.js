const db = require('../../db');
const AppError = require('../../utils/AppError');

/**
 * =====================================================================
 * Pagamento (provedor "mock", pronto para trocar por Pix/Mercado Pago)
 * =====================================================================
 * O ciclo financeiro e SEPARADO do ciclo de producao do pedido:
 *
 *   pendente ──aprovar──> aprovado ──estornar──> estornado
 *      │
 *      ├──recusar──> recusado
 *      └──cancelar──> cancelado
 *
 * pedidos.status_pagamento e derivado da soma dos pagamentos aprovados:
 *   0                      -> nao_iniciado / pendente
 *   0 < aprovado < total   -> parcial   (conta dividida)
 *   aprovado >= total      -> pago
 */

const METODOS_NA_HORA = ['dinheiro', 'na_entrega', 'no_local'];

/** Recalcula pedidos.status_pagamento a partir dos pagamentos aprovados. */
async function sincronizarStatusPagamento(cliente, pedidoId) {
  const { rows } = await cliente.query(
    `select p.total,
            coalesce(sum(pg.valor) filter (where pg.status = 'aprovado'), 0)  as aprovado,
            coalesce(sum(pg.valor) filter (where pg.status = 'pendente'), 0)  as pendente,
            coalesce(sum(pg.valor) filter (where pg.status = 'estornado'), 0) as estornado
       from pedidos p
       left join pagamentos pg on pg.pedido_id = p.id
      where p.id = $1
      group by p.total`,
    [pedidoId]
  );

  const { total, aprovado, pendente, estornado } = rows[0];
  let status = 'nao_iniciado';

  if (Number(aprovado) > 0 && Number(aprovado) >= Number(total)) status = 'pago';
  else if (Number(aprovado) > 0) status = 'parcial';
  else if (Number(pendente) > 0) status = 'pendente';
  else if (Number(estornado) > 0) status = 'estornado';

  await cliente.query('update pedidos set status_pagamento = $2 where id = $1', [pedidoId, status]);
  return status;
}

/**
 * RN-PAG-001: nao se cobra pedido em rascunho (o valor ainda pode mudar).
 * RN-PAG-002: a soma dos pagamentos nao pode ultrapassar o total do pedido.
 * RN-PAG-006: idempotencia -- reenviar a mesma chave devolve o mesmo pagamento
 *             em vez de criar uma segunda cobranca.
 */
async function criar(restaurante, pedidoId, req, dados) {
  return db.transacao(async (cliente) => {
    const { rows: pedidos } = await cliente.query(
      'select * from pedidos where restaurante_id = $1 and id = $2 for update',
      [restaurante.id, pedidoId]
    );
    const pedido = pedidos[0];
    if (!pedido) throw AppError.naoEncontrado('Pedido');

    const perfil = req.perfil || 'cliente';
    if (perfil === 'cliente' && pedido.cliente_id !== req.usuario.id) {
      throw AppError.proibido('Este pedido nao pertence a voce.');
    }

    if (pedido.status === 'rascunho') {
      throw AppError.regraDeNegocio(
        'Confirme o pedido antes de iniciar o pagamento.',
        'PEDIDO_EM_RASCUNHO'
      );
    }
    if (pedido.status === 'cancelado') {
      throw AppError.regraDeNegocio('Pedido cancelado nao pode receber pagamento.');
    }
    if (pedido.status_pagamento === 'pago') {
      throw AppError.conflito('Este pedido ja esta pago.');
    }

    if (dados.idempotencyKey) {
      const { rows } = await cliente.query(
        'select * from pagamentos where restaurante_id = $1 and idempotency_key = $2',
        [restaurante.id, dados.idempotencyKey]
      );
      if (rows[0]) return { pagamento: rows[0], reaproveitado: true };
    }

    const { rows: somas } = await cliente.query(
      `select coalesce(sum(valor) filter (where status in ('aprovado','pendente')), 0) as comprometido
         from pagamentos where pedido_id = $1`,
      [pedidoId]
    );

    const restante = Number(pedido.total) - Number(somas[0].comprometido);
    const valor = dados.valor ?? Number(restante.toFixed(2));

    if (valor <= 0) {
      throw AppError.regraDeNegocio('Nao ha saldo em aberto neste pedido.', 'SEM_SALDO');
    }
    if (valor > restante + 0.001) {
      throw AppError.regraDeNegocio(
        `O valor excede o saldo em aberto (R$ ${restante.toFixed(2)}).`,
        'VALOR_EXCEDE_TOTAL'
      );
    }
    if (dados.metodo === 'dinheiro' && dados.trocoPara && dados.trocoPara < valor) {
      throw AppError.regraDeNegocio('O valor para troco e menor que o valor a pagar.');
    }

    // Simulacao do provedor: um Pix real devolveria QR Code e id da cobranca.
    const ehPix = dados.metodo === 'pix';
    const { rows } = await cliente.query(
      `insert into pagamentos (restaurante_id, pedido_id, metodo, valor, troco_para,
                               provedor, provedor_pagamento_id, idempotency_key,
                               qr_code, registrado_por, status)
       values ($1, $2, $3, $4, $5, 'mock', $6, $7, $8, $9, 'pendente')
       returning *`,
      [
        restaurante.id,
        pedidoId,
        dados.metodo,
        valor,
        dados.trocoPara ?? null,
        `mock_${Date.now()}`,
        dados.idempotencyKey || null,
        ehPix ? `00020126580014BR.GOV.BCB.PIX-MOCK-${pedidoId.slice(0, 8)}` : null,
        req.usuario.id,
      ]
    );

    await sincronizarStatusPagamento(cliente, pedidoId);
    return { pagamento: rows[0], reaproveitado: false };
  });
}

/**
 * RN-PAG-003: no mundo real quem aprova e o webhook do provedor.
 * Aqui a aprovacao e manual (mock), mas o efeito colateral e o mesmo:
 * atualiza o pagamento e sincroniza o status financeiro do pedido.
 * Pagamentos "na hora" (dinheiro/na entrega/no local) so podem ser
 * aprovados pela equipe, nunca pelo proprio cliente (RN-PAG-004).
 */
async function confirmar(restaurante, pagamentoId, req) {
  return db.transacao(async (cliente) => {
    const { rows } = await cliente.query(
      'select * from pagamentos where restaurante_id = $1 and id = $2 for update',
      [restaurante.id, pagamentoId]
    );
    const pagamento = rows[0];
    if (!pagamento) throw AppError.naoEncontrado('Pagamento');

    if (pagamento.status !== 'pendente') {
      throw AppError.conflito(`Pagamento ja esta ${pagamento.status}.`);
    }

    const perfil = req.perfil || 'cliente';
    if (METODOS_NA_HORA.includes(pagamento.metodo) && perfil === 'cliente') {
      throw AppError.proibido(
        'Pagamento em dinheiro/no local e confirmado pela equipe do restaurante.'
      );
    }

    const { rows: atualizados } = await cliente.query(
      `update pagamentos
          set status = 'aprovado', aprovado_em = now(),
              resposta_provedor = jsonb_build_object('mock', true, 'confirmado_por', $2::text)
        where id = $1
        returning *`,
      [pagamentoId, req.usuario.id]
    );

    const statusPedido = await sincronizarStatusPagamento(cliente, pagamento.pedido_id);
    return { pagamento: atualizados[0], statusPagamentoPedido: statusPedido };
  });
}

/** RN-PAG-005: estorno e privativo do gerente e sempre exige motivo. */
async function estornar(restaurante, pagamentoId, req, motivo) {
  return db.transacao(async (cliente) => {
    const { rows } = await cliente.query(
      'select * from pagamentos where restaurante_id = $1 and id = $2 for update',
      [restaurante.id, pagamentoId]
    );
    const pagamento = rows[0];
    if (!pagamento) throw AppError.naoEncontrado('Pagamento');
    if (pagamento.status !== 'aprovado') {
      throw AppError.regraDeNegocio('Somente pagamento aprovado pode ser estornado.');
    }

    const { rows: atualizados } = await cliente.query(
      `update pagamentos
          set status = 'estornado',
              resposta_provedor = coalesce(resposta_provedor, '{}'::jsonb)
                || jsonb_build_object('estorno_motivo', $2::text, 'estornado_por', $3::text)
        where id = $1
        returning *`,
      [pagamentoId, motivo, req.usuario.id]
    );

    await sincronizarStatusPagamento(cliente, pagamento.pedido_id);
    return atualizados[0];
  });
}

async function listar(restaurante, pedidoId) {
  const { rows } = await db.query(
    `select id, metodo, status, valor, troco_para, provedor, provedor_pagamento_id,
            qr_code, criado_em, aprovado_em
       from pagamentos
      where restaurante_id = $1 and pedido_id = $2
      order by criado_em`,
    [restaurante.id, pedidoId]
  );
  return rows;
}

module.exports = { criar, confirmar, estornar, listar, sincronizarStatusPagamento };
