const db = require('../../db');

const CAMPOS_PEDIDO = `p.id, p.codigo, p.numero_dia, p.tipo, p.canal, p.status,
  p.status_pagamento, p.subtotal, p.desconto, p.taxa_entrega, p.taxa_servico,
  p.total, p.observacao, p.motivo_cancelamento, p.previsao_entrega_min,
  p.cliente_id, p.criado_por, p.sessao_mesa_id, p.endereco_id,
  p.criado_em, p.confirmado_em, p.concluido_em`;

async function criar(cliente, dados) {
  const { rows } = await cliente.query(
    `insert into pedidos (restaurante_id, cliente_id, criado_por, sessao_mesa_id,
                          endereco_id, tipo, canal, observacao)
     values ($1, $2, $3, $4, $5, $6, $7, $8)
     returning *`,
    [
      dados.restauranteId,
      dados.clienteId || null,
      dados.criadoPor || null,
      dados.sessaoMesaId || null,
      dados.enderecoId || null,
      dados.tipo,
      dados.canal,
      dados.observacao || null,
    ]
  );
  return rows[0];
}

/** Carrega o pedido travando a linha (evita corrida entre garcom e cozinha). */
async function buscarParaAtualizar(cliente, restauranteId, pedidoId) {
  const { rows } = await cliente.query(
    'select * from pedidos where restaurante_id = $1 and id = $2 for update',
    [restauranteId, pedidoId]
  );
  return rows[0] || null;
}

async function buscar(restauranteId, pedidoId) {
  const { rows } = await db.query(
    `select ${CAMPOS_PEDIDO},
            u.nome as cliente_nome,
            m.numero as mesa_numero
       from pedidos p
       left join usuarios u on u.id = p.cliente_id
       left join sessoes_mesa s on s.id = p.sessao_mesa_id
       left join mesas m on m.id = s.mesa_id
      where p.restaurante_id = $1 and p.id = $2`,
    [restauranteId, pedidoId]
  );
  return rows[0] || null;
}

async function listarItens(pedidoId) {
  const { rows } = await db.query(
    `select id, produto_id, produto_nome, quantidade, preco_unitario, total,
            observacao, status, motivo_cancelamento, criado_em
       from pedido_itens
      where pedido_id = $1
      order by criado_em`,
    [pedidoId]
  );
  return rows;
}

async function listarHistorico(pedidoId) {
  const { rows } = await db.query(
    `select h.status_antigo, h.status_novo, h.criado_em, u.nome as alterado_por
       from pedido_status_historico h
       left join usuarios u on u.id = h.alterado_por
      where h.pedido_id = $1
      order by h.criado_em`,
    [pedidoId]
  );
  return rows;
}

async function listar(restauranteId, filtros = {}) {
  const { rows } = await db.query(
    `select ${CAMPOS_PEDIDO}, u.nome as cliente_nome, m.numero as mesa_numero
       from pedidos p
       left join usuarios u on u.id = p.cliente_id
       left join sessoes_mesa s on s.id = p.sessao_mesa_id
       left join mesas m on m.id = s.mesa_id
      where p.restaurante_id = $1
        and ($2::text is null or p.status::text = $2)
        and ($3::text is null or p.tipo::text = $3)
        and ($4::uuid is null or p.cliente_id = $4)
        and ($5::boolean is false or p.status in
             ('confirmado','em_preparo','pronto','em_entrega'))
      order by p.criado_em desc
      limit coalesce($6, 100)`,
    [
      restauranteId,
      filtros.status || null,
      filtros.tipo || null,
      filtros.clienteId || null,
      filtros.apenasAtivos === true,
      filtros.limite || null,
    ]
  );
  return rows;
}

async function listarDoCliente(clienteId, limite = 50) {
  const { rows } = await db.query(
    `select ${CAMPOS_PEDIDO}, r.nome as restaurante_nome, r.slug as restaurante_slug
       from pedidos p
       join restaurantes r on r.id = p.restaurante_id
      where p.cliente_id = $1
      order by p.criado_em desc
      limit $2`,
    [clienteId, limite]
  );
  return rows;
}

async function inserirItem(cliente, dados) {
  const { rows } = await cliente.query(
    `insert into pedido_itens (restaurante_id, pedido_id, produto_id, produto_nome,
                               preco_unitario, quantidade, observacao, status)
     values ($1, $2, $3, $4, $5, $6, $7, $8)
     returning id, produto_id, produto_nome, quantidade, preco_unitario, total,
               observacao, status`,
    [
      dados.restauranteId,
      dados.pedidoId,
      dados.produtoId,
      dados.produtoNome,
      dados.precoUnitario,
      dados.quantidade,
      dados.observacao || null,
      dados.status,
    ]
  );
  return rows[0];
}

