const { Router } = require('express');
const { z } = require('zod');

const servico = require('./pagamentos.service');
const validar = require('../../middlewares/validar');
const { autenticar } = require('../../middlewares/autenticar');
const { exigirPerfil, carregarPerfilSeHouver } = require('../../middlewares/restaurante');

const rotas = Router({ mergeParams: true });

rotas.use(autenticar, carregarPerfilSeHouver);

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
  // Opcional: quando omitido, cobra o saldo restante (conta cheia).
  // Informado, permite dividir a conta em varios pagamentos.
  valor: z.number().positive().max(99999.99).optional(),
  trocoPara: z.number().positive().max(99999.99).optional(),
  idempotencyKey: z.string().trim().min(8).max(120).optional(),
});

rotas.get('/pedidos/:pedidoId/pagamentos', async (req, res, proximo) => {
  try {
    res.json(await servico.listar(req.restaurante, req.params.pedidoId));
  } catch (erro) {
    proximo(erro);
  }
});

rotas.post(
  '/pedidos/:pedidoId/pagamentos',
  validar(schemaPagamento),
  async (req, res, proximo) => {
    try {
      const { pagamento, reaproveitado } = await servico.criar(
        req.restaurante,
        req.params.pedidoId,
        req,
        req.body
      );
      res.status(reaproveitado ? 200 : 201).json(pagamento);
    } catch (erro) {
      proximo(erro);
    }
  }
);

// No mundo real esta rota seria substituida pelo webhook do provedor.
rotas.post('/pagamentos/:pagamentoId/confirmar', async (req, res, proximo) => {
  try {
    res.json(await servico.confirmar(req.restaurante, req.params.pagamentoId, req));
  } catch (erro) {
    proximo(erro);
  }
});

rotas.post(
  '/pagamentos/:pagamentoId/estornar',
  exigirPerfil('gerente'),
  validar(z.object({ motivo: z.string().trim().min(5).max(300) })),
  async (req, res, proximo) => {
    try {
      res.json(
        await servico.estornar(req.restaurante, req.params.pagamentoId, req, req.body.motivo)
      );
    } catch (erro) {
      proximo(erro);
    }
  }
);

module.exports = rotas;
