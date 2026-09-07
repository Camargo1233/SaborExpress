const db = require('../../db');

// ----------------------------- CATEGORIAS -----------------------------

async function listarCategorias(restauranteId, { apenasAtivas = true } = {}) {
  const { rows } = await db.query(
    `select id, nome, descricao, ordem, ativo
       from categorias
      where restaurante_id = $1
        and ($2::boolean is false or ativo = true)
      order by ordem, nome`,
    [restauranteId, apenasAtivas]
  );
  return rows;
}

async function criarCategoria(restauranteId, { nome, descricao, ordem }) {
  const { rows } = await db.query(
    `insert into categorias (restaurante_id, nome, descricao, ordem)
     values ($1, $2, $3, coalesce($4, 0))
     returning id, nome, descricao, ordem, ativo`,
    [restauranteId, nome, descricao || null, ordem]
  );
  return rows[0];
}

async function atualizarCategoria(restauranteId, categoriaId, dados) {
  const { rows } = await db.query(
    `update categorias
        set nome      = coalesce($3, nome),
            descricao = coalesce($4, descricao),
            ordem     = coalesce($5, ordem),
            ativo     = coalesce($6, ativo)
      where restaurante_id = $1 and id = $2
      returning id, nome, descricao, ordem, ativo`,
    [restauranteId, categoriaId, dados.nome, dados.descricao, dados.ordem, dados.ativo]
  );
  return rows[0] || null;
}

// ------------------------------ PRODUTOS ------------------------------

const CAMPOS_PRODUTO = `p.id, p.nome, p.descricao, p.preco, p.imagem_url,
       p.tempo_preparo_min, p.destaque, p.disponivel, p.ativo,
       p.categoria_id, c.nome as categoria_nome`;

async function listarProdutos(restauranteId, filtros = {}) {
  const { rows } = await db.query(
    `select ${CAMPOS_PRODUTO}
       from produtos p
       left join categorias c on c.id = p.categoria_id
      where p.restaurante_id = $1
        and ($2::boolean is false or (p.ativo = true and p.disponivel = true))
        and ($3::uuid is null or p.categoria_id = $3)
        and ($4::boolean is false or p.destaque = true)
        and ($5::text is null or p.nome ilike '%' || $5 || '%'
                              or coalesce(p.descricao, '') ilike '%' || $5 || '%')
      order by p.destaque desc, p.nome`,
    [
      restauranteId,
      filtros.apenasDisponiveis !== false,
      filtros.categoriaId || null,
      filtros.destaque === true,
      filtros.busca || null,
    ]
  );
  return rows;
}

async function buscarProduto(restauranteId, produtoId) {
  const { rows } = await db.query(
    `select ${CAMPOS_PRODUTO}
       from produtos p
       left join categorias c on c.id = p.categoria_id
      where p.restaurante_id = $1 and p.id = $2`,
    [restauranteId, produtoId]
  );
  return rows[0] || null;
}

async function criarProduto(restauranteId, dados) {
  const { rows } = await db.query(
    `insert into produtos (restaurante_id, categoria_id, nome, descricao, preco,
                           imagem_url, tempo_preparo_min, destaque, disponivel)
     values ($1, $2, $3, $4, $5, $6, $7, coalesce($8, false), coalesce($9, true))
     returning id, nome, descricao, preco, imagem_url, tempo_preparo_min,
               destaque, disponivel, ativo, categoria_id`,
    [
      restauranteId,
      dados.categoriaId || null,
      dados.nome,
      dados.descricao || null,
      dados.preco,
      dados.imagemUrl || null,
      dados.tempoPreparoMin ?? null,
      dados.destaque,
      dados.disponivel,
    ]
  );
  return rows[0];
}

async function atualizarProduto(restauranteId, produtoId, dados) {
  const { rows } = await db.query(
    `update produtos
        set categoria_id      = coalesce($3, categoria_id),
            nome              = coalesce($4, nome),
            descricao         = coalesce($5, descricao),
            preco             = coalesce($6, preco),
            imagem_url        = coalesce($7, imagem_url),
            tempo_preparo_min = coalesce($8, tempo_preparo_min),
            destaque          = coalesce($9, destaque),
            disponivel        = coalesce($10, disponivel),
            ativo             = coalesce($11, ativo)
      where restaurante_id = $1 and id = $2
      returning id, nome, descricao, preco, imagem_url, tempo_preparo_min,
                destaque, disponivel, ativo, categoria_id`,
    [
      restauranteId,
      produtoId,
      dados.categoriaId,
      dados.nome,
      dados.descricao,
      dados.preco,
      dados.imagemUrl,
      dados.tempoPreparoMin,
      dados.destaque,
      dados.disponivel,
      dados.ativo,
    ]
  );
  return rows[0] || null;
}

/** RN-CAT-004: produto nunca e apagado fisicamente (quebraria o historico). */
async function desativarProduto(restauranteId, produtoId) {
  const { rows } = await db.query(
    `update produtos set ativo = false, disponivel = false
      where restaurante_id = $1 and id = $2
      returning id, nome, ativo`,
    [restauranteId, produtoId]
  );
  return rows[0] || null;
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
