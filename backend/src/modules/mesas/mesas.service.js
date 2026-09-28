const db = require('../../db');
const repositorio = require('./mesas.repository');
const AppError = require('../../utils/AppError');

async function listarMesas(restaurante) {
  return repositorio.listarMesas(restaurante.id);
}

async function criarMesa(restaurante, dados) {
  return repositorio.criarMesa(restaurante.id, dados);
}

/**
 * RN-MESA-001: abrir sessao = ocupar a mesa.
 * RN-MESA-002: uma mesa nao pode ter duas sessoes abertas ao mesmo tempo
 *              (garantido tambem por indice unico parcial no banco).
 * RN-MESA-003: mesa interditada nao recebe sessao.
 */
async function abrirSessao(restaurante, mesaId, usuario, { qtdPessoas }) {
  const mesa = await repositorio.buscarMesa(restaurante.id, mesaId);
  if (!mesa || !mesa.ativo) throw AppError.naoEncontrado('Mesa');

  if (mesa.status === 'interditada') {
    throw AppError.regraDeNegocio('Esta mesa esta interditada.');
  }

  const jaAberta = await repositorio.sessaoAbertaDaMesa(restaurante.id, mesaId);
  if (jaAberta) {
    throw AppError.conflito('Esta mesa ja possui uma comanda aberta.');
  }

  if (qtdPessoas && qtdPessoas > mesa.capacidade) {
    throw AppError.regraDeNegocio(
      `A mesa ${mesa.numero} comporta ate ${mesa.capacidade} pessoas.`
    );
  }

  return db.transacao((cliente) =>
    repositorio.abrirSessao(cliente, {
      restauranteId: restaurante.id,
      mesaId,
      usuarioId: usuario.id,
      qtdPessoas,
    })
  );
}

async function detalharSessao(restaurante, sessaoId) {
  const sessao = await repositorio.buscarSessao(restaurante.id, sessaoId);
  if (!sessao) throw AppError.naoEncontrado('Comanda');

  const conta = await repositorio.contaDaSessao(restaurante.id, sessaoId);
  return { sessao, ...conta };
}

/**
 * RN-MESA-004: a comanda so fecha quando TODOS os pedidos dela estiverem
 * pagos e nenhum estiver em producao. Fechar libera a mesa (via trigger).
 */
async function fecharSessao(restaurante, sessaoId, usuario) {
  const sessao = await repositorio.buscarSessao(restaurante.id, sessaoId);
  if (!sessao) throw AppError.naoEncontrado('Comanda');
  if (sessao.status !== 'aberta') {
    throw AppError.conflito('Esta comanda ja foi encerrada.');
  }

  const { rows: pendencias } = await db.query(
    `select
        count(*) filter (where status_pagamento <> 'pago')             as nao_pagos,
        count(*) filter (where status in ('rascunho','confirmado','em_preparo','pronto')) as em_aberto
       from pedidos
      where restaurante_id = $1 and sessao_mesa_id = $2 and status <> 'cancelado'`,
    [restaurante.id, sessaoId]
  );

  const { nao_pagos: naoPagos, em_aberto: emAberto } = pendencias[0];

  if (Number(naoPagos) > 0) {
    throw AppError.regraDeNegocio(
      `Ainda ha ${naoPagos} pedido(s) sem pagamento confirmado nesta mesa.`,
      'CONTA_EM_ABERTO'
    );
  }
  if (Number(emAberto) > 0) {
    throw AppError.regraDeNegocio(
      `Ainda ha ${emAberto} pedido(s) em producao nesta mesa.`,
      'PEDIDO_EM_PRODUCAO'
    );
  }

  return db.transacao(async (cliente) => {
    const fechada = await repositorio.fecharSessao(cliente, {
      restauranteId: restaurante.id,
      sessaoId,
      usuarioId: usuario.id,
      status: 'fechada',
    });
    if (!fechada) throw AppError.conflito('Comanda ja encerrada por outro atendente.');
    return fechada;
  });
}

/**
 * RN-CAL-005: a taxa de servico (10%) e FACULTATIVA. O cliente pode recusar
 * e o valor precisa sair da conta imediatamente.
 */
async function definirServico(restaurante, sessaoId, aceito) {
  const sessao = await repositorio.definirServicoAceito(restaurante.id, sessaoId, aceito);
  if (!sessao) throw AppError.naoEncontrado('Comanda aberta');

  // Recalcula todos os pedidos da comanda que ainda nao foram pagos.
  await db.transacao(async (cliente) => {
    const { rows } = await cliente.query(
      `select id from pedidos
        where sessao_mesa_id = $1 and status <> 'cancelado' and status_pagamento <> 'pago'`,
      [sessaoId]
    );
    for (const pedido of rows) {
      await cliente.query('select recalcular_pedido($1)', [pedido.id]);
    }
  });

  return sessao;
}

module.exports = {
  listarMesas,
  criarMesa,
  abrirSessao,
  detalharSessao,
  fecharSessao,
  definirServico,
};
