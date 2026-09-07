const db = require('../db');
const AppError = require('../utils/AppError');

const REGEX_UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/**
 * Resolve o :restauranteId da rota (aceita UUID ou slug) e coloca o
 * restaurante em req.restaurante. Todo recurso operacional da API vive
 * abaixo de /restaurantes/:restauranteId -- e o limite do tenant.
 */
async function carregarRestaurante(req, _res, proximo) {
  try {
    const chave = req.params.restauranteId;
    const campo = REGEX_UUID.test(chave) ? 'id' : 'slug';

    const { rows } = await db.query(
      `select * from restaurantes where ${campo} = $1 and ativo = true`,
      [chave]
    );

    if (!rows[0]) throw AppError.naoEncontrado('Restaurante');

    req.restaurante = rows[0];
    proximo();
  } catch (erro) {
    proximo(erro);
  }
}

/**
 * Exige que o usuario autenticado seja membro ATIVO do restaurante da rota
 * e que seu perfil esteja na lista permitida (RN-SEG-002).
 * Coloca o perfil em req.perfil.
 */
function exigirPerfil(...perfisPermitidos) {
  return async function (req, _res, proximo) {
    try {
      if (!req.usuario) throw AppError.naoAutorizado();
      if (!req.restaurante) throw new Error('carregarRestaurante deve rodar antes de exigirPerfil');

      const { rows } = await db.query(
        `select perfil from restaurante_membros
          where restaurante_id = $1 and usuario_id = $2 and ativo = true`,
        [req.restaurante.id, req.usuario.id]
      );

      const vinculo = rows[0];
      if (!vinculo) {
        throw AppError.proibido('Voce nao faz parte da equipe deste restaurante.');
      }
      if (perfisPermitidos.length && !perfisPermitidos.includes(vinculo.perfil)) {
        throw AppError.proibido(
          `Operacao permitida apenas para: ${perfisPermitidos.join(', ')}.`
        );
      }

      req.perfil = vinculo.perfil;
      proximo();
    } catch (erro) {
      proximo(erro);
    }
  };
}

/**
 * Carrega o perfil quando existir, sem bloquear clientes.
 * Usado em rotas que atendem tanto cliente quanto equipe (ex.: ver pedido).
 */
async function carregarPerfilSeHouver(req, _res, proximo) {
  try {
    req.perfil = null;
    if (req.usuario && req.restaurante) {
      const { rows } = await db.query(
        `select perfil from restaurante_membros
          where restaurante_id = $1 and usuario_id = $2 and ativo = true`,
        [req.restaurante.id, req.usuario.id]
      );
      req.perfil = rows[0] ? rows[0].perfil : null;
    }
    proximo();
  } catch (erro) {
    proximo(erro);
  }
}

module.exports = { carregarRestaurante, exigirPerfil, carregarPerfilSeHouver };
