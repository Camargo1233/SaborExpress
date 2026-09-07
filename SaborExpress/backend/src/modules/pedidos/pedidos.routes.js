const { Router } = require('express');
const { z } = require('zod');

const servico = require('./pedidos.service');
const validar = require('../../middlewares/validar');
const { autenticar } = require('../../middlewares/autenticar');
const { exigirPerfil, carregarPerfilSeHouver } = require('../../middlewares/restaurante');

const rotas = Router({ mergeParams: true });

// Pedido sempre exige usuario autenticado (cliente ou equipe).
rotas.use(autenticar, carregarPerfilSeHouver);

const schemaCriacao = z
  .object({
    tipo: z.enum(['mesa', 'delivery', 'retirada']),
    sessaoMesaId: z.string().uuid().optional(),
    enderecoId: z.string().uuid().optional(),
    clienteId: z.string().uuid().optional(),
    observacao: z.string().trim().max(500).optional(),
  })
  .refine((d) => d.tipo !== 'mesa' || Boolean(d.sessaoMesaId), {
    message: 'Pedido de mesa exige sessaoMesaId (comanda aberta).',
    path: ['sessaoMesaId'],
  });

const schemaItem = z.object({
  produtoId: z.string().uuid(),
  quantidade: z.number().int().positive().max(99),
  observacao: z.string().trim().max(300).optional(),
});

const schemaItemEdicao = z.object({
  quantidade: z.number().int().positive().max(99).optional(),
  observacao: z.string().trim().max(300).optional(),
});

const schemaStatus = z.object({
  status: z.enum(['confirmado', 'em_preparo', 'pronto', 'em_entrega', 'concluido', 'cancelado']),
  motivo: z.string().trim().max(300).optional(),
});

const schemaFiltro = z.object({
  status: z.enum(['rascunho', 'confirmado', 'em_preparo', 'pronto', 'em_entrega', 'concluido', 'cancelado']).optional(),
  tipo: z.enum(['mesa', 'delivery', 'retirada']).optional(),
  apenasAtivos: z.enum(['true', 'false']).optional(),
  limite: z.coerce.number().int().positive().max(200).optional(),
});

// ------------------------------ Pedidos ------------------------------

rotas.post('/pedidos', validar(schemaCriacao), async (req, res, proximo) => {
  try {
    res.status(201).json(await servico.criar(req.restaurante, req, req.body));
  } catch (erro) {
    proximo(erro);
  }
});

rotas.get('/pedidos', validar(schemaFiltro, 'query'), async (req, res, proximo) => {
  try {
    const filtros = { ...req.query, apenasAtivos: req.query.apenasAtivos === 'true' };
    res.json(await servico.listar(req.restaurante, req, filtros));
  } catch (erro) {
    proximo(erro);
  }
});

rotas.get('/pedidos/:pedidoId', async (req, res, proximo) => {
  try {
    res.json(await servico.detalhar(req.restaurante, req.params.pedidoId, req));
  } catch (erro) {
    proximo(erro);
  }
});

rotas.post('/pedidos/:pedidoId/confirmar', async (req, res, proximo) => {
  try {
    res.json(await servico.confirmar(req.restaurante, req.params.pedidoId, req));
  } catch (erro) {
    proximo(erro);
  }
});

rotas.patch('/pedidos/:pedidoId/status', validar(schemaStatus), async (req, res, proximo) => {
  try {
    res.json(await servico.alterarStatus(req.restaurante, req.params.pedidoId, req, req.body));
  } catch (erro) {
    proximo(erro);
  }
});

// ------------------------------- Itens -------------------------------

rotas.post('/pedidos/:pedidoId/itens', validar(schemaItem), async (req, res, proximo) => {
  try {
    const resultado = await servico.adicionarItem(
      req.restaurante,
      req.params.pedidoId,
      req,
      req.body
    );
    res.status(201).json(resultado);
  } catch (erro) {
    proximo(erro);
  }
});

rotas.patch(
  '/pedidos/:pedidoId/itens/:itemId',
  validar(schemaItemEdicao),
  async (req, res, proximo) => {
    try {
      res.json(
        await servico.atualizarItem(
          req.restaurante,
          req.params.pedidoId,
          req.params.itemId,
          req,
          req.body
        )
      );
    } catch (erro) {
      proximo(erro);
    }
  }
);

rotas.delete('/pedidos/:pedidoId/itens/:itemId', async (req, res, proximo) => {
  try {
    const motivo = (req.body && req.body.motivo) || 'Removido pelo cliente';
    res.json(
      await servico.cancelarItem(
        req.restaurante,
        req.params.pedidoId,
        req.params.itemId,
        req,
        motivo
      )
    );
  } catch (erro) {
    proximo(erro);
  }
});

// ------------------------------ Cozinha ------------------------------

rotas.get('/cozinha/fila', exigirPerfil('gerente', 'cozinha', 'garcom'), async (req, res, proximo) => {
  try {
    res.json(await servico.filaCozinha(req.restaurante));
  } catch (erro) {
    proximo(erro);
  }
});

rotas.patch(
  '/cozinha/itens/:itemId/status',
  exigirPerfil('gerente', 'cozinha', 'garcom'),
  validar(
    z.object({
      status: z.enum(['enviado_cozinha', 'em_preparo', 'pronto', 'entregue', 'cancelado']),
    })
  ),
  async (req, res, proximo) => {
    try {
      res.json(
        await servico.alterarStatusItem(req.restaurante, req.params.itemId, req.body.status, req)
      );
    } catch (erro) {
      proximo(erro);
    }
  }
);

module.exports = rotas;
