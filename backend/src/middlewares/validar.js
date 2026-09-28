const AppError = require('../utils/AppError');

/**
 * Valida body/params/query com um schema Zod antes de chegar no service.
 * Nenhum dado externo entra na regra de negocio sem passar por aqui.
 */
function validar(schema, origem = 'body') {
  return function (req, _res, proximo) {
    const resultado = schema.safeParse(req[origem]);

    if (!resultado.success) {
      const detalhes = resultado.error.issues.map((problema) => ({
        campo: problema.path.join('.') || origem,
        mensagem: problema.message,
      }));
      return proximo(
        new AppError('Dados invalidos.', 400, 'VALIDACAO', detalhes)
      );
    }

    req[origem] = resultado.data;
    proximo();
  };
}

module.exports = validar;
