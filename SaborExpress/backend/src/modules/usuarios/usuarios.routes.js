const { Router } = require('express');
const { z } = require('zod');

const db = require('../../db');
const AppError = require('../../utils/AppError');
const senhaUtil = require('../../utils/senha');
const validar = require('../../middlewares/validar');
const { autenticar } = require('../../middlewares/autenticar');
const { exigirPerfil } = require('../../middlewares/restaurante');

const rotas = Router({ mergeParams: true });

rotas.use(autenticar);

const schemaMembro = z.object({
  nome: z.string().trim().min(3).max(120),
  email: z.string().trim().email().max(160),
  telefone: z.string().trim().max(30).optional(),
  senha: z.string().min(8).max(72).regex(/[A-Za-z]/).regex(/[0-9]/),
  perfil: z.enum(['gerente', 'garcom', 'cozinha', 'entregador']),
});

/** Equipe do restaurante. */
rotas.get('/', exigirPerfil('gerente'), async (req, res, proximo) => {
  try {
    const { rows } = await db.query(
      `select u.id, u.nome, u.email, u.telefone, u.ativo,
              m.perfil, m.ativo as vinculo_ativo, m.criado_em
         from restaurante_membros m
         join usuarios u on u.id = m.usuario_id
        where m.restaurante_id = $1
        order by m.perfil, u.nome`,
      [req.restaurante.id]
    );
    res.json(rows);
  } catch (erro) {
    proximo(erro);
  }
});

/**
 * RN-USR-006: apenas o gerente cria contas de equipe. Se o e-mail ja
 * existir na plataforma (ex.: a pessoa ja era cliente), reaproveitamos o
 * usuario e apenas criamos o vinculo -- sem duplicar cadastro.
 */
rotas.post('/', exigirPerfil('gerente'), validar(schemaMembro), async (req, res, proximo) => {
  try {
    const { nome, email, telefone, senha, perfil } = req.body;

    const resultado = await db.transacao(async (cliente) => {
      const { rows: existentes } = await cliente.query(
        'select id, nome, email from usuarios where lower(email) = lower($1)',
        [email]
      );

      let usuario = existentes[0];
      if (!usuario) {
        const hash = await senhaUtil.gerarHash(senha);
        const { rows } = await cliente.query(
          `insert into usuarios (nome, email, telefone, senha_hash)
           values ($1, $2, $3, $4)
           returning id, nome, email, telefone`,
          [nome, email, telefone || null, hash]
        );
        usuario = rows[0];
      }

      const { rows: vinculos } = await cliente.query(
        `insert into restaurante_membros (restaurante_id, usuario_id, perfil)
         values ($1, $2, $3)
         on conflict (restaurante_id, usuario_id)
         do update set perfil = excluded.perfil, ativo = true
         returning perfil, ativo`,
        [req.restaurante.id, usuario.id, perfil]
      );

      return { ...usuario, ...vinculos[0] };
    });

    res.status(201).json(resultado);
  } catch (erro) {
    proximo(erro);
  }
});

/** RN-USR-007: desligar alguem revoga o acesso na proxima requisicao. */
rotas.delete('/:usuarioId', exigirPerfil('gerente'), async (req, res, proximo) => {
  try {
    if (req.params.usuarioId === req.usuario.id) {
      throw AppError.regraDeNegocio('Voce nao pode remover o proprio acesso de gerente.');
    }

    const { rows } = await db.query(
      `update restaurante_membros set ativo = false
        where restaurante_id = $1 and usuario_id = $2
        returning usuario_id, perfil, ativo`,
      [req.restaurante.id, req.params.usuarioId]
    );

    if (!rows[0]) throw AppError.naoEncontrado('Membro da equipe');
    res.json(rows[0]);
  } catch (erro) {
    proximo(erro);
  }
});

module.exports = rotas;
