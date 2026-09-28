const db = require('../db');
const AppError = require('../utils/AppError');
const token = require('../utils/token');

/**
 * Le o header Authorization: Bearer <token>, valida e carrega o usuario
 * do banco em req.usuario. Usuario inativo e tratado como nao autenticado.
 */
async function autenticar(req, _res, proximo) {
  try {
    const header = req.headers.authorization || '';
    const [esquema, valor] = header.split(' ');

    if (esquema !== 'Bearer' || !valor) {
      throw AppError.naoAutorizado('Envie o token no header Authorization: Bearer <token>.');
    }

    const payload = token.verificar(valor);

    const { rows } = await db.query(
      'select id, nome, email, telefone, ativo from usuarios where id = $1',
      [payload.sub]
    );

    const usuario = rows[0];
    if (!usuario || !usuario.ativo) {
      throw AppError.naoAutorizado('Usuario inativo ou inexistente.');
    }

    req.usuario = usuario;
    proximo();
  } catch (erro) {
    proximo(erro);
  }
}

/**
 * Versao opcional: se houver token valido carrega o usuario, senao segue
 * como visitante. Usada no cardapio publico.
 */
async function autenticarOpcional(req, _res, proximo) {
  if (!req.headers.authorization) return proximo();
  return autenticar(req, _res, proximo);
}

module.exports = { autenticar, autenticarOpcional };
