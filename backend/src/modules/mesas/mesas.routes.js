const { Router } = require('express');
const { z } = require('zod');

const servico = require('./mesas.service');
const validar = require('../../middlewares/validar');
const { autenticar } = require('../../middlewares/autenticar');
const { exigirPerfil } = require('../../middlewares/restaurante');

const rotas = Router({ mergeParams: true });

// Todas as rotas de mesa exigem usuario da equipe.
rotas.use(autenticar);

const schemaMesa = z.object({
  numero: z.number().int().positive(),
  apelido: z.string().trim().max(40).optional(),
  capacidade: z.number().int().positive().max(50).optional(),
});

const schemaAbertura = z.object({
  qtdPessoas: z.number().int().positive().max(50).optional(),
});

rotas.get('/mesas', exigirPerfil('gerente', 'garcom', 'cozinha'), async (req, res, proximo) => {
  try {
    res.json(await servico.listarMesas(req.restaurante));
  } catch (erro) {
    proximo(erro);
  }
});

rotas.post('/mesas', exigirPerfil('gerente'), validar(schemaMesa), async (req, res, proximo) => {
  try {
    res.status(201).json(await servico.criarMesa(req.restaurante, req.body));
  } catch (erro) {
    proximo(erro);
  }
});

// Abrir comanda (ocupar a mesa)
rotas.post(
  '/mesas/:mesaId/sessoes',
  exigirPerfil('gerente', 'garcom'),
  validar(schemaAbertura),
  async (req, res, proximo) => {
    try {
      const sessao = await servico.abrirSessao(
        req.restaurante,
        req.params.mesaId,
        req.usuario,
        req.body
      );
      res.status(201).json(sessao);
    } catch (erro) {
      proximo(erro);
    }
  }
);

// Conta consolidada da comanda
rotas.get(
  '/sessoes/:sessaoId',
  exigirPerfil('gerente', 'garcom', 'cozinha'),
  async (req, res, proximo) => {
    try {
      res.json(await servico.detalharSessao(req.restaurante, req.params.sessaoId));
    } catch (erro) {
      proximo(erro);
    }
  }
);

// Aceitar/recusar a taxa de servico
rotas.patch(
  '/sessoes/:sessaoId/servico',
  exigirPerfil('gerente', 'garcom'),
  validar(z.object({ aceito: z.boolean() })),
  async (req, res, proximo) => {
    try {
      res.json(await servico.definirServico(req.restaurante, req.params.sessaoId, req.body.aceito));
    } catch (erro) {
      proximo(erro);
    }
  }
);

// Fechar comanda e liberar a mesa
rotas.post(
  '/sessoes/:sessaoId/fechar',
  exigirPerfil('gerente', 'garcom'),
  async (req, res, proximo) => {
    try {
      res.json(await servico.fecharSessao(req.restaurante, req.params.sessaoId, req.usuario));
    } catch (erro) {
      proximo(erro);
    }
  }
);

module.exports = rotas;
