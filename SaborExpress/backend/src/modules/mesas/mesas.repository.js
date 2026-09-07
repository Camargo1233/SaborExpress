const db = require('../../db');

async function listarMesas(restauranteId) {
  const { rows } = await db.query(
    `select m.id, m.numero, m.apelido, m.capacidade, m.status, m.ativo,
            s.id as sessao_id, s.aberta_em, s.qtd_pessoas,
            u.nome as garcom_nome,
            coalesce(t.total_aberto, 0) as total_aberto,
            coalesce(t.qtd_pedidos, 0)  as qtd_pedidos
       from mesas m
       left join sessoes_mesa s
              on s.mesa_id = m.id and s.status = 'aberta'
       left join usuarios u on u.id = s.aberta_por
       left join lateral (
            select sum(p.total) as total_aberto, count(*) as qtd_pedidos
              from pedidos p
             where p.sessao_mesa_id = s.id and p.status <> 'cancelado'
       ) t on true
      where m.restaurante_id = $1 and m.ativo = true
      order by m.numero`,
    [restauranteId]
  );
  return rows;
}

async function criarMesa(restauranteId, { numero, apelido, capacidade }) {
  const { rows } = await db.query(
    `insert into mesas (restaurante_id, numero, apelido, capacidade)
     values ($1, $2, $3, coalesce($4, 4))
     returning id, numero, apelido, capacidade, status, ativo`,
    [restauranteId, numero, apelido || null, capacidade]
  );
  return rows[0];
}

async function buscarMesa(restauranteId, mesaId) {
  const { rows } = await db.query(
    'select * from mesas where restaurante_id = $1 and id = $2',
    [restauranteId, mesaId]
  );
  return rows[0] || null;
}

async function abrirSessao(cliente, { restauranteId, mesaId, usuarioId, qtdPessoas }) {
  const { rows } = await cliente.query(
    `insert into sessoes_mesa (restaurante_id, mesa_id, aberta_por, qtd_pessoas)
     values ($1, $2, $3, coalesce($4, 1))
     returning id, mesa_id, status, qtd_pessoas, servico_aceito, aberta_em`,
    [restauranteId, mesaId, usuarioId, qtdPessoas]
  );
  return rows[0];
}

async function buscarSessao(restauranteId, sessaoId) {
  const { rows } = await db.query(
    `select s.*, m.numero as mesa_numero
       from sessoes_mesa s
       join mesas m on m.id = s.mesa_id
      where s.restaurante_id = $1 and s.id = $2`,
    [restauranteId, sessaoId]
  );
  return rows[0] || null;
}

async function sessaoAbertaDaMesa(restauranteId, mesaId) {
  const { rows } = await db.query(
    `select * from sessoes_mesa
      where restaurante_id = $1 and mesa_id = $2 and status = 'aberta'`,
    [restauranteId, mesaId]
  );
  return rows[0] || null;
}

/** Conta consolidada da sessao: todos os pedidos nao cancelados. */
async function contaDaSessao(restauranteId, sessaoId) {
  const { rows: pedidos } = await db.query(
    `select p.id, p.codigo, p.status, p.status_pagamento,
            p.subtotal, p.taxa_servico, p.total
       from pedidos p
      where p.restaurante_id = $1 and p.sessao_mesa_id = $2 and p.status <> 'cancelado'
      order by p.criado_em`,
    [restauranteId, sessaoId]
  );

  const { rows: itens } = await db.query(
    `select i.produto_nome, i.quantidade, i.preco_unitario, i.total, i.status, i.observacao
       from pedido_itens i
       join pedidos p on p.id = i.pedido_id
      where p.restaurante_id = $1 and p.sessao_mesa_id = $2
        and p.status <> 'cancelado' and i.status <> 'cancelado'
      order by i.criado_em`,
    [restauranteId, sessaoId]
  );

  const { rows: totais } = await db.query(
    `select coalesce(sum(p.subtotal), 0)     as subtotal,
            coalesce(sum(p.taxa_servico), 0) as taxa_servico,
            coalesce(sum(p.total), 0)        as total,
            coalesce(sum(case when p.status_pagamento = 'pago' then p.total else 0 end), 0) as total_pago
       from pedidos p
      where p.restaurante_id = $1 and p.sessao_mesa_id = $2 and p.status <> 'cancelado'`,
    [restauranteId, sessaoId]
  );

  return { pedidos, itens, totais: totais[0] };
}

async function fecharSessao(cliente, { restauranteId, sessaoId, usuarioId, status }) {
  const { rows } = await cliente.query(
    `update sessoes_mesa
        set status = $4, fechada_em = now(), fechada_por = $3
      where restaurante_id = $1 and id = $2 and status = 'aberta'
      returning id, mesa_id, status, fechada_em`,
    [restauranteId, sessaoId, usuarioId, status]
  );
  return rows[0] || null;
}

async function definirServicoAceito(restauranteId, sessaoId, aceito) {
  const { rows } = await db.query(
    `update sessoes_mesa set servico_aceito = $3
      where restaurante_id = $1 and id = $2 and status = 'aberta'
      returning id, servico_aceito`,
    [restauranteId, sessaoId, aceito]
  );
  return rows[0] || null;
}

module.exports = {
  listarMesas,
  criarMesa,
  buscarMesa,
  abrirSessao,
  buscarSessao,
  sessaoAbertaDaMesa,
  contaDaSessao,
  fecharSessao,
  definirServicoAceito,
};
