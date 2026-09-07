const jwt = require('jsonwebtoken');
const env = require('../config/env');
const AppError = require('./AppError');

/**
 * O token carrega apenas o id do usuario. Perfil e restaurante NAO vao no
 * token: sao consultados no banco a cada requisicao, para que a revogacao
 * de um acesso tenha efeito imediato (RN-SEG-003).
 */
function gerar(usuario) {
  return jwt.sign({ sub: usuario.id, nome: usuario.nome }, env.jwt.secret, {
    expiresIn: env.jwt.expiresIn,
    issuer: 'saborexpress-api',
  });
}

function verificar(token) {
  try {
    return jwt.verify(token, env.jwt.secret, { issuer: 'saborexpress-api' });
  } catch (erro) {
    if (erro.name === 'TokenExpiredError') {
      throw AppError.naoAutorizado('Sessao expirada. Faca login novamente.');
    }
    throw AppError.naoAutorizado('Token invalido.');
  }
}

module.exports = { gerar, verificar };
