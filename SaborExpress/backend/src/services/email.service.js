
'use strict';

// ============================================================
// SABOREXPRESS - SERVICO DE E-MAIL
// Integracao com a API do Brevo
// ============================================================

const BREVO_URL = 'https://api.brevo.com/v3/smtp/email';

// Protege os dados inseridos dentro do HTML.
function escaparHtml(valor) {
  return String(valor ?? '').replace(/[&<>"']/g, (caractere) => {
    const substituicoes = {
      '&': '&amp;',
      '<': '&lt;',
      '>': '&gt;',
      '"': '&quot;',
      "'": '&#39;',
    };

    return substituicoes[caractere];
  });
}

// ============================================================
// ENVIAR E-MAIL TRANSACIONAL
// ============================================================

async function enviarEmail({
  destinatario,
  nomeDestinatario,
  assunto,
  html,
  texto,
}) {
  const apiKey = process.env.BREVO_API_KEY;
  const remetenteEmail = process.env.BREVO_REMETENTE_EMAIL;
  const remetenteNome =
    process.env.BREVO_REMETENTE_NOME || 'SaborExpress';

  if (!apiKey || apiKey === 'COLE_SUA_CHAVE_AQUI') {
    throw new Error('BREVO_API_KEY nao configurada no .env.');
  }

  if (!remetenteEmail ||
      remetenteEmail === 'SEU_EMAIL_VERIFICADO') {
    throw new Error(
      'BREVO_REMETENTE_EMAIL nao configurado no .env.'
    );
  }

  const resposta = await fetch(BREVO_URL, {
    method: 'POST',
    headers: {
      'accept': 'application/json',
      'content-type': 'application/json',
      'api-key': apiKey,
    },
    body: JSON.stringify({
      sender: {
        name: remetenteNome,
        email: remetenteEmail,
      },
      to: [
        {
          email: destinatario,
          ...(nomeDestinatario
            ? { name: nomeDestinatario }
            : {}),
        },
      ],
      subject: assunto,
      htmlContent: html,
      textContent: texto,
      tags: ['recuperacao-senha'],
    }),
    signal: AbortSignal.timeout(15000),
  });

  if (!resposta.ok) {
    // Nao registra a chave de API nem o link de recuperacao.
    console.error(
      '[SaborExpress] Falha ao enviar e-mail pelo Brevo.',
      'HTTP:',
      resposta.status
    );

    throw new Error(
      'Nao foi possivel enviar o e-mail de recuperacao.'
    );
  }

  return true;
}

// ============================================================
// E-MAIL DE RECUPERACAO DE SENHA
// ============================================================

async function enviarEmailRecuperacao({
  email,
  nome,
  linkRecuperacao,
}) {
  const nomeSeguro = escaparHtml(nome || 'Cliente');
  const linkSeguro = escaparHtml(linkRecuperacao);

  const assunto = 'SaborExpress - Recuperacao de senha';

  const html = `
    <!DOCTYPE html>
    <html lang="pt-BR">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport"
            content="width=device-width, initial-scale=1">
    </head>

    <body style="
      margin:0;
      padding:30px 12px;
      background:#f5f7f5;
      font-family:Arial,sans-serif;
      color:#333333;
    ">

      <div style="
        max-width:540px;
        margin:0 auto;
        background:#ffffff;
        border-radius:18px;
        overflow:hidden;
      ">

        <div style="
          background:#26964d;
          padding:28px;
          text-align:center;
        ">
          <h1 style="
            margin:0;
            color:#ffffff;
            font-size:28px;
          ">
            SaborExpress
          </h1>

          <p style="
            color:#e7f8ec;
            margin:8px 0 0;
          ">
            Recuperacao de senha
          </p>
        </div>

        <div style="padding:30px 26px;">

          <h2 style="font-size:21px;">
            Ola, ${nomeSeguro}!
          </h2>

          <p style="line-height:1.7;">
            Recebemos uma solicitacao para redefinir
            a senha da sua conta no SaborExpress.
          </p>

          <p style="line-height:1.7;">
            Clique no botao abaixo para cadastrar
            uma nova senha.
          </p>

          <div style="
            text-align:center;
            margin:30px 0;
          ">
            <a href="${linkSeguro}" style="
              display:inline-block;
              background:#26964d;
              color:#ffffff;
              text-decoration:none;
              padding:15px 26px;
              border-radius:12px;
              font-weight:bold;
            ">
              Redefinir minha senha
            </a>
          </div>

          <p style="line-height:1.7;">
            Este link e valido por
            <strong>15 minutos</strong>
            e pode ser utilizado apenas uma vez.
          </p>

          <p style="
            line-height:1.7;
            color:#777777;
            font-size:13px;
          ">
            Se voce nao solicitou a recuperacao,
            ignore esta mensagem.
          </p>

        </div>

        <div style="
          background:#f0f5f0;
          padding:18px;
          text-align:center;
          font-size:12px;
          color:#777777;
        ">
          SaborExpress - Sistema de Gestao de Restaurante
        </div>

      </div>

    </body>
    </html>
  `;

  const texto = [
    `Ola, ${nome || 'Cliente'}!`,
    '',
    'Recebemos uma solicitacao para redefinir sua senha.',
    '',
    `Acesse: ${linkRecuperacao}`,
    '',
    'O link expira em 15 minutos e so pode ser usado uma vez.',
    '',
    'Se voce nao solicitou, ignore este e-mail.',
    '',
    'SaborExpress',
  ].join('\n');

  return enviarEmail({
    destinatario: email,
    nomeDestinatario: nome,
    assunto,
    html,
    texto,
  });
}

module.exports = {
  enviarEmail,
  enviarEmailRecuperacao,
};
