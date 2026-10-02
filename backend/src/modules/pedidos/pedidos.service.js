const db = require('../../db');
const repositorio = require('./pedidos.repository');
const maquina = require('./pedidos.maquinaDeEstados');
const AppError = require('../../utils/AppError');

// Status em que o pedido ainda aceita novos itens (RN-PED-005).
const ACEITA_ITENS = ['rascunho'];
const ACEITA_ITENS_MESA = ['rascunho', 'confirmado', 'em_preparo'];

/** O perfil efetivo: membro da equipe ou 'cliente'. */
function perfilDe(req) {
  return req.perfil || 'cliente';
}

/** RN-SEG-006: cliente so enxerga o proprio pedido. */
function assegurarAcesso(pedido, req) {
  const perfil = perfilDe(req);

  if (perfil !== 'cliente') return;

  if (!pedido.cliente_id || pedido.cliente_id !== req.usuario.id) {
    throw AppError.proibido('Este pedido nao pertence a voce.');
  }
}

// ---------------------------------------------------------------------
// Criacao
// ---------------------------------------------------------------------

/**
 * RN-PED-002: cada tipo exige um vinculo diferente.
 *   mesa     -> comanda aberta (sessao)
 *   delivery -> endereco do cliente
 *   retirada -> nenhum vinculo
 *
 * RN-PED-004: o restaurante precisa aceitar aquele tipo de pedido
 * e estar aberto.
 */
async function criar(restaurante, req, dados) {
  const perfil = perfilDe(req);

  if (!restaurante.aberto) {
    throw AppError.regraDeNegocio(
      'O restaurante esta fechado no momento.',
      'RESTAURANTE_FECHADO'
    );
  }

  const aceita = {
    mesa: restaurante.aceita_mesa,
    delivery: restaurante.aceita_delivery,
    retirada: restaurante.aceita_retirada,
  };

  if (!aceita[dados.tipo]) {
    throw AppError.regraDeNegocio(
      `Este restaurante nao aceita pedidos de ${dados.tipo}.`
    );
  }

  // ============================================================
  // PEDIDO DE MESA
  // ============================================================
  //
  // O cliente pode criar um pedido de mesa SOMENTE quando
  // possuir uma sessao/comanda valida e aberta.
  //
  // A reserva feita pelo aplicativo retorna sessaoMesaId.
  // Essa sessao precisa existir no restaurante e continuar aberta.
  // ============================================================

  if (dados.tipo === 'mesa') {
    if (!dados.sessaoMesaId) {
      throw AppError.regraDeNegocio(
        'Selecione e reserve uma mesa antes de fazer o pedido.',
        'SESSAO_MESA_OBRIGATORIA'
      );
    }

    const { rows } = await db.query(
      `select id, mesa_id, status
         from sessoes_mesa
        where restaurante_id = $1
          and id = $2`,
      [restaurante.id, dados.sessaoMesaId]
    );

    const sessao = rows[0];

    if (!sessao) {
      throw AppError.naoEncontrado('Comanda');
    }

    if (sessao.status !== 'aberta') {
      throw AppError.regraDeNegocio(
        'A comanda desta mesa nao esta aberta.',
        'SESSAO_MESA_FECHADA'
      );
    }
  }

  // ============================================================
  // DELIVERY
  // ============================================================

  if (dados.tipo === 'delivery' && dados.enderecoId) {
    const { rows } = await db.query(
      `select id
         from enderecos
        where id = $1
          and usuario_id = $2
          and ativo = true`,
      [
        dados.enderecoId,
        dados.clienteId || req.usuario.id,
      ]
    );

    if (!rows[0]) {
      throw AppError.naoEncontrado(
        'Endereco de entrega'
      );
    }
  }

  const canal =
    perfil === 'cliente'
      ? 'app_cliente'
      : perfil === 'garcom'
        ? 'garcom'
        : 'balcao';

  return db.transacao(async (cliente) => {
    const pedido = await repositorio.criar(cliente, {
      restauranteId: restaurante.id,

      // Cliente logado sempre fica vinculado ao proprio pedido.
      // Isso tambem vale para pedidos de mesa.
      clienteId:
        perfil === 'cliente'
          ? req.usuario.id
          : dados.clienteId || null,

      criadoPor: req.usuario.id,
      sessaoMesaId: dados.sessaoMesaId,
      enderecoId: dados.enderecoId,
      tipo: dados.tipo,
      canal,
      observacao: dados.observacao,
    });

    return pedido;
  });
}

