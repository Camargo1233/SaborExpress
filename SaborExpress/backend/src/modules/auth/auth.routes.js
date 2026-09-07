const { Router } = require('express');
const rateLimit = require('express-rate-limit');
const { z } = require('zod');

const servico = require('./auth.service');
const validar = require('../../middlewares/validar');
const { autenticar } = require('../../middlewares/autenticar');

const rotas = Router();

// RN-SEG-005: forca bruta no login e barrada por IP.
const limiteLogin = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  message: { erro: 'Muitas tentativas de login. Tente novamente em 15 minutos.' },
});

const schemaRegistro = z.object({
  nome: z.string().trim().min(3, 'Informe o nome completo.').max(120),
  email: z.string().trim().email('E-mail invalido.').max(160),
  telefone: z.string().trim().max(30).optional(),
  // RN-USR-004: minimo de 8 caracteres, com letra e numero.
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

rotas.post('/registrar', validar(schemaRegistro), async (req, res, proximo) => {
  try {
    res.status(201).json(await servico.registrar(req.body));
  } catch (erro) {
    proximo(erro);
  }
});

rotas.post('/login', limiteLogin, validar(schemaLogin), async (req, res, proximo) => {
  try {
    res.json(await servico.login(req.body));
  } catch (erro) {
    proximo(erro);
  }
});

rotas.get('/eu', autenticar, async (req, res, proximo) => {
  try {
    res.json(await servico.eu(req.usuario));
  } catch (erro) {
    proximo(erro);
  }
});

module.exports = rotas;
