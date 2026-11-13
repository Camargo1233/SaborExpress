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


async function buscarPorId(usuarioId) {
  const { rows } = await db.query(
    `SELECT id, nome, email, telefone, ativo, asaas_cliente_id
       FROM usuarios
      WHERE id = $1`,
    [usuarioId]
  );

  return rows[0] || null;
}


async function salvarAsaasClienteId(usuarioId, asaasClienteId) {
  const { rows } = await db.query(
    `UPDATE usuarios
        SET asaas_cliente_id = $2
      WHERE id = $1
        AND (asaas_cliente_id IS NULL OR asaas_cliente_id = $2)
      RETURNING id, asaas_cliente_id`,
    [usuarioId, asaasClienteId]
  );

  return rows[0] || null;
}
// ============================================================
// RECUPERACAO DE SENHA
// ============================================================

async function criarRecuperacaoSenha(usuarioId, tokenHash) {
  await db.query(
    `INSERT INTO recuperacoes_senha
       (usuario_id, token_hash, expira_em)
     VALUES ($1, $2, NOW() + INTERVAL '15 minutes')`,
    [usuarioId, tokenHash]
  );
}

async function buscarRecuperacaoSenha(tokenHash) {
  const { rows } = await db.query(
    `SELECT r.id, r.usuario_id
       FROM recuperacoes_senha r
       JOIN usuarios u ON u.id = r.usuario_id
      WHERE r.token_hash = $1
        AND r.utilizado_em IS NULL
        AND r.expira_em > NOW()
        AND u.ativo = true`,
    [tokenHash]
  );

  return rows[0] || null;
}

async function redefinirSenha(tokenHash, novaSenhaHash) {
  const cliente = await db.connect();

  try {
    await cliente.query('BEGIN');

    // Bloqueia o token para impedir duas redefinicoes simultaneas.
    const { rows } = await cliente.query(
      `SELECT r.id, r.usuario_id
         FROM recuperacoes_senha r
         JOIN usuarios u ON u.id = r.usuario_id
        WHERE r.token_hash = $1
          AND r.utilizado_em IS NULL
          AND r.expira_em > NOW()
          AND u.ativo = true
        FOR UPDATE OF r`,
      [tokenHash]
    );

    if (rows.length === 0) {
      await cliente.query('ROLLBACK');
      return false;
    }

    const recuperacao = rows[0];

    await cliente.query(
      `UPDATE usuarios
          SET senha_hash = $1
        WHERE id = $2`,
      [novaSenhaHash, recuperacao.usuario_id]
    );

    // Invalida todos os links pendentes deste usuario.
    await cliente.query(
      `UPDATE recuperacoes_senha
          SET utilizado_em = NOW()
        WHERE usuario_id = $1
          AND utilizado_em IS NULL`,
      [recuperacao.usuario_id]
    );

    await cliente.query('COMMIT');
    return true;
  } catch (erro) {
    await cliente.query('ROLLBACK');
    throw erro;
  } finally {
    cliente.release();
  }
}

module.exports = {
  buscarPorEmail,
  buscarPorId,
  criar,
  registrarLogin,
  listarVinculos,
  salvarAsaasClienteId,
  criarRecuperacaoSenha,
  buscarRecuperacaoSenha,
  redefinirSenha,
  CAMPOS_PUBLICOS,
};