// ---------------------------------------------------------------------
// Itens
// ---------------------------------------------------------------------

async function adicionarItem(restaurante, pedidoId, req, dados) {
  const perfil = perfilDe(req);

  return db.transacao(async (cliente) => {
    const pedido =
      await repositorio.buscarParaAtualizar(
        cliente,
        restaurante.id,
        pedidoId
      );

    if (!pedido) {
      throw AppError.naoEncontrado('Pedido');
    }

    assegurarAcesso(pedido, req);

    const permitidos =
      pedido.tipo === 'mesa'
        ? ACEITA_ITENS_MESA
        : ACEITA_ITENS;

    if (!permitidos.includes(pedido.status)) {
      throw AppError.regraDeNegocio(
        `Nao e possivel adicionar itens a um pedido com status "${pedido.status}".`,
        'PEDIDO_FECHADO_PARA_ITENS'
      );
    }

    if (pedido.status_pagamento === 'pago') {
      throw AppError.regraDeNegocio(
        'Este pedido ja foi pago. Abra um novo pedido para itens adicionais.',
        'PEDIDO_PAGO'
      );
    }

    // RN-PED-006: preco e nome sao congelados no momento da inclusao.
    const { rows } = await cliente.query(
      `select id, nome, preco, ativo, disponivel
         from produtos
        where restaurante_id = $1
          and id = $2
        for share`,
      [restaurante.id, dados.produtoId]
    );

    const produto = rows[0];

    if (!produto || !produto.ativo) {
      throw AppError.naoEncontrado('Produto');
    }

    if (!produto.disponivel) {
      throw AppError.regraDeNegocio(
        `"${produto.nome}" esta indisponivel no momento.`,
        'INDISPONIVEL'
      );
    }

    // Item entra ja enviado a cozinha quando o pedido esta em producao.
    const statusItem =
      pedido.status === 'rascunho'
        ? 'pendente'
        : 'enviado_cozinha';

    const item = await repositorio.inserirItem(cliente, {
      restauranteId: restaurante.id,
      pedidoId: pedido.id,
      produtoId: produto.id,
      produtoNome: produto.nome,
      precoUnitario: produto.preco,
      quantidade: dados.quantidade,
      observacao: dados.observacao,
      status: statusItem,
    });

    await repositorio.recalcular(
      cliente,
      pedido.id
    );

    const atualizado =
      await repositorio.buscarParaAtualizar(
        cliente,
        restaurante.id,
        pedido.id
      );

    return {
      item,
      pedido: atualizado,
      perfil,
    };
  });
}

async function atualizarItem(
  restaurante,
  pedidoId,
  itemId,
  req,
  dados
) {
  return db.transacao(async (cliente) => {
    const pedido =
      await repositorio.buscarParaAtualizar(
        cliente,
        restaurante.id,
        pedidoId
      );

    if (!pedido) {
      throw AppError.naoEncontrado('Pedido');
    }

    assegurarAcesso(pedido, req);

    const item =
      await repositorio.buscarItem(
        cliente,
        pedidoId,
        itemId
      );

    if (!item) {
      throw AppError.naoEncontrado('Item');
    }

    if (item.status === 'cancelado') {
      throw AppError.regraDeNegocio(
        'Este item ja foi cancelado.'
      );
    }

    // RN-PED-007: item que ja esta pronto/entregue
    // nao muda de quantidade.
    if (
      ['pronto', 'entregue'].includes(
        item.status
      )
    ) {
      throw AppError.regraDeNegocio(
        'O item ja foi preparado e nao pode ser alterado. Cancele-o com autorizacao do gerente.',
        'ITEM_EM_PRODUCAO'
      );
    }

    const atualizado =
      await repositorio.atualizarItem(
        cliente,
        itemId,
        dados
      );

    await repositorio.recalcular(
      cliente,
      pedidoId
    );

    return atualizado;
  });
}

