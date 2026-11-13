
const db = require('../../db');

const CAMPOS_PUBLICOS = 'id, nome, email, telefone, ativo, criado_em';

// ============================================================
// BUSCAR USUARIO POR E-MAIL
// ============================================================

async function buscarPorEmail(email) {
  const { rows } = await db.query(
    `select id, nome, email, telefone, senha_hash, ativo
       from usuarios
      where lower(email) = lower($1)`,
    [email]
  );

  return rows[0] || null;
}

// ============================================================
// CADASTRAR USUARIO
// ============================================================

async function criar({ nome, email, telefone, senhaHash }) {
  const { rows } = await db.query(
    `insert into usuarios (nome, email, telefone, senha_hash)
     values ($1, $2, $3, $4)
     returning ${CAMPOS_PUBLICOS}`,
    [nome, email, telefone || null, senhaHash]
  );

  return rows[0];
}

// ============================================================
// REGISTRAR LOGIN
// ============================================================

async function registrarLogin(usuarioId) {
  await db.query(
    'update usuarios set ultimo_login_em = now() where id = $1',
    [usuarioId]
  );
}

// ============================================================
// LISTAR VINCULOS COM RESTAURANTES
// ============================================================

/**
 * Restaurantes em que o usuario trabalha e com qual perfil.
 */
async function listarVinculos(usuarioId) {
  const { rows } = await db.query(
    `select r.id as restaurante_id, r.nome, r.slug, m.perfil
       from restaurante_membros m
       join restaurantes r on r.id = m.restaurante_id
      where m.usuario_id = $1
        and m.ativo = true
        and r.ativo = true
      order by r.nome`,
    [usuarioId]
  );

  return rows;
}

// ============================================================
// RECUPERACAO DE SENHA
// ============================================================

/**
 * Salva o hash do token de recuperacao.
 *
 * O token original nao e armazenado no banco.
 * A validade e de 15 minutos.
 */
async function criarRecuperacaoSenha(usuarioId, tokenHash) {
  await db.query(
    `insert into recuperacoes_senha
       (usuario_id, token_hash, expira_em)
     values
       ($1, $2, now() + interval '15 minutes')`,
    [usuarioId, tokenHash]
  );
}

/**
 * Busca um token de recuperacao valido.
 *
 * Requisitos:
 * - O token deve existir.
 * - Nao pode ter sido utilizado.
 * - Nao pode estar expirado.
 * - O usuario deve estar ativo.
 */
async function buscarRecuperacaoSenha(tokenHash) {
  const { rows } = await db.query(
    `select
       r.id,
       r.usuario_id
     from recuperacoes_senha r
     join usuarios u
       on u.id = r.usuario_id
     where r.token_hash = $1
       and r.utilizado_em is null
       and r.expira_em > now()
       and u.ativo = true`,
    [tokenHash]
  );

  return rows[0] || null;
}

/**
 * Redefine a senha do usuario.
 *
 * A operacao utiliza uma transacao para garantir
 * que o token seja usado apenas uma vez.
 */
async function redefinirSenha(tokenHash, novaSenhaHash) {
  const cliente = await db.connect();

  try {
    await cliente.query('BEGIN');

    // Bloqueia o registro durante a redefinicao.
    const { rows } = await cliente.query(
      `select
         r.id,
         r.usuario_id
       from recuperacoes_senha r
       join usuarios u
         on u.id = r.usuario_id
       where r.token_hash = $1
         and r.utilizado_em is null
         and r.expira_em > now()
         and u.ativo = true
       for update of r`,
      [tokenHash]
    );

    if (rows.length === 0) {
      await cliente.query('ROLLBACK');
      return false;
    }

    const usuarioId = rows[0].usuario_id;

    // Atualiza a senha do usuario.
    await cliente.query(
      `update usuarios
          set senha_hash = $1
        where id = $2`,
      [novaSenhaHash, usuarioId]
    );

    // Invalida todos os tokens pendentes do usuario.
    await cliente.query(
      `update recuperacoes_senha
          set utilizado_em = now()
        where usuario_id = $1
          and utilizado_em is null`,
      [usuarioId]
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

// ============================================================
// EXPORTACOES
// ============================================================

module.exports = {
  buscarPorEmail,
  criar,
  registrarLogin,
  listarVinculos,
  criarRecuperacaoSenha,
  buscarRecuperacaoSenha,
  redefinirSenha,
  CAMPOS_PUBLICOS,
};