async function buscarItem(cliente, pedidoId, itemId) {
  const { rows } = await cliente.query(
    'select * from pedido_itens where pedido_id = $1 and id = $2 for update',
    [pedidoId, itemId]
  );
  return rows[0] || null;
}

async function atualizarItem(cliente, itemId, { quantidade, observacao }) {
  const { rows } = await cliente.query(
    `update pedido_itens
        set quantidade = coalesce($2, quantidade),
            observacao = coalesce($3, observacao)
      where id = $1
      returning id, produto_nome, quantidade, preco_unitario, total, observacao, status`,
    [itemId, quantidade ?? null, observacao ?? null]
  );
  return rows[0];
}

async function cancelarItem(cliente, itemId, usuarioId, motivo) {
  const { rows } = await cliente.query(
    `update pedido_itens
        set status = 'cancelado', cancelado_por = $2, motivo_cancelamento = $3
      where id = $1
      returning id, produto_nome, status`,
    [itemId, usuarioId, motivo]
  );
  return rows[0];
}

async function atualizarStatusItem(cliente, restauranteId, itemId, status) {
  const { rows } = await cliente.query(
    `update pedido_itens set status = $3
      where restaurante_id = $1 and id = $2
      returning id, pedido_id, produto_nome, status`,
    [restauranteId, itemId, status]
  );
  return rows[0] || null;
}

async function recalcular(cliente, pedidoId) {
  await cliente.query('select recalcular_pedido($1)', [pedidoId]);
}

async function atualizarStatus(cliente, pedidoId, dados) {
  const { rows } = await cliente.query(
    // $2 chega sempre como texto e e convertido uma unica vez para o enum:
    // isso evita o erro "inconsistent types deduced for parameter".
    `update pedidos
        set status              = $2::text::pedido_status,
            criado_por          = coalesce($3::uuid, criado_por),
            motivo_cancelamento = coalesce($4::text, motivo_cancelamento),
            confirmado_em       = case when $2::text = 'confirmado' then now() else confirmado_em end,
            concluido_em        = case when $2::text = 'concluido'  then now() else concluido_em end,
            cancelado_em        = case when $2::text = 'cancelado'  then now() else cancelado_em end
      where id = $1
      returning *`,
    [pedidoId, dados.status, dados.alteradoPor || null, dados.motivo || null]
  );
  return rows[0];
}

async function definirTaxaEntrega(cliente, pedidoId, taxa, previsaoMin) {
  await cliente.query(
    `update pedidos
        set taxa_entrega = $2,
            previsao_entrega_min = coalesce($3, previsao_entrega_min),
            total = subtotal - desconto + $2 + taxa_servico
      where id = $1`,
    [pedidoId, taxa, previsaoMin ?? null]
  );
}

/** Fila da cozinha: itens que precisam ser produzidos, mais antigos primeiro. */
async function filaCozinha(restauranteId) {
  const { rows } = await db.query(
    `select i.id as item_id, i.produto_nome, i.quantidade, i.observacao, i.status,
            i.criado_em, p.id as pedido_id, p.codigo, p.tipo, m.numero as mesa_numero,
            extract(epoch from (now() - i.criado_em))::int / 60 as minutos_na_fila
       from pedido_itens i
       join pedidos p on p.id = i.pedido_id
       left join sessoes_mesa s on s.id = p.sessao_mesa_id
       left join mesas m on m.id = s.mesa_id
      where i.restaurante_id = $1
        and i.status in ('enviado_cozinha', 'em_preparo')
        and p.status not in ('cancelado', 'concluido')
      order by i.criado_em`,
    [restauranteId]
  );
  return rows;
}

async function enviarItensParaCozinha(cliente, pedidoId) {
  const { rows } = await cliente.query(
    `update pedido_itens
        set status = 'enviado_cozinha'
      where pedido_id = $1 and status = 'pendente'
      returning id`,
    [pedidoId]
  );
  return rows.length;
}

module.exports = {
  criar,
  buscar,
  buscarParaAtualizar,
  listar,
  listarDoCliente,
  listarItens,
  listarHistorico,
  inserirItem,
  buscarItem,
  atualizarItem,
  cancelarItem,
  atualizarStatusItem,
  recalcular,
  atualizarStatus,
  definirTaxaEntrega,
  filaCozinha,
  enviarItensParaCozinha,
};
