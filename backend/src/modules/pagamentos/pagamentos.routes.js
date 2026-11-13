
const { Router } = require('express');
const { z } = require('zod');

const servico = require('./pagamentos.service');
const validar = require('../../middlewares/validar');
const { autenticar } = require('../../middlewares/autenticar');

const {
  exigirPerfil,
  carregarPerfilSeHouver,
} = require('../../middlewares/restaurante');

const rotas = Router({ mergeParams: true });

// ============================================================
// AUTENTICACAO
// ============================================================

// Todas as rotas exigem usuario autenticado.
rotas.use(autenticar, carregarPerfilSeHouver);

// ============================================================
// VALIDACAO DOS PAGAMENTOS
// ============================================================

const schemaPagamento = z.object({
  metodo: z.enum([
    'pix',
    'cartao_credito',
    'cartao_debito',
    'dinheiro',
    'vale_refeicao',
    'na_entrega',
    'no_local',
  ]),

  valor: z.number()
    .positive()
    .max(99999.99)
    .optional(),

  trocoPara: z.number()
    .positive()
    .max(99999.99)
    .optional(),

  idempotencyKey: z.string()
    .trim()
    .min(8)
    .max(120)
    .optional(),
});

// ============================================================
// LISTAR PAGAMENTOS DO PEDIDO
// ============================================================

rotas.get(
  '/pedidos/:pedidoId/pagamentos',
  async (req, res, proximo) => {
    try {
      const pagamentos = await servico.listar(
        req.restaurante,
        req.params.pedidoId,
        req
      );

      res.json(pagamentos);
    } catch (erro) {
      proximo(erro);
    }
  }
);

// ============================================================
// CRIAR PAGAMENTO DEMONSTRATIVO
// ============================================================

// Cria um pagamento com o provedor mock.
// Nao realiza cobranca bancaria.

rotas.post(
  '/pedidos/:pedidoId/pagamentos',
  validar(schemaPagamento),
  async (req, res, proximo) => {
    try {
      const resultado = await servico.criar(
        req.restaurante,
        req.params.pedidoId,
        req,
        req.body
      );

      res.status(resultado.reaproveitado ? 200 : 201)
        .json(resultado.pagamento);
    } catch (erro) {
      proximo(erro);
    }
  }
);

// ============================================================
// CONSULTAR STATUS DO PIX DEMONSTRATIVO
// ============================================================

// Consulta o pagamento diretamente no PostgreSQL.
// Retorna o status do Pix e o status financeiro do pedido.

rotas.get(
  '/pagamentos/:pagamentoId/status-pix',
  async (req, res, proximo) => {
    try {
      const resultado = await servico.consultarStatusPix(
        req.restaurante,
        req.params.pagamentoId,
        req
      );

      res.json(resultado);
    } catch (erro) {
      proximo(erro);
    }
  }
);

// ============================================================
// CONFIRMAR PAGAMENTO DEMONSTRATIVO
// ============================================================

// Aprova o pagamento simulado.
// O servico sincroniza o status financeiro do pedido.

rotas.post(
  '/pagamentos/:pagamentoId/confirmar',
  async (req, res, proximo) => {
    try {
      const resultado = await servico.confirmar(
        req.restaurante,
        req.params.pagamentoId,
        req
      );

      res.json(resultado);
    } catch (erro) {
      proximo(erro);
    }
  }
);

// ============================================================
// ESTORNAR PAGAMENTO DEMONSTRATIVO
// ============================================================

// Somente o gerente pode realizar o estorno.

rotas.post(
  '/pagamentos/:pagamentoId/estornar',
  exigirPerfil('gerente'),
  validar(
    z.object({
      motivo: z.string()
        .trim()
        .min(5)
        .max(300),
    })
  ),
  async (req, res, proximo) => {
    try {
      const resultado = await servico.estornar(
        req.restaurante,
        req.params.pagamentoId,
        req,
        req.body.motivo
      );

      res.json(resultado);
    } catch (erro) {
      proximo(erro);
    }
  }
);

// ============================================================
// EXPORTACAO
// ============================================================

module.exports = rotas;
