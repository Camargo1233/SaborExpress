
const env = require('../../config/env');
const usuariosRepositorio = require('../auth/auth.repository');

const BASE_URL = env.asaas.baseUrl.replace(/\/+$/, '');

// Realiza requisicoes para a API do Asaas.
async function requisitarAsaas(caminho, opcoes = {}) {
  if (!env.asaas.apiKey) {
    throw new Error('ASAAS_API_KEY nao configurada no .env');
  }

  const resposta = await fetch(`${BASE_URL}${caminho}`, {
    method: opcoes.method || 'GET',
    headers: {
      access_token: env.asaas.apiKey,
      accept: 'application/json',
      'content-type': 'application/json',
      'User-Agent': 'SaborExpress/1.0',
      ...opcoes.headers,
    },
    body: opcoes.body
      ? JSON.stringify(opcoes.body)
      : undefined,
    signal: AbortSignal.timeout(15000),
  });

  const dados = await resposta.json().catch(() => ({}));

  if (!resposta.ok) {
    const detalhes =
      dados.errors
        ?.map((erro) => erro.description)
        .join('; ') || 'Erro desconhecido';

    throw new Error(
      `Erro Asaas (${resposta.status}): ${detalhes}`
    );
  }

  return dados;
}

// Cadastra um cliente no Asaas.
async function criarCliente({
  nome,
  email,
  cpfCnpj,
  referencia,
}) {
  return requisitarAsaas('/customers', {
    method: 'POST',
    body: {
      name: nome,
      email,
      ...(cpfCnpj ? { cpfCnpj } : {}),
      ...(referencia
        ? { externalReference: referencia }
        : {}),
    },
  });
}

// Cria uma cobranca Pix no Asaas.

async function criarCobrancaPix({
  clienteAsaasId,
  valor,
  vencimento,
  referencia,
}) {
  if (!clienteAsaasId) {
    throw new Error('Cliente Asaas nao informado.');
  }

  if (!Number.isFinite(Number(valor)) || Number(valor) <= 0) {
    throw new Error('Valor da cobranca Pix invalido.');
  }

  if (!vencimento || !/^\d{4}-\d{2}-\d{2}$/.test(vencimento)) {
    throw new Error('Data de vencimento invalida.');
  }

  if (!referencia) {
    throw new Error('Referencia do pedido nao informada.');
  }

  return requisitarAsaas('/payments', {
    method: 'POST',
    body: {
      customer: clienteAsaasId,
      billingType: 'PIX',
      value: Number(valor),
      dueDate: vencimento,
      externalReference: referencia,
    },
  });
}


// Busca o QR Code e o Pix copia e cola.
async function obterQrCodePix(pagamentoAsaasId) {
  return requisitarAsaas(
    `/payments/${encodeURIComponent(pagamentoAsaasId)}/pixQrCode`
  );
}

// Consulta o status de uma cobranca no Asaas.
async function consultarPagamento(pagamentoAsaasId) {
  return requisitarAsaas(
    `/payments/${encodeURIComponent(pagamentoAsaasId)}`
  );
}

// Recupera o cadastro de um cliente pela referencia externa.
async function buscarClientePorReferencia(referencia) {
  const resultado = await requisitarAsaas(
    `/customers?externalReference=${encodeURIComponent(referencia)}`
  );

  return resultado.data?.[0] || null;
}

// Busca ou cadastra o usuario no Asaas.
async function obterOuCriarClienteAsaas(usuarioId) {
  const usuario = await usuariosRepositorio.buscarPorId(usuarioId);

  if (!usuario || !usuario.ativo) {
    throw new Error('Usuario nao encontrado ou inativo.');
  }

  // Se o ID ja estiver salvo, reutiliza o cadastro.
  if (usuario.asaas_cliente_id) {
    return usuario.asaas_cliente_id;
  }

  // Verifica se o cliente ja existe no Asaas.
  let clienteAsaas = await buscarClientePorReferencia(
    usuario.id
  );

  // Se nao existir, cria um novo cadastro.
  if (!clienteAsaas) {
    clienteAsaas = await criarCliente({
      nome: usuario.nome,
      email: usuario.email,
      referencia: usuario.id,
    });
  }

  if (!clienteAsaas?.id) {
    throw new Error(
      'O Asaas nao retornou um identificador de cliente.'
    );
  }

  // Salva o ID retornado no PostgreSQL.
  const atualizado =
    await usuariosRepositorio.salvarAsaasClienteId(
      usuario.id,
      clienteAsaas.id
    );

  if (!atualizado) {
    throw new Error(
      'Nao foi possivel vincular o cliente Asaas ao usuario.'
    );
  }

  return atualizado.asaas_cliente_id;
}


 // Busca cobrancas existentes pela referencia externa.
async function buscarCobrancasPorReferencia(referencia) {
  if (!referencia) {
    throw new Error('Referencia do pagamento nao informada.');
  }

  const resultado = await requisitarAsaas(
    `/payments?externalReference=${encodeURIComponent(referencia)}`
  );

  return resultado.data || [];
}



module.exports = {
  criarCliente,
  criarCobrancaPix,
  obterQrCodePix,
  consultarPagamento,
  buscarClientePorReferencia,
  obterOuCriarClienteAsaas,
  buscarCobrancasPorReferencia,
};
