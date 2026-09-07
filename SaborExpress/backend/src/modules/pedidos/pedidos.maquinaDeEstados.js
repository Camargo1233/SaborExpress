const AppError = require('../../utils/AppError');

/**
 * =====================================================================
 * Maquina de estados do PEDIDO (ciclo de producao)
 * =====================================================================
 *
 *   rascunho ──confirmar──> confirmado ──> em_preparo ──> pronto
 *                                                          │
 *                             (delivery) ──> em_entrega ────┤
 *                                                          v
 *                                                      concluido
 *
 *   Qualquer estado nao final pode ir para "cancelado".
 *   "concluido" e "cancelado" sao FINAIS: nao saem mais de la.
 *
 * O status financeiro (status_pagamento) e independente e vive em
 * pedidos.status_pagamento -- ver modulo pagamentos.
 */
const TRANSICOES = Object.freeze({
  rascunho: ['confirmado', 'cancelado'],
  confirmado: ['em_preparo', 'cancelado'],
  em_preparo: ['pronto', 'cancelado'],
  pronto: ['em_entrega', 'concluido', 'cancelado'],
  em_entrega: ['concluido', 'cancelado'],
  concluido: [],
  cancelado: [],
});

/** Quem pode colocar o pedido em cada estado (RN-SEG-002). */
const PERFIS_POR_STATUS = Object.freeze({
  confirmado: ['gerente', 'garcom', 'cliente'],
  em_preparo: ['gerente', 'garcom', 'cozinha'],
  pronto: ['gerente', 'garcom', 'cozinha'],
  em_entrega: ['gerente', 'garcom', 'entregador'],
  concluido: ['gerente', 'garcom', 'entregador'],
  cancelado: ['gerente', 'garcom', 'cliente'],
});

const ESTADOS_FINAIS = ['concluido', 'cancelado'];

function ehFinal(status) {
  return ESTADOS_FINAIS.includes(status);
}

/**
 * Valida a transicao. Lanca AppError com mensagem util quando invalida.
 * @param {object} pedido       pedido atual (linha do banco)
 * @param {string} novoStatus   estado desejado
 * @param {string} perfil       perfil de quem esta pedindo ('cliente' quando nao e equipe)
 */
function validarTransicao(pedido, novoStatus, perfil) {
  const permitidos = TRANSICOES[pedido.status] || [];

  if (ehFinal(pedido.status)) {
    throw AppError.regraDeNegocio(
      `O pedido ja esta ${pedido.status} e nao pode mais mudar de status.`,
      'ESTADO_FINAL'
    );
  }

  if (!permitidos.includes(novoStatus)) {
    throw AppError.regraDeNegocio(
      `Transicao invalida: ${pedido.status} -> ${novoStatus}. ` +
        `A partir de "${pedido.status}" so e possivel ir para: ${permitidos.join(', ')}.`,
      'TRANSICAO_INVALIDA'
    );
  }

  const perfisPermitidos = PERFIS_POR_STATUS[novoStatus] || [];
  if (!perfisPermitidos.includes(perfil)) {
    throw AppError.proibido(
      `O perfil "${perfil}" nao pode mover o pedido para "${novoStatus}".`
    );
  }

  // RN-PED-008: so pedido de delivery passa por "em_entrega".
  if (novoStatus === 'em_entrega' && pedido.tipo !== 'delivery') {
    throw AppError.regraDeNegocio(
      'Apenas pedidos de delivery podem entrar em rota de entrega.',
      'TIPO_INCOMPATIVEL'
    );
  }

  // RN-PED-010: nao se conclui pedido sem o pagamento confirmado.
  if (novoStatus === 'concluido' && pedido.status_pagamento !== 'pago') {
    throw AppError.regraDeNegocio(
      'O pedido so pode ser concluido apos a confirmacao do pagamento.',
      'PAGAMENTO_PENDENTE'
    );
  }

  // RN-PED-011: cliente so cancela antes da producao comecar.
  if (novoStatus === 'cancelado' && perfil === 'cliente') {
    if (!['rascunho', 'confirmado'].includes(pedido.status)) {
      throw AppError.regraDeNegocio(
        'O pedido ja entrou em producao. Fale com o restaurante para cancelar.',
        'CANCELAMENTO_TARDIO'
      );
    }
  }

  return true;
}

module.exports = { TRANSICOES, PERFIS_POR_STATUS, ESTADOS_FINAIS, ehFinal, validarTransicao };