/**
 * RN-PED-009: cancelar item que ja foi para a cozinha exige perfil
 * de gerente (evita "sumir" com consumo). Motivo e obrigatorio.
 */
async function cancelarItem(
  restaurante,
  pedidoId,
  itemId,
  req,
  motivo
) {
  const perfil = perfilDe(req);

  return db.transacao(async (cliente) => {
    const pedido =
      await repositorio.buscarParaAtualizar(
        cliente,
        restaurante.id,
        pedidoId
      );

    if (!pedido) {
      throw AppError.naoEncontrado('Pedido');
    }

    assegurarAcesso(pedido, req);

    const item =
      await repositorio.buscarItem(
        cliente,
        pedidoId,
        itemId
      );

    if (!item) {
      throw AppError.naoEncontrado('Item');
    }

    if (item.status === 'cancelado') {
      return item;
    }

    const jaFoiParaCozinha =
      item.status !== 'pendente';

    if (
      jaFoiParaCozinha &&
      perfil !== 'gerente'
    ) {
      throw AppError.proibido(
        'Item ja enviado a cozinha. O cancelamento precisa ser feito pelo gerente.'
      );
    }

    const cancelado =
      await repositorio.cancelarItem(
        cliente,
        itemId,
        req.usuario.id,
        motivo
      );

    await repositorio.recalcular(
      cliente,
      pedidoId
    );

    return cancelado;
  });
}

// ---------------------------------------------------------------------
// Confirmacao e status
// ---------------------------------------------------------------------

/**
 * Confirmar = fechar o carrinho e mandar o pedido para o restaurante.
 *
 * RN-PED-012: pedido sem item nao pode ser confirmado.
 * RN-CAL-002: pedido minimo de delivery e verificado aqui.
 * RN-CAL-003: taxa de entrega e calculada aqui.
 *
 * REGRA DO APP:
 *
 * Pedido de retirada confirmado pelo cliente entra
 * automaticamente em "em_preparo".
 *
 * O cliente NAO recebe permissao para alterar livremente
 * o status do pedido.
 */
async function confirmar(restaurante, pedidoId, req) {
  const perfil = perfilDe(req);

  return db.transacao(async (cliente) => {
    const pedido =
      await repositorio.buscarParaAtualizar(
        cliente,
        restaurante.id,
        pedidoId
      );

    if (!pedido) {
      throw AppError.naoEncontrado('Pedido');
    }

    assegurarAcesso(pedido, req);

    // A confirmacao continua sendo validada pela maquina
    // de estados como rascunho -> confirmado.
    maquina.validarTransicao(
      pedido,
      'confirmado',
      perfil
    );

    // ---------------------------------------------------------
    // Validar se existem itens
    // ---------------------------------------------------------

    const { rows: contagem } =
      await cliente.query(
        `select count(*)::int as qtd
           from pedido_itens
          where pedido_id = $1
            and status <> 'cancelado'`,
        [pedidoId]
      );

    if (contagem[0].qtd === 0) {
      throw AppError.regraDeNegocio(
        'Adicione ao menos um item antes de confirmar.',
        'PEDIDO_VAZIO'
      );
    }

    // ---------------------------------------------------------
    // Recalcular pedido
    // ---------------------------------------------------------

    await repositorio.recalcular(
      cliente,
      pedidoId
    );

    const comTotais =
      await repositorio.buscarParaAtualizar(
        cliente,
        restaurante.id,
        pedidoId
      );

    // ---------------------------------------------------------
    // Delivery
    // ---------------------------------------------------------

    if (comTotais.tipo === 'delivery') {
      if (!comTotais.endereco_id) {
        throw AppError.regraDeNegocio(
          'Escolha um endereco de entrega.',
          'ENDERECO_OBRIGATORIO'
        );
      }

      if (
        Number(comTotais.subtotal) <
        Number(
          restaurante.pedido_minimo_delivery
        )
      ) {
        throw AppError.regraDeNegocio(
          `O pedido minimo para delivery e de R$ ${Number(
            restaurante.pedido_minimo_delivery
          ).toFixed(2)}.`,
          'PEDIDO_MINIMO'
        );
      }

      const limiteFreteGratis =
        restaurante.frete_gratis_acima_de;

      const taxa =
        limiteFreteGratis !== null &&
        Number(comTotais.subtotal) >=
          Number(limiteFreteGratis)
          ? 0
          : Number(
              restaurante
                .taxa_entrega_padrao
            );

      await repositorio.definirTaxaEntrega(
        cliente,
        pedidoId,
        taxa,
        45
      );
    }

    // ---------------------------------------------------------
    // Enviar itens para cozinha
    // ---------------------------------------------------------

    await repositorio.enviarItensParaCozinha(
      cliente,
      pedidoId
    );

    // ---------------------------------------------------------
    // Status inicial depois da confirmacao
    // ---------------------------------------------------------
    //
    // Retirada feita pelo cliente:
    //
    // rascunho
    //    ↓
    // confirmar
    //    ↓
    // em_preparo
    //
    // O cliente nao chama alterarStatus().
    //
    // Depois o gerente podera:
    //
    // em_preparo -> pronto
    // pronto -> concluido
    // ---------------------------------------------------------

    const statusAposConfirmacao =
      comTotais.tipo === 'retirada' &&
      perfil === 'cliente'
        ? 'em_preparo'
        : 'confirmado';

    const atualizado =
      await repositorio.atualizarStatus(
        cliente,
        pedidoId,
        {
          status:
            statusAposConfirmacao,
          alteradoPor:
            req.usuario.id,
        }
      );

    return atualizado;
  });
}

