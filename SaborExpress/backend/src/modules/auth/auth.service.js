
const crypto = require('node:crypto');

const repositorio = require('./auth.repository');
const senhaUtil = require('../../utils/senha');
const token = require('../../utils/token');
const AppError = require('../../utils/AppError');

const {
  enviarEmailRecuperacao,
} = require('../../services/email.service');

// ============================================================
// CADASTRO DE USUARIO
// ============================================================

/**
 * RN-USR-001:
 * Cadastro publico cria sempre um cliente.
 * Perfis de equipe sao gerenciados separadamente.
 */
async function registrar({ nome, email, telefone, senha }) {
  const existente = await repositorio.buscarPorEmail(email);

  if (existente) {
    throw AppError.conflito(
      'Ja existe uma conta com este e-mail.'
    );
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

// ============================================================
// LOGIN
// ============================================================

/**
 * RN-SEG-001:
 * A mensagem de erro e igual para e-mail inexistente
 * e senha incorreta.
 */
async function login({ email, senha }) {
  const usuario = await repositorio.buscarPorEmail(email);

  const hash = usuario ? usuario.senha_hash : null;

  const senhaConfere = await senhaUtil.conferir(
    senha,
    hash
  );

  if (!usuario || !senhaConfere || !usuario.ativo) {
    throw AppError.naoAutorizado(
      'E-mail ou senha invalidos.'
    );
  }

  await repositorio.registrarLogin(usuario.id);

  const vinculos = await repositorio.listarVinculos(
    usuario.id
  );

  delete usuario.senha_hash;

  return {
    usuario,
    token: token.gerar(usuario),
    vinculos,
  };
}

// ============================================================
// USUARIO AUTENTICADO
// ============================================================

async function eu(usuario) {
  const vinculos = await repositorio.listarVinculos(
    usuario.id
  );

  return {
    usuario,
    vinculos,
  };
}

// ============================================================
// RECUPERACAO DE SENHA - GERACAO DO TOKEN
// ============================================================

function gerarTokenRecuperacao() {
  return crypto.randomBytes(32).toString('hex');
}

function gerarHashToken(tokenRecuperacao) {
  return crypto
    .createHash('sha256')
    .update(tokenRecuperacao)
    .digest('hex');
}

// ============================================================
// SOLICITAR RECUPERACAO DE SENHA
// ============================================================

async function solicitarRecuperacaoSenha({ email }) {
  // A resposta nao revela se o e-mail esta cadastrado.
  const mensagem = {
    mensagem:
      'Se este e-mail estiver cadastrado, voce recebera ' +
      'instrucoes para redefinir sua senha.',
  };

  const usuario = await repositorio.buscarPorEmail(email);

  if (!usuario || !usuario.ativo) {
    return mensagem;
  }

  // ==========================================================
  // VERIFICAR CONFIGURACAO DO LINK
  // ==========================================================

  const urlBase = process.env.RECUPERACAO_SENHA_URL;

  if (!urlBase) {
    console.error(
      '[SaborExpress] RECUPERACAO_SENHA_URL nao configurada.'
    );

    throw new Error(
      'Configuracao de recuperacao de senha ausente.'
    );
  }

  // ==========================================================
  // GERAR TOKEN SEGURO
  // ==========================================================

  const tokenRecuperacao = gerarTokenRecuperacao();

  const tokenHash = gerarHashToken(
    tokenRecuperacao
  );

  // ==========================================================
  // CONSTRUIR LINK DE RECUPERACAO
  // ==========================================================

  const url = new URL(urlBase);

  // O Flutter Web utiliza rotas com fragmento (#).
  // Se a URL possuir fragmento, adicionamos o token nele.
  if (url.hash) {
    const fragmento = url.hash.substring(1);
    const separador = fragmento.includes('?') ? '&' : '?';

    url.hash =
      `${fragmento}${separador}token=` +
      encodeURIComponent(tokenRecuperacao);
  } else {
    url.searchParams.set(
      'token',
      tokenRecuperacao
    );
  }

  const linkRecuperacao = url.toString();

  // ==========================================================
  // SALVAR HASH DO TOKEN NO POSTGRESQL
  // ==========================================================

  await repositorio.criarRecuperacaoSenha(
    usuario.id,
    tokenHash
  );

  // ==========================================================
  // ENVIAR E-MAIL PELO BREVO
  // ==========================================================

  try {
    await enviarEmailRecuperacao({
      email: usuario.email,
      nome: usuario.nome,
      linkRecuperacao,
    });
  } catch (erro) {
    // Nao expor o token ou os dados do usuario nos logs.
    console.error(
      '[SaborExpress] Falha no envio do e-mail de recuperacao:',
      erro.message
    );

    // Mantemos a mesma resposta publica para nao revelar
    // se determinado e-mail existe no sistema.
    return mensagem;
  }

  return mensagem;
}

// ============================================================
// REDEFINIR SENHA
// ============================================================

async function redefinirSenha({
  tokenRecuperacao,
  novaSenha,
}) {
  // ==========================================================
  // VALIDAR TOKEN
  // ==========================================================

  const tokenHash = gerarHashToken(
    tokenRecuperacao
  );

  const recuperacao =
    await repositorio.buscarRecuperacaoSenha(
      tokenHash
    );

  if (!recuperacao) {
    throw AppError.naoAutorizado(
      'Link de recuperacao invalido ou expirado.'
    );
  }

  // ==========================================================
  // GERAR HASH DA NOVA SENHA
  // ==========================================================

  const novaSenhaHash = await senhaUtil.gerarHash(
    novaSenha
  );

  // ==========================================================
  // ATUALIZAR SENHA NO BANCO DE DADOS
  // ==========================================================

  // O repositorio utiliza transacao para atualizar a senha
  // e invalidar os tokens de recuperacao pendentes.
  const atualizado = await repositorio.redefinirSenha(
    tokenHash,
    novaSenhaHash
  );

  if (!atualizado) {
    throw AppError.naoAutorizado(
      'Link de recuperacao invalido ou expirado.'
    );
  }

  return {
    mensagem: 'Senha atualizada com sucesso.',
  };
}

// ============================================================
// EXPORTACOES
// ============================================================

module.exports = {
  registrar,
  login,
  eu,
  solicitarRecuperacaoSenha,
  redefinirSenha,
};
