const { Router } = require('express');
const { z } = require('zod');

const servico = require('./catalogo.service');
const validar = require('../../middlewares/validar');
const { autenticar, autenticarOpcional } = require('../../middlewares/autenticar');
const { exigirPerfil, carregarPerfilSeHouver } = require('../../middlewares/restaurante');

// mergeParams: precisamos do :restauranteId definido no router pai.
const rotas = Router({ mergeParams: true });

const schemaCategoria = z.object({
  nome: z.string().trim().min(2).max(80),
  descricao: z.string().trim().max(500).optional(),
  ordem: z.number().int().min(0).optional(),
});

const schemaCategoriaEdicao = schemaCategoria.partial().extend({
  ativo: z.boolean().optional(),
});

const schemaProduto = z.object({
  nome: z.string().trim().min(2).max(120),
  descricao: z.string().trim().max(1000).optional(),
  preco: z.number().positive('O preco deve ser maior que zero.').max(99999.99),
  categoriaId: z.string().uuid().optional(),
  imagemUrl: z.string().url().max(2000).optional(),
  tempoPreparoMin: z.number().int().min(0).max(600).optional(),
  destaque: z.boolean().optional(),
  disponivel: z.boolean().optional(),
});

const schemaProdutoEdicao = schemaProduto.partial().extend({
  ativo: z.boolean().optional(),
});

const schemaFiltroProdutos = z.object({
  categoriaId: z.string().uuid().optional(),
  busca: z.string().trim().min(1).max(80).optional(),
  destaque: z.enum(['true', 'false']).optional(),
});

// --------------------------- CATEGORIAS ---------------------------

rotas.get('/categorias', autenticarOpcional, carregarPerfilSeHouver, async (req, res, proximo) => {
  try {
    res.json(await servico.listarCategorias(req.restaurante, Boolean(req.perfil)));
  } catch (erro) {
    proximo(erro);
  }
});

rotas.post(
  '/categorias',
  autenticar,
  exigirPerfil('gerente'),
  validar(schemaCategoria),
  async (req, res, proximo) => {
    try {
      res.status(201).json(await servico.criarCategoria(req.restaurante, req.body));
    } catch (erro) {
      proximo(erro);
    }
  }
);

rotas.patch(
  '/categorias/:categoriaId',
  autenticar,
  exigirPerfil('gerente'),
  validar(schemaCategoriaEdicao),
  async (req, res, proximo) => {
    try {
      res.json(await servico.atualizarCategoria(req.restaurante, req.params.categoriaId, req.body));
    } catch (erro) {
      proximo(erro);
    }
  }
);

// ---------------------------- PRODUTOS ----------------------------

rotas.get(
  '/produtos',
  autenticarOpcional,
  carregarPerfilSeHouver,
  validar(schemaFiltroProdutos, 'query'),
  async (req, res, proximo) => {
    try {
      const filtros = { ...req.query, destaque: req.query.destaque === 'true' };
      res.json(await servico.listarProdutos(req.restaurante, filtros, Boolean(req.perfil)));
    } catch (erro) {
      proximo(erro);
    }
  }
);

rotas.get('/produtos/:produtoId', async (req, res, proximo) => {
  try {
    res.json(await servico.buscarProduto(req.restaurante, req.params.produtoId));
  } catch (erro) {
    proximo(erro);
  }
});

rotas.post(
  '/produtos',
  autenticar,
  exigirPerfil('gerente'),
  validar(schemaProduto),
  async (req, res, proximo) => {
    try {
      res.status(201).json(await servico.criarProduto(req.restaurante, req.body));
    } catch (erro) {
      proximo(erro);
    }
  }
);

rotas.patch(
  '/produtos/:produtoId',
  autenticar,
  exigirPerfil('gerente'),
  validar(schemaProdutoEdicao),
  async (req, res, proximo) => {
    try {
      res.json(await servico.atualizarProduto(req.restaurante, req.params.produtoId, req.body));
    } catch (erro) {
      proximo(erro);
    }
  }
);

// Garcom e cozinha podem marcar "acabou" sem poder editar preco (RN-CAT-005).
rotas.patch(
  '/produtos/:produtoId/disponibilidade',
  autenticar,
  exigirPerfil('gerente', 'garcom', 'cozinha'),
  validar(z.object({ disponivel: z.boolean() })),
  async (req, res, proximo) => {
    try {
      res.json(
        await servico.atualizarProduto(req.restaurante, req.params.produtoId, {
          disponivel: req.body.disponivel,
        })
      );
    } catch (erro) {
      proximo(erro);
    }
  }
);

rotas.delete(
  '/produtos/:produtoId',
  autenticar,
  exigirPerfil('gerente'),
  async (req, res, proximo) => {
    try {
      res.json(await servico.desativarProduto(req.restaurante, req.params.produtoId));
    } catch (erro) {
      proximo(erro);
    }
  }
);

module.exports = rotas;
