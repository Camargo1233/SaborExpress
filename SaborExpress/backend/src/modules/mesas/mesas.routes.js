
const { Router } = require('express');
const { z } = require('zod');

const servico = require('./mesas.service');
const validar = require('../../middlewares/validar');
const { autenticar } = require('../../middlewares/autenticar');
const { exigirPerfil } = require('../../middlewares/restaurante');

const rotas = Router({ mergeParams: true });

rotas.use(autenticar);

// ============================================================
// SCHEMAS
// ============================================================

const schemaMesa = z.object({
  numero: z.number().int().positive(),
  apelido: z.string().trim().max(40).optional(),
  capacidade: z.number().int().positive().max(50).optional(),
});

const schemaAbertura = z.object({
  qtdPessoas: z.number().int().positive().max(50).optional(),
});

const schemaSelecaoCliente = z.object({
  qtdPessoas: z.number().int().positive().max(50),
});

// ============================================================
// CLIENTE - LISTAR MESAS DISPONÍVEIS
// ============================================================

rotas.get(
  '/mesas/disponiveis',
  async (req, res, proximo) => {
    try {
      const mesas =
        await servico.listarMesasDisponiveis(
          req.restaurante
        );

      res.json(mesas);
    } catch (erro) {
      proximo(erro);
    }
  }
);

// ============================================================
// CLIENTE - SELECIONAR MESA E ABRIR COMANDA
// ============================================================

rotas.post(
  '/mesas/:mesaId/reservar',
  validar(schemaSelecaoCliente),
  async (req, res, proximo) => {
    try {
      const sessao =
        await servico.selecionarMesaCliente(
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

// ============================================================
// EQUIPE - LISTAR TODAS AS MESAS
// ============================================================

rotas.get(
  '/mesas',
  exigirPerfil('gerente', 'garcom', 'cozinha'),
  async (req, res, proximo) => {
    try {
      res.json(
        await servico.listarMesas(req.restaurante)
      );
    } catch (erro) {
      proximo(erro);
    }
  }
);

// ============================================================
// GERENTE - CRIAR MESA
// ============================================================

rotas.post(
  '/mesas',
  exigirPerfil('gerente'),
  validar(schemaMesa),
  async (req, res, proximo) => {
    try {
      const mesa = await servico.criarMesa(
        req.restaurante,
        req.body
      );

      res.status(201).json(mesa);
    } catch (erro) {
      proximo(erro);
    }
  }
);

// ============================================================
// EQUIPE - ABRIR COMANDA
// ============================================================

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

// ============================================================
// EQUIPE - DETALHAR COMANDA
// ============================================================

rotas.get(
  '/sessoes/:sessaoId',
  exigirPerfil('gerente', 'garcom', 'cozinha'),
  async (req, res, proximo) => {
    try {
      res.json(
        await servico.detalharSessao(
          req.restaurante,
          req.params.sessaoId
        )
      );
    } catch (erro) {
      proximo(erro);
    }
  }
);

// ============================================================
// EQUIPE - TAXA DE SERVIÇO
// ============================================================

rotas.patch(
  '/sessoes/:sessaoId/servico',
  exigirPerfil('gerente', 'garcom'),
  validar(
    z.object({
      aceito: z.boolean(),
    })
  ),
  async (req, res, proximo) => {
    try {
      res.json(
        await servico.definirServico(
          req.restaurante,
          req.params.sessaoId,
          req.body.aceito
        )
      );
    } catch (erro) {
      proximo(erro);
    }
  }
);

// ============================================================
// EQUIPE - FECHAR COMANDA
// ============================================================

rotas.post(
  '/sessoes/:sessaoId/fechar',
  exigirPerfil('gerente', 'garcom'),
  async (req, res, proximo) => {
    try {
      res.json(
        await servico.fecharSessao(
          req.restaurante,
          req.params.sessaoId,
          req.usuario
        )
      );
    } catch (erro) {
      proximo(erro);
    }
  }
);

module.exports = rotas;
