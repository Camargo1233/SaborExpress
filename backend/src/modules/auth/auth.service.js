
const crypto = require('crypto');

const repositorio = require('./auth.repository');
const senhaUtil = require('../../utils/senha');
const token = require('../../utils/token');
const AppError = require('../../utils/AppError');
const { enviarEmailRecuperacao } = require('../../services/email.service');

/**
 * RN-USR-001: cadastro publico cria SEMPRE um cliente.
 * Perfis de equipe (gerente, garcom, cozinha) so existem por convite
 * de um gerente do restaurante -- ver modulo usuarios.
 */
async function registrar({ nome, email, telefone, senha }) {
  const existente = await repositorio.buscarPorEmail(email);

  if (existente) {
    throw AppError.conflito('Ja existe uma conta com este e-mail.');
  }

  const senhaHash = await senhaUtil.gerarHash(senha);

  const usuario = await repositorio.criar({
    nome,
    email,
    telefone,
    senhaHash,
  });

  return {
    usuario,
    token: token.gerar(usuario),
    vinculos: [],
  };
}

/**
 * RN-SEG-001: a resposta de login e sempre a mesma para
 * "e-mail inexistente" e "senha errada".
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

  return {
    usuario,
    token: token.gerar(usuario),
    vinculos,
  };
}

/**
 * Dados do usuario logado e vinculos com restaurantes.
 */
async function eu(usuario) {
  const vinculos = await repositorio.listarVinculos(usuario.id);

  return {
    usuario,
    vinculos,
  };
}

// ============================================================
// RECUPERACAO DE SENHA
// ============================================================

/**
 * Gera um token aleatorio e seguro.
 */
function gerarTokenRecuperacao() {
  return crypto.randomBytes(32).toString('hex');
}

/**
 * Gera o hash SHA-256 do token.
 * O token original nunca e salvo no banco.
 */
function gerarHashToken(tokenRecuperacao) {
  return crypto
    .createHash('sha256')
    .update(tokenRecuperacao)
    .digest('hex');
}

/**
 * Solicita a recuperacao de senha.
 *
 * Por seguranca, a resposta nao revela se o e-mail
 * informado possui cadastro.
 */
async function solicitarRecuperacaoSenha({ email }) {
  const mensagem = {
    mensagem:
      'Se o e-mail estiver cadastrado, voce recebera um link para redefinir sua senha.',
  };

  const usuario = await repositorio.buscarPorEmail(email);

  if (!usuario || !usuario.ativo) {
    return mensagem;
  }

  const urlConfigurada = process.env.RECUPERACAO_SENHA_URL;

  if (!urlConfigurada) {
    console.error(
      '[Recuperacao] RECUPERACAO_SENHA_URL nao configurada.'
    );

    throw new Error(
      'Configuracao de recuperacao de senha ausente.'
    );
  }

  const tokenRecuperacao = gerarTokenRecuperacao();
  const tokenHash = gerarHashToken(tokenRecuperacao);

  const link = new URL(urlConfigurada);

  // Flutter Web utiliza rotas com hash (#).
  if (link.hash) {
    const fragmento = link.hash.substring(1);
    const rota = new URL(
      fragmento,
      'http://localhost'
    );

    rota.searchParams.set(
      'token',
      tokenRecuperacao
    );

    link.hash = rota.pathname + rota.search;
  } else {
    link.searchParams.set(
      'token',
      tokenRecuperacao
    );
  }

  // O token expira em 15 minutos.
  await repositorio.criarRecuperacaoSenha(
    usuario.id,
    tokenHash
  );

  try {
    await enviarEmailRecuperacao({
      email: usuario.email,
      nome: usuario.nome,
      linkRecuperacao: link.toString(),
    });
  } catch (erro) {
    // Nao expor dados sensiveis nem o token no log.
    console.error(
      '[Recuperacao] Falha ao enviar e-mail:',
      erro.message
    );

    // Mantem resposta generica ao usuario.
  }

  return mensagem;
}

/**
 * Redefine a senha utilizando um token valido.
 */
async function redefinirSenha({
  tokenRecuperacao,
  novaSenha,
}) {
  const tokenHash = gerarHashToken(tokenRecuperacao);

  const recuperacao =
    await repositorio.buscarRecuperacaoSenha(
      tokenHash
    );

  if (!recuperacao) {
    throw AppError.naoAutorizado(
      'Link de recuperacao invalido ou expirado.'
    );
  }

  const novaSenhaHash =
    await senhaUtil.gerarHash(novaSenha);

  const atualizado =
    await repositorio.redefinirSenha(
      tokenHash,
      novaSenhaHash
    );

  if (!atualizado) {
    throw AppError.naoAutorizado(
      'Link de recuperacao invalido ou expirado.'
    );
  }

  return {
    mensagem: 'Senha redefinida com sucesso.',
  };
}

module.exports = {
  registrar,
  login,
  eu,
  solicitarRecuperacaoSenha,
  redefinirSenha,
};
