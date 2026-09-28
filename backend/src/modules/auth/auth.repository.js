const db = require('../../db');

const CAMPOS_PUBLICOS = 'id, nome, email, telefone, ativo, criado_em';

async function buscarPorEmail(email) {
  const { rows } = await db.query(
    'select id, nome, email, telefone, senha_hash, ativo from usuarios where lower(email) = lower($1)',
    [email]
  );
  return rows[0] || null;
}

async function criar({ nome, email, telefone, senhaHash }) {
  const { rows } = await db.query(
    `insert into usuarios (nome, email, telefone, senha_hash)
     values ($1, $2, $3, $4)
     returning ${CAMPOS_PUBLICOS}`,
    [nome, email, telefone || null, senhaHash]
  );
  return rows[0];
}

async function registrarLogin(usuarioId) {
  await db.query('update usuarios set ultimo_login_em = now() where id = $1', [usuarioId]);
}

/** Restaurantes em que o usuario trabalha e com qual perfil. */
async function listarVinculos(usuarioId) {
  const { rows } = await db.query(
    `select r.id as restaurante_id, r.nome, r.slug, m.perfil
       from restaurante_membros m
       join restaurantes r on r.id = m.restaurante_id
      where m.usuario_id = $1 and m.ativo = true and r.ativo = true
      order by r.nome`,
    [usuarioId]
  );
  return rows;
}

module.exports = { buscarPorEmail, criar, registrarLogin, listarVinculos, CAMPOS_PUBLICOS };