async function alterarStatus(
  restaurante,
  pedidoId,
  req,
  { status, motivo }
) {
  const perfil = perfilDe(req);

  return db.transacao(async (cliente) => {
    const pedido =
      await repositorio.buscarParaAtualizar(
        cliente,
        restaurante.id,
        pedidoId
      );

    if (!pedido) {
      throw AppError.naoEncontrado(
        'Pedido'
      );
    }

    assegurarAcesso(
      pedido,
      req
    );

    maquina.validarTransicao(
      pedido,
      status,
      perfil
    );

    if (
      status === 'cancelado' &&
      !motivo
    ) {
      throw AppError.regraDeNegocio(
        'Informe o motivo do cancelamento.',
        'MOTIVO_OBRIGATORIO'
      );
    }

    // RN-PED-013: cancelar pedido pago exige
    // estorno antes (gerente).
    if (
      status === 'cancelado' &&
      pedido.status_pagamento === 'pago'
    ) {
      throw AppError.regraDeNegocio(
        'Este pedido esta pago. Estorne o pagamento antes de cancelar.',
        'ESTORNO_NECESSARIO'
      );
    }

    const atualizado =
      await repositorio.atualizarStatus(
        cliente,
        pedidoId,
        {
          status,
          alteradoPor:
            req.usuario.id,
          motivo,
        }
      );

    if (
      status === 'concluido' ||
      status === 'cancelado'
    ) {
      await cliente.query(
        `update pedido_itens
            set status =
              case
                when status = 'cancelado'
                  then status
                when $2 = 'concluido'
                  then 'entregue'::item_status
                else 'cancelado'::item_status
              end,
                motivo_cancelamento =
              case
                when status <> 'cancelado'
                     and $2 = 'cancelado'
                  then coalesce(
                    motivo_cancelamento,
                    'Pedido cancelado'
                  )
                else motivo_cancelamento
              end
          where pedido_id = $1`,
        [
          pedidoId,
          status,
        ]
      );
    }

    return atualizado;
  });
}

// ---------------------------------------------------------------------
// Consultas
// ---------------------------------------------------------------------

