
const db = require('../../db');
const repositorio = require('./mesas.repository');
const AppError = require('../../utils/AppError');

// ============================================================
// LISTAR MESAS - EQUIPE
// ============================================================

async function listarMesas(restaurante) {
  return repositorio.listarMesas(restaurante.id);
}

// ============================================================
// LISTAR MESAS DISPONÍVEIS - CLIENTE
// ============================================================

async function listarMesasDisponiveis(restaurante) {
  return repositorio.listarMesasDisponiveis(restaurante.id);
}

// ============================================================
// CRIAR MESA - GERENTE
// ============================================================

async function criarMesa(restaurante, dados) {
  return repositorio.criarMesa(restaurante.id, dados);
}

// ============================================================
// ABRIR COMANDA - EQUIPE
// ============================================================

async function abrirSessao(
  restaurante,
  mesaId,
  usuario,
  { qtdPessoas }
) {
  const mesa = await repositorio.buscarMesa(
    restaurante.id,
    mesaId
  );

  if (!mesa || !mesa.ativo) {
    throw AppError.naoEncontrado('Mesa');
  }

  if (mesa.status === 'interditada') {
    throw AppError.regraDeNegocio(
      'Esta mesa está interditada.'
    );
  }

  const jaAberta = await repositorio.sessaoAbertaDaMesa(
    restaurante.id,
    mesaId
  );

  if (jaAberta) {
    throw AppError.conflito(
      'Esta mesa já possui uma comanda aberta.'
    );
  }

  if (qtdPessoas && qtdPessoas > mesa.capacidade) {
    throw AppError.regraDeNegocio(
      `A mesa ${mesa.numero} comporta até ${mesa.capacidade} pessoas.`
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

// ============================================================
// CLIENTE - SELECIONAR MESA E ABRIR COMANDA
// ============================================================

async function selecionarMesaCliente(
  restaurante,
  mesaId,
  usuario,
  { qtdPessoas }
) {
  if (!Number.isInteger(qtdPessoas) || qtdPessoas < 1) {
    throw AppError.regraDeNegocio(
      'Informe uma quantidade válida de pessoas.'
    );
  }

  const mesa = await repositorio.buscarMesa(
    restaurante.id,
    mesaId
  );

  if (!mesa || !mesa.ativo) {
    throw AppError.naoEncontrado('Mesa');
  }

  if (mesa.status !== 'livre') {
    throw AppError.conflito(
      'Esta mesa não está disponível.'
    );
  }

  if (qtdPessoas > mesa.capacidade) {
    throw AppError.regraDeNegocio(
      `A mesa ${mesa.numero} comporta até ${mesa.capacidade} pessoas.`
    );
  }

  const jaAberta = await repositorio.sessaoAbertaDaMesa(
    restaurante.id,
    mesaId
  );

  if (jaAberta) {
    throw AppError.conflito(
      'Esta mesa já está ocupada.'
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

// ============================================================
// DETALHAR COMANDA
// ============================================================

async function detalharSessao(restaurante, sessaoId) {
  const sessao = await repositorio.buscarSessao(
    restaurante.id,
    sessaoId
  );

  if (!sessao) {
    throw AppError.naoEncontrado('Comanda');
  }

  const conta = await repositorio.contaDaSessao(
    restaurante.id,
    sessaoId
  );

  return {
    sessao,
    ...conta,
  };
}

// ============================================================
// FECHAR COMANDA
// ============================================================

async function fecharSessao(restaurante, sessaoId, usuario) {
  const sessao = await repositorio.buscarSessao(
    restaurante.id,
    sessaoId
  );

  if (!sessao) {
    throw AppError.naoEncontrado('Comanda');
  }

  if (sessao.status !== 'aberta') {
    throw AppError.conflito(
      'Esta comanda já foi encerrada.'
    );
  }

  const { rows: pendencias } = await db.query(
    `select
        count(*) filter (
          where status_pagamento <> 'pago'
        ) as nao_pagos,
        count(*) filter (
          where status in (
            'rascunho',
            'aguardando_confirmacao',
            'confirmado',
            'em_preparo',
            'pronto',
            'em_entrega'
          )
        ) as em_aberto
       from pedidos
      where restaurante_id = $1
        and sessao_mesa_id = $2
        and status <> 'cancelado'`,
    [restaurante.id, sessaoId]
  );

  const {
    nao_pagos: naoPagos,
    em_aberto: emAberto,
  } = pendencias[0];

  if (Number(naoPagos) > 0) {
    throw AppError.regraDeNegocio(
      `Ainda há ${naoPagos} pedido(s) sem pagamento confirmado nesta mesa.`,
      'CONTA_EM_ABERTO'
    );
  }

  if (Number(emAberto) > 0) {
    throw AppError.regraDeNegocio(
      `Ainda há ${emAberto} pedido(s) em produção nesta mesa.`,
      'PEDIDO_EM_PRODUCAO'
    );
  }

  return db.transacao(async (cliente) => {
    const fechada = await repositorio.fecharSessao(
      cliente,
      {
        restauranteId: restaurante.id,
        sessaoId,
        usuarioId: usuario.id,
        status: 'fechada',
      }
    );

    if (!fechada) {
      throw AppError.conflito(
        'Comanda já encerrada por outro atendente.'
      );
    }

    return fechada;
  });
}

// ============================================================
// TAXA DE SERVIÇO
// ============================================================

async function definirServico(
  restaurante,
  sessaoId,
  aceito
) {
  const sessao = await repositorio.definirServicoAceito(
    restaurante.id,
    sessaoId,
    aceito
  );

  if (!sessao) {
    throw AppError.naoEncontrado('Comanda aberta');
  }

  await db.transacao(async (cliente) => {
    const { rows } = await cliente.query(
      `select id
         from pedidos
        where sessao_mesa_id = $1
          and status <> 'cancelado'
          and status_pagamento <> 'pago'`,
      [sessaoId]
    );

    for (const pedido of rows) {
      await cliente.query(
        'select recalcular_pedido($1)',
        [pedido.id]
      );
    }
  });

  return sessao;
}

module.exports = {
  listarMesas,
  listarMesasDisponiveis,
  criarMesa,
  abrirSessao,
  selecionarMesaCliente,
  detalharSessao,
  fecharSessao,
  definirServico,
};
