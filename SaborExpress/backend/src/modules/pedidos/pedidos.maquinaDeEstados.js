
const AppError = require('../../utils/AppError');

/**
 * =====================================================================
 * Maquina de estados do PEDIDO (ciclo de producao)
 * =====================================================================
 *
 * rascunho
 *    |
 *    v
 * aguardando_confirmacao
 *    |
 *    | Confirmacao exclusiva do gerente
 *    v
 * confirmado
 *    |
 *    v
 * em_preparo
 *    |
 *    v
 * pronto
 *    |
 *    |-- Delivery --> em_entrega --> concluido
 *    |
 *    |-- Mesa/Retirada ------------> concluido
 *
 * Qualquer estado nao final pode ir para "cancelado".
 *
 * "concluido" e "cancelado" sao estados finais.
 *
 * O status financeiro (status_pagamento) e independente
 * do status de producao do pedido.
 *
 * =====================================================================
 */

const TRANSICOES = Object.freeze({
  rascunho: [
    'aguardando_confirmacao',
    'cancelado',
  ],

  aguardando_confirmacao: [
    'confirmado',
    'cancelado',
  ],

  confirmado: [
    'em_preparo',
    'cancelado',
  ],

  em_preparo: [
    'pronto',
    'cancelado',
  ],

  pronto: [
    'em_entrega',
    'concluido',
    'cancelado',
  ],

  em_entrega: [
    'concluido',
    'cancelado',
  ],

  concluido: [],

  cancelado: [],
});

/**
 * Define quais perfis podem colocar um pedido
 * em cada status.
 *
 * O cliente pode enviar o pedido, mas nao
 * pode confirmar a aceitacao pelo restaurante.
 */
const PERFIS_POR_STATUS = Object.freeze({
  aguardando_confirmacao: [
    'cliente',
    'garcom',
    'gerente',
  ],

  confirmado: [
    'gerente',
  ],

  em_preparo: [
    'gerente',
    'garcom',
    'cozinha',
  ],

  pronto: [
    'gerente',
    'garcom',
    'cozinha',
  ],

  em_entrega: [
    'gerente',
    'garcom',
    'entregador',
  ],

  concluido: [
    'gerente',
    'garcom',
    'entregador',
  ],

  cancelado: [
    'gerente',
    'garcom',
    'cliente',
  ],
});

/**
 * Estados que nao permitem novas transicoes.
 */
const ESTADOS_FINAIS = [
  'concluido',
  'cancelado',
];

/**
 * Verifica se o pedido esta em um estado final.
 */
function ehFinal(status) {
  return ESTADOS_FINAIS.includes(status);
}

/**
 * Valida uma transicao de status.
 *
 * @param {object} pedido
 * Pedido atual armazenado no banco.
 *
 * @param {string} novoStatus
 * Status solicitado.
 *
 * @param {string} perfil
 * Perfil do usuario que solicitou a alteracao.
 */
function validarTransicao(pedido, novoStatus, perfil) {
  const permitidos = TRANSICOES[pedido.status] || [];

  // ---------------------------------------------------------
  // Impedir alteracoes em pedidos finalizados
  // ---------------------------------------------------------

  if (ehFinal(pedido.status)) {
    throw AppError.regraDeNegocio(
      `O pedido ja esta ${pedido.status} e nao pode mais mudar de status.`,
      'ESTADO_FINAL'
    );
  }

  // ---------------------------------------------------------
  // Validar se a transicao e permitida
  // ---------------------------------------------------------

  if (!permitidos.includes(novoStatus)) {
    throw AppError.regraDeNegocio(
      `Transicao invalida: ${pedido.status} -> ${novoStatus}. ` +
        `A partir de "${pedido.status}" so e possivel ir para: ${permitidos.join(', ')}.`,
      'TRANSICAO_INVALIDA'
    );
  }

  // ---------------------------------------------------------
  // Validar permissao do perfil
  // ---------------------------------------------------------

  const perfisPermitidos =
    PERFIS_POR_STATUS[novoStatus] || [];

  if (!perfisPermitidos.includes(perfil)) {
    throw AppError.proibido(
      `O perfil "${perfil}" nao pode mover o pedido para "${novoStatus}".`
    );
  }

  // ---------------------------------------------------------
  // Somente delivery pode entrar em rota de entrega
  // ---------------------------------------------------------

  if (
    novoStatus === 'em_entrega' &&
    pedido.tipo !== 'delivery'
  ) {
    throw AppError.regraDeNegocio(
      'Apenas pedidos de delivery podem entrar em rota de entrega.',
      'TIPO_INCOMPATIVEL'
    );
  }

  // ---------------------------------------------------------
  // Nao concluir pedido sem pagamento confirmado
  // ---------------------------------------------------------

  if (
    novoStatus === 'concluido' &&
    pedido.status_pagamento !== 'pago'
  ) {
    throw AppError.regraDeNegocio(
      'O pedido so pode ser concluido apos a confirmacao do pagamento.',
      'PAGAMENTO_PENDENTE'
    );
  }

  // ---------------------------------------------------------
  // Cliente so pode cancelar antes da aprovacao do gerente
  // ---------------------------------------------------------

  if (
    novoStatus === 'cancelado' &&
    perfil === 'cliente'
  ) {
    const estadosCancelaveis = [
      'rascunho',
      'aguardando_confirmacao',
    ];

    if (!estadosCancelaveis.includes(pedido.status)) {
      throw AppError.regraDeNegocio(
        'O pedido ja foi confirmado pelo restaurante. Fale com o restaurante para cancelar.',
        'CANCELAMENTO_TARDIO'
      );
    }
  }

  return true;
}

module.exports = {
  TRANSICOES,
  PERFIS_POR_STATUS,
  ESTADOS_FINAIS,
  ehFinal,
  validarTransicao,
};
