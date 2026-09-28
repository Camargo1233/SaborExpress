const AppError = require('../utils/AppError');
const env = require('../config/env');

/** Rota inexistente. */
function naoEncontrado(req, _res, proximo) {
  proximo(new AppError(`Rota nao encontrada: ${req.method} ${req.originalUrl}`, 404));
}

/** Traduz erros do PostgreSQL para mensagens de negocio. */
function traduzirErroDoBanco(erro) {
  switch (erro.code) {
    case '23505': // unique_violation
      return AppError.conflito('Ja existe um registro com esses dados.');
    case '23503': // foreign_key_violation
      return new AppError('Referencia invalida: o registro relacionado nao existe.', 422);
    case '23514': // check_violation
      return AppError.regraDeNegocio(
        `Operacao viola uma regra do banco (${erro.constraint}).`
      );
    case '22P02': // invalid_text_representation
      return new AppError('Identificador em formato invalido.', 400);
    default:
      return null;
  }
}

/** Tratador central: nenhum erro escapa sem virar resposta JSON. */
// eslint-disable-next-line no-unused-vars
function tratarErro(erro, req, res, _proximo) {
  const traduzido = erro.ehEsperado ? erro : traduzirErroDoBanco(erro) || erro;

  if (traduzido.ehEsperado) {
    return res.status(traduzido.status).json({
      erro: traduzido.message,
      codigo: traduzido.codigo,
      detalhes: traduzido.detalhes || undefined,
    });
  }

  // Erro nao previsto: loga completo no servidor, devolve generico ao cliente.
  console.error('[erro-nao-tratado]', {
    rota: `${req.method} ${req.originalUrl}`,
    mensagem: erro.message,
    stack: erro.stack,
  });

  return res.status(500).json({
    erro: 'Erro interno do servidor.',
    codigo: 'ERRO_INTERNO',
    detalhes: env.ehProducao ? undefined : erro.message,
  });
}

module.exports = { naoEncontrado, tratarErro };
