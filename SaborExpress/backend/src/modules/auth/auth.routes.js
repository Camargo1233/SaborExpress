
const { Router } = require('express');
const rateLimit = require('express-rate-limit');
const { z } = require('zod');

const servico = require('./auth.service');
const validar = require('../../middlewares/validar');
const { autenticar } = require('../../middlewares/autenticar');

const rotas = Router();

// ============================================================
// LIMITES DE REQUISICOES
// ============================================================

// Protecao contra forca bruta no login.
const limiteLogin = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    erro: 'Muitas tentativas de login. Tente novamente em 15 minutos.',
  },
});

// Limita solicitacoes de recuperacao por IP.
const limiteRecuperacao = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    erro: 'Muitas solicitacoes. Tente novamente em 15 minutos.',
  },
});

// Limita tentativas de redefinicao de senha.
const limiteRedefinicao = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    erro: 'Muitas tentativas. Tente novamente em 15 minutos.',
  },
});

// ============================================================
// VALIDACOES
// ============================================================

const schemaRegistro = z.object({
  nome: z.string().trim().min(3, 'Informe o nome completo.').max(120),
  email: z.string().trim().email('E-mail invalido.').max(160),
  telefone: z.string().trim().max(30).optional(),
  senha: z
    .string()
    .min(8, 'A senha deve ter ao menos 8 caracteres.')
    .max(72)
    .regex(/[A-Za-z]/, 'A senha deve conter ao menos uma letra.')
    .regex(/[0-9]/, 'A senha deve conter ao menos um numero.'),
});

const schemaLogin = z.object({
  email: z.string().trim().email('E-mail invalido.'),
  senha: z.string().min(1, 'Informe a senha.'),
});

const schemaEsqueciSenha = z.object({
  email: z
    .string()
    .trim()
    .email('Informe um e-mail valido.')
    .max(160),
});

const schemaRedefinirSenha = z.object({
  tokenRecuperacao: z
    .string()
    .regex(/^[a-f0-9]{64}$/, 'Link de recuperacao invalido.'),
  novaSenha: z
    .string()
    .min(8, 'A senha deve ter ao menos 8 caracteres.')
    .max(72)
    .regex(/[A-Za-z]/, 'A senha deve conter ao menos uma letra.')
    .regex(/[0-9]/, 'A senha deve conter ao menos um numero.'),
});

// ============================================================
// CADASTRO
// ============================================================

rotas.post(
  '/registrar',
  validar(schemaRegistro),
  async (req, res, proximo) => {
    try {
      res.status(201).json(
        await servico.registrar(req.body)
      );
    } catch (erro) {
      proximo(erro);
    }
  }
);

// ============================================================
// LOGIN
// ============================================================

rotas.post(
  '/login',
  limiteLogin,
  validar(schemaLogin),
  async (req, res, proximo) => {
    try {
      res.json(await servico.login(req.body));
    } catch (erro) {
      proximo(erro);
    }
  }
);

// ============================================================
// SOLICITAR RECUPERACAO DE SENHA
// ============================================================

rotas.post(
  '/esqueci-senha',
  limiteRecuperacao,
  validar(schemaEsqueciSenha),
  async (req, res, proximo) => {
    try {
      const resultado =
        await servico.solicitarRecuperacaoSenha(req.body);

      res.json(resultado);
    } catch (erro) {
      proximo(erro);
    }
  }
);

// ============================================================
// REDEFINIR SENHA
// ============================================================

rotas.post(
  '/redefinir-senha',
  limiteRedefinicao,
  validar(schemaRedefinirSenha),
  async (req, res, proximo) => {
    try {
      const resultado =
        await servico.redefinirSenha(req.body);

      res.json(resultado);
    } catch (erro) {
      proximo(erro);
    }
  }
);

// ============================================================
// USUARIO AUTENTICADO
// ============================================================

rotas.get(
  '/eu',
  autenticar,
  async (req, res, proximo) => {
    try {
      res.json(await servico.eu(req.usuario));
    } catch (erro) {
      proximo(erro);
    }
  }
);

module.exports = rotas;
