const bcrypt = require('bcryptjs');

const CUSTO = 10; // ~100ms por hash: seguro sem travar a API

/** Gera o hash que sera gravado em usuarios.senha_hash. */
async function gerarHash(senhaEmTexto) {
  return bcrypt.hash(senhaEmTexto, CUSTO);
}

/** Compara a senha digitada com o hash do banco (tempo constante). */
async function conferir(senhaEmTexto, hash) {
  if (!hash) return false;
  return bcrypt.compare(senhaEmTexto, hash);
}

module.exports = { gerarHash, conferir };
