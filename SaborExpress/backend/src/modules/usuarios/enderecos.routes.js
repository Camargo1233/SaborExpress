const { Router } = require('express');
const { z } = require('zod');

const db = require('../../db');
const AppError = require('../../utils/AppError');
const validar = require('../../middlewares/validar');
const { autenticar } = require('../../middlewares/autenticar');

const rotas = Router();

rotas.use(autenticar);

const schemaEndereco = z.object({
  apelido: z.string().trim().max(80).optional(),
  cep: z.string().trim().regex(/^\d{5}-?\d{3}$/, 'CEP invalido (use 00000-000).'),
  logradouro: z.string().trim().min(3).max(160),
  numero: z.string().trim().min(1).max(20),
  complemento: z.string().trim().max(120).optional(),
  bairro: z.string().trim().min(2).max(100),
  cidade: z.string().trim().min(2).max(100),
  estado: z.string().trim().length(2, 'Use a sigla do estado (ex.: SP).'),
  referencia: z.string().trim().max(160).optional(),
  principal: z.boolean().optional(),
});

rotas.get('/', async (req, res, proximo) => {
  try {
    const { rows } = await db.query(
      `select id, apelido, cep, logradouro, numero, complemento, bairro,
              cidade, estado, referencia, principal
         from enderecos
        where usuario_id = $1 and ativo = true
        order by principal desc, criado_em`,
      [req.usuario.id]
    );
    res.json(rows);
  } catch (erro) {
    proximo(erro);
  }
});

/** RN-USR-005: so existe um endereco principal por usuario. */
rotas.post('/', validar(schemaEndereco), async (req, res, proximo) => {
  try {
    const dados = req.body;
    const endereco = await db.transacao(async (cliente) => {
      if (dados.principal) {
        await cliente.query(
          'update enderecos set principal = false where usuario_id = $1',
          [req.usuario.id]
        );
      }
      const { rows } = await cliente.query(
        `insert into enderecos (usuario_id, apelido, cep, logradouro, numero, complemento,
                                bairro, cidade, estado, referencia, principal)
         values ($1, coalesce($2, 'Principal'), $3, $4, $5, $6, $7, $8, upper($9), $10,
                 coalesce($11, false))
         returning id, apelido, cep, logradouro, numero, complemento, bairro,
                   cidade, estado, referencia, principal`,
        [
          req.usuario.id,
          dados.apelido || null,
          dados.cep,
          dados.logradouro,
          dados.numero,
          dados.complemento || null,
          dados.bairro,
          dados.cidade,
          dados.estado,
          dados.referencia || null,
          dados.principal ?? false,
        ]
      );
      return rows[0];
    });

    res.status(201).json(endereco);
  } catch (erro) {
    proximo(erro);
  }
});

rotas.delete('/:enderecoId', async (req, res, proximo) => {
  try {
    const { rows } = await db.query(
      `update enderecos set ativo = false, principal = false
        where id = $1 and usuario_id = $2
        returning id`,
      [req.params.enderecoId, req.usuario.id]
    );
    if (!rows[0]) throw AppError.naoEncontrado('Endereco');
    res.json(rows[0]);
  } catch (erro) {
    proximo(erro);
  }
});

module.exports = rotas;
