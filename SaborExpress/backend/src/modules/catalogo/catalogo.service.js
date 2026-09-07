const repositorio = require('./catalogo.repository');
const AppError = require('../../utils/AppError');

async function listarCategorias(restaurante, ehEquipe) {
  return repositorio.listarCategorias(restaurante.id, { apenasAtivas: !ehEquipe });
}

async function criarCategoria(restaurante, dados) {
  return repositorio.criarCategoria(restaurante.id, dados);
}

async function atualizarCategoria(restaurante, categoriaId, dados) {
  const categoria = await repositorio.atualizarCategoria(restaurante.id, categoriaId, dados);
  if (!categoria) throw AppError.naoEncontrado('Categoria');
  return categoria;
}

/**
 * O cardapio publico mostra apenas produtos ativos E disponiveis.
 * A equipe enxerga tudo, inclusive o que esta em falta (RN-CAT-003).
 */
async function listarProdutos(restaurante, filtros, ehEquipe) {
  return repositorio.listarProdutos(restaurante.id, {
    ...filtros,
    apenasDisponiveis: !ehEquipe,
  });
}

async function buscarProduto(restaurante, produtoId) {
  const produto = await repositorio.buscarProduto(restaurante.id, produtoId);
  if (!produto) throw AppError.naoEncontrado('Produto');
  return produto;
}

async function criarProduto(restaurante, dados) {
  if (dados.preco <= 0) {
    throw AppError.regraDeNegocio('O preco do produto deve ser maior que zero.');
  }
  return repositorio.criarProduto(restaurante.id, dados);
}

async function atualizarProduto(restaurante, produtoId, dados) {
  const produto = await repositorio.atualizarProduto(restaurante.id, produtoId, dados);
  if (!produto) throw AppError.naoEncontrado('Produto');
  return produto;
}

async function desativarProduto(restaurante, produtoId) {
  const produto = await repositorio.desativarProduto(restaurante.id, produtoId);
  if (!produto) throw AppError.naoEncontrado('Produto');
  return produto;
}

module.exports = {
  listarCategorias,
  criarCategoria,
  atualizarCategoria,
  listarProdutos,
  buscarProduto,
  criarProduto,
  atualizarProduto,
  desativarProduto,
};
