
const { Router } = require('express');
const { z } = require('zod');

const servico = require('./pedidos.service');
const validar = require('../../middlewares/validar');

const {
  autenticar,
} = require('../../middlewares/autenticar');

const {
  exigirPerfil,
  carregarPerfilSeHouver,
} = require('../../middlewares/restaurante');

const rotas = Router({ mergeParams: true });

// ============================================================
// AUTENTICACAO
// ============================================================

// Todos os pedidos exigem usuario autenticado.
rotas.use(autenticar, carregarPerfilSeHouver);

// ============================================================
// SCHEMAS DE VALIDACAO
// ============================================================

const schemaCriacao = z
  .object({
    tipo: z.enum(['mesa', 'delivery', 'retirada']),
    sessaoMesaId: z.string().uuid().optional(),
    enderecoId: z.string().uuid().optional(),
    clienteId: z.string().uuid().optional(),
    observacao: z.string().trim().max(500).optional(),
  })
  .refine(
    (dados) =>
      dados.tipo !== 'mesa' ||
      Boolean(dados.sessaoMesaId),
    {
      message:
        'Pedido de mesa exige sessaoMesaId (comanda aberta).',
      path: ['sessaoMesaId'],
    }
  );

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
  status: z.enum([
    'confirmado',
    'em_preparo',
    'pronto',
    'em_entrega',
    'concluido',
    'cancelado',
  ]),
  motivo: z.string().trim().max(300).optional(),
});

const schemaFiltro = z.object({
  status: z
    .enum([
      'rascunho',
      'aguardando_confirmacao',
      'confirmado',
      'em_preparo',
      'pronto',
      'em_entrega',
      'concluido',
      'cancelado',
    ])
    .optional(),

  tipo: z
    .enum(['mesa', 'delivery', 'retirada'])
    .optional(),

  apenasAtivos: z.enum(['true', 'false']).optional(),

  limite: z.coerce
    .number()
    .int()
    .positive()
    .max(200)
    .optional(),
});

// ============================================================
// CRIAR PEDIDO
// ============================================================

rotas.post(
  '/pedidos',
  validar(schemaCriacao),
  async (req, res, proximo) => {
    try {
      const pedido = await servico.criar(
        req.restaurante,
        req,
        req.body
      );

      res.status(201).json(pedido);
    } catch (erro) {
      proximo(erro);
    }
  }
);

// ============================================================
// LISTAR PEDIDOS
// ============================================================

rotas.get(
  '/pedidos',
  validar(schemaFiltro, 'query'),
  async (req, res, proximo) => {
    try {
      const filtros = {
        ...req.query,
        apenasAtivos:
          req.query.apenasAtivos === 'true',
      };

      const pedidos = await servico.listar(
        req.restaurante,
        req,
        filtros
      );

      res.json(pedidos);
    } catch (erro) {
      proximo(erro);
    }
  }
);

// ============================================================
// DETALHAR PEDIDO
// ============================================================

rotas.get(
  '/pedidos/:pedidoId',
  async (req, res, proximo) => {
    try {
      const pedido = await servico.detalhar(
        req.restaurante,
        req.params.pedidoId,
        req
      );

      res.json(pedido);
    } catch (erro) {
      proximo(erro);
    }
  }
);

// ============================================================
// ENVIAR PEDIDO
//
// Utilizado na finalizacao do pedido.
// Altera o status para aguardando_confirmacao,
// conforme as regras do pedidos.service.js.
//
// Importante: esta rota nao realiza cobranca.
// ============================================================

rotas.post(
  '/pedidos/:pedidoId/enviar',
  async (req, res, proximo) => {
    try {
      const pedido = await servico.enviar(
        req.restaurante,
        req.params.pedidoId,
        req
      );

      res.json(pedido);
    } catch (erro) {
      proximo(erro);
    }
  }
);

// ============================================================
// CONFIRMAR PEDIDO
// ============================================================

rotas.post(
  '/pedidos/:pedidoId/confirmar',
  async (req, res, proximo) => {
    try {
      const pedido = await servico.confirmar(
        req.restaurante,
        req.params.pedidoId,
        req
      );

      res.json(pedido);
    } catch (erro) {
      proximo(erro);
    }
  }
);

// ============================================================
// ALTERAR STATUS DO PEDIDO
// ============================================================

rotas.patch(
  '/pedidos/:pedidoId/status',
  validar(schemaStatus),
  async (req, res, proximo) => {
    try {
      const pedido = await servico.alterarStatus(
        req.restaurante,
        req.params.pedidoId,
        req,
        req.body
      );

      res.json(pedido);
    } catch (erro) {
      proximo(erro);
    }
  }
);

// ============================================================
// ADICIONAR ITEM AO PEDIDO
// ============================================================

rotas.post(
  '/pedidos/:pedidoId/itens',
  validar(schemaItem),
  async (req, res, proximo) => {
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
  }
);

// ============================================================
// ATUALIZAR ITEM DO PEDIDO
// ============================================================

rotas.patch(
  '/pedidos/:pedidoId/itens/:itemId',
  validar(schemaItemEdicao),
  async (req, res, proximo) => {
    try {
      const resultado = await servico.atualizarItem(
        req.restaurante,
        req.params.pedidoId,
        req.params.itemId,
        req,
        req.body
      );

      res.json(resultado);
    } catch (erro) {
      proximo(erro);
    }
  }
);

// ============================================================
// CANCELAR ITEM DO PEDIDO
// ============================================================

rotas.delete(
  '/pedidos/:pedidoId/itens/:itemId',
  async (req, res, proximo) => {
    try {
      const motivo =
        (req.body && req.body.motivo) ||
        'Removido pelo cliente';

      const resultado = await servico.cancelarItem(
        req.restaurante,
        req.params.pedidoId,
        req.params.itemId,
        req,
        motivo
      );

      res.json(resultado);
    } catch (erro) {
      proximo(erro);
    }
  }
);

// ============================================================
// COZINHA - LISTAR FILA
// ============================================================

rotas.get(
  '/cozinha/fila',
  exigirPerfil('gerente', 'cozinha', 'garcom'),
  async (req, res, proximo) => {
    try {
      const fila = await servico.filaCozinha(
        req.restaurante
      );

      res.json(fila);
    } catch (erro) {
      proximo(erro);
    }
  }
);

// ============================================================
// COZINHA - ALTERAR STATUS DO ITEM
// ============================================================

rotas.patch(
  '/cozinha/itens/:itemId/status',
  exigirPerfil('gerente', 'cozinha', 'garcom'),
  validar(
    z.object({
      status: z.enum([
        'enviado_cozinha',
        'em_preparo',
        'pronto',
        'entregue',
        'cancelado',
      ]),
    })
  ),
  async (req, res, proximo) => {
    try {
      const resultado = await servico.alterarStatusItem(
        req.restaurante,
        req.params.itemId,
        req.body.status,
        req
      );

      res.json(resultado);
    } catch (erro) {
      proximo(erro);
    }
  }
);

// ============================================================
// EXPORTAR ROTAS
// ============================================================

module.exports = rotas;
