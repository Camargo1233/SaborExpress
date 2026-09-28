const repositorio = require('./auth.repository');
const senhaUtil = require('../../utils/senha');
const token = require('../../utils/token');
const AppError = require('../../utils/AppError');

/**
 * RN-USR-001: cadastro publico cria SEMPRE um cliente.
 * Perfis de equipe (gerente, garcom, cozinha) so existem por convite de um
 * gerente do restaurante -- ver modulo usuarios.
 */
async function registrar({ nome, email, telefone, senha }) {
  const existente = await repositorio.buscarPorEmail(email);
  if (existente) {
    throw AppError.conflito('Ja existe uma conta com este e-mail.');
  }

  const senhaHash = await senhaUtil.gerarHash(senha);
  const usuario = await repositorio.criar({ nome, email, telefone, senhaHash });

  return { usuario, token: token.gerar(usuario), vinculos: [] };
}

/**
 * RN-SEG-001: a resposta de login e sempre a mesma para "e-mail inexistente"
 * e "senha errada" -- nao entregamos ao atacante a informacao de quais
 * e-mails estao cadastrados.
 */
async function login({ email, senha }) {
  const usuario = await repositorio.buscarPorEmail(email);
  const hash = usuario ? usuario.senha_hash : null;
  const senhaConfere = await senhaUtil.conferir(senha, hash);

  if (!usuario || !senhaConfere || !usuario.ativo) {
    throw AppError.naoAutorizado('E-mail ou senha invalidos.');
  }

  await repositorio.registrarLogin(usuario.id);
  const vinculos = await repositorio.listarVinculos(usuario.id);

  delete usuario.senha_hash;

  return { usuario, token: token.gerar(usuario), vinculos };
}

/** Dados do usuario logado + onde ele trabalha (usado no boot do app). */
async function eu(usuario) {
  const vinculos = await repositorio.listarVinculos(usuario.id);
  return { usuario, vinculos };
}

module.exports = { registrar, login, eu };
