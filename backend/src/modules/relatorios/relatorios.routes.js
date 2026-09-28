const { Router } = require('express');
const { z } = require('zod');

const db = require('../../db');
const validar = require('../../middlewares/validar');
const { autenticar } = require('../../middlewares/autenticar');
const { exigirPerfil } = require('../../middlewares/restaurante');

const rotas = Router({ mergeParams: true });

rotas.use(autenticar, exigirPerfil('gerente'));

const schemaPeriodo = z.object({
  de: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
  ate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
});

/**
 * RN-REL-001: faturamento considera SOMENTE pedidos concluidos.
 * Pedido cancelado ou ainda em producao nao entra no numero.
 * RN-REL-002: a taxa de servico e destacada, porque nao e receita do
 * restaurante -- e repasse a equipe.
 */
rotas.get('/resumo', validar(schemaPeriodo, 'query'), async (req, res, proximo) => {
  try {
    const { de, ate } = req.query;

    const { rows } = await db.query(
      `with periodo as (
         select coalesce($2::date, current_date - interval '30 days')      as inicio,
                coalesce($3::date, current_date) + interval '1 day'        as fim
       )
       select
         count(*) filter (where p.status = 'concluido')::int              as pedidos_concluidos,
         count(*) filter (where p.status = 'cancelado')::int              as pedidos_cancelados,
         count(*) filter (where p.status not in ('concluido','cancelado','rascunho'))::int
                                                                          as pedidos_em_andamento,
         coalesce(sum(p.subtotal)     filter (where p.status = 'concluido'), 0) as subtotal,
         coalesce(sum(p.taxa_entrega) filter (where p.status = 'concluido'), 0) as taxa_entrega,
         coalesce(sum(p.taxa_servico) filter (where p.status = 'concluido'), 0) as taxa_servico,
         coalesce(sum(p.total)        filter (where p.status = 'concluido'), 0) as faturamento,
         coalesce(avg(p.total)        filter (where p.status = 'concluido'), 0) as ticket_medio
       from pedidos p, periodo
       where p.restaurante_id = $1
         and p.criado_em >= periodo.inicio
         and p.criado_em <  periodo.fim`,
      [req.restaurante.id, de || null, ate || null]
    );

    const { rows: porTipo } = await db.query(
      `select p.tipo, count(*)::int as pedidos, coalesce(sum(p.total), 0) as faturamento
         from pedidos p
        where p.restaurante_id = $1 and p.status = 'concluido'
          and p.criado_em >= coalesce($2::date, current_date - interval '30 days')
          and p.criado_em <  coalesce($3::date, current_date) + interval '1 day'
        group by p.tipo
        order by faturamento desc`,
      [req.restaurante.id, de || null, ate || null]
    );

    res.json({ periodo: { de: de || null, ate: ate || null }, ...rows[0], porTipo });
  } catch (erro) {
    proximo(erro);
  }
});

/** RN-REL-003: itens cancelados nunca contam como venda. */
rotas.get('/mais-vendidos', validar(schemaPeriodo, 'query'), async (req, res, proximo) => {
  try {
    const { de, ate } = req.query;
    const { rows } = await db.query(
      `select i.produto_nome,
              sum(i.quantidade)::int as unidades,
              sum(i.total)           as receita
         from pedido_itens i
         join pedidos p on p.id = i.pedido_id
        where p.restaurante_id = $1
          and p.status = 'concluido'
          and i.status <> 'cancelado'
          and p.criado_em >= coalesce($2::date, current_date - interval '30 days')
          and p.criado_em <  coalesce($3::date, current_date) + interval '1 day'
        group by i.produto_nome
        order by unidades desc, receita desc
        limit 10`,
      [req.restaurante.id, de || null, ate || null]
    );
    res.json(rows);
  } catch (erro) {
    proximo(erro);
  }
});

/** Ocupacao das mesas: quantas comandas e quanto tempo em media. */
rotas.get('/mesas', async (req, res, proximo) => {
  try {
    const { rows } = await db.query(
      `select m.numero,
              count(s.id)::int as comandas,
              coalesce(avg(extract(epoch from (s.fechada_em - s.aberta_em)) / 60), 0)::int
                as minutos_medios,
              coalesce(sum(p.total), 0) as faturamento
         from mesas m
         left join sessoes_mesa s on s.mesa_id = m.id and s.status = 'fechada'
         left join pedidos p on p.sessao_mesa_id = s.id and p.status = 'concluido'
        where m.restaurante_id = $1
        group by m.numero
        order by m.numero`,
      [req.restaurante.id]
    );
    res.json(rows);
  } catch (erro) {
    proximo(erro);
  }
});

module.exports = rotas;
