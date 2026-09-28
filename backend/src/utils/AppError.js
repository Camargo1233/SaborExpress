/**
 * Erro de negocio previsto. Diferente de um erro inesperado (bug),
 * este carrega o status HTTP e uma mensagem segura para o cliente.
 */
class AppError extends Error {
  constructor(mensagem, status = 400, codigo = null, detalhes = null) {
    super(mensagem);
    this.name = 'AppError';
    this.status = status;
    this.codigo = codigo;
    this.detalhes = detalhes;
    this.ehEsperado = true;
  }

  static naoEncontrado(recurso = 'Recurso') {
    return new AppError(`${recurso} nao encontrado.`, 404, 'NAO_ENCONTRADO');
  }

  static naoAutorizado(mensagem = 'Credenciais invalidas.') {
    return new AppError(mensagem, 401, 'NAO_AUTENTICADO');
  }

  static proibido(mensagem = 'Voce nao tem permissao para esta operacao.') {
    return new AppError(mensagem, 403, 'PROIBIDO');
  }

  static conflito(mensagem) {
    return new AppError(mensagem, 409, 'CONFLITO');
  }

  static regraDeNegocio(mensagem, codigo = 'REGRA_DE_NEGOCIO') {
    return new AppError(mensagem, 422, codigo);
  }
}

module.exports = AppError;