async function detalhar(
  restaurante,
  pedidoId,
  req
) {
  const pedido =
    await repositorio.buscar(
      restaurante.id,
      pedidoId
    );

  if (!pedido) {
    throw AppError.naoEncontrado(
      'Pedido'
    );
  }

  assegurarAcesso(
    pedido,
    req
  );

  const [
    itens,
    historico,
  ] = await Promise.all([
    repositorio.listarItens(
      pedidoId
    ),
    repositorio.listarHistorico(
      pedidoId
    ),
  ]);

  return {
    ...pedido,
    itens,
    historico,
  };
}

async function listar(
  restaurante,
  req,
  filtros
) {
  const perfil = perfilDe(req);

  if (perfil === 'cliente') {
    return repositorio.listar(
      restaurante.id,
      {
        ...filtros,
        clienteId:
          req.usuario.id,
      }
    );
  }

  return repositorio.listar(
    restaurante.id,
    filtros
  );
}

async function meusPedidos(
  usuarioId
) {
  return repositorio.listarDoCliente(
    usuarioId
  );
}

// ---------------------------------------------------------------------
// Cozinha (KDS)
// ---------------------------------------------------------------------

const FLUXO_ITEM = {
  pendente: [
    'enviado_cozinha',
    'cancelado',
  ],
  enviado_cozinha: [
    'em_preparo',
    'pronto',
    'cancelado',
  ],
  em_preparo: [
    'pronto',
    'cancelado',
  ],
  pronto: [
    'entregue',
    'cancelado',
  ],
  entregue: [],
  cancelado: [],
};

async function filaCozinha(
  restaurante
) {
  return repositorio.filaCozinha(
    restaurante.id
  );
}

/**
 * RN-KDS-002: quando todos os itens ficam prontos,
 * o pedido inteiro avanca para "pronto" automaticamente.
 */
async function alterarStatusItem(
  restaurante,
  itemId,
  novoStatus,
  req
) {
  return db.transacao(async (cliente) => {
    const { rows } =
      await cliente.query(
        `select *
           from pedido_itens
          where restaurante_id = $1
            and id = $2
          for update`,
        [
          restaurante.id,
          itemId,
        ]
      );

    const item =
      rows[0];

    if (!item) {
      throw AppError.naoEncontrado(
        'Item'
      );
    }

    const permitidos =
      FLUXO_ITEM[item.status] || [];

    if (
      !permitidos.includes(
        novoStatus
      )
    ) {
      throw AppError.regraDeNegocio(
        `Transicao invalida do item: ${item.status} -> ${novoStatus}.`,
        'TRANSICAO_INVALIDA'
      );
    }

    const atualizado =
      await repositorio.atualizarStatusItem(
        cliente,
        restaurante.id,
        itemId,
        novoStatus
      );

    const pedido =
      await repositorio.buscarParaAtualizar(
        cliente,
        restaurante.id,
        item.pedido_id
      );

    const { rows: resumo } =
      await cliente.query(
        `select
           count(*) filter (
             where status not in (
               'pronto',
               'entregue',
               'cancelado'
             )
           )::int as pendentes,
           count(*) filter (
             where status <> 'cancelado'
           )::int as validos
         from pedido_itens
        where pedido_id = $1`,
        [item.pedido_id]
      );

    if (
      novoStatus === 'em_preparo' &&
      pedido.status === 'confirmado'
    ) {
      await repositorio.atualizarStatus(
        cliente,
        pedido.id,
        {
          status:
            'em_preparo',
          alteradoPor:
            req.usuario.id,
        }
      );
    }

    if (
      resumo[0].pendentes === 0 &&
      resumo[0].validos > 0 &&
      [
        'confirmado',
        'em_preparo',
      ].includes(
        pedido.status
      )
    ) {
      await repositorio.atualizarStatus(
        cliente,
        pedido.id,
        {
          status:
            'pronto',
          alteradoPor:
            req.usuario.id,
        }
      );
    }

    return atualizado;
  });
}

// ---------------------------------------------------------------------
// EXPORTS
// ---------------------------------------------------------------------

module.exports = {
  criar,
  adicionarItem,
  atualizarItem,
  cancelarItem,
  confirmar,
  alterarStatus,
  detalhar,
  listar,
  meusPedidos,
  filaCozinha,
  alterarStatusItem,
  FLUXO_ITEM,
};