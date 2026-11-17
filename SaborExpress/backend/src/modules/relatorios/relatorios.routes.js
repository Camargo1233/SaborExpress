
const { Router } = require('express');
const { z } = require('zod');

const db = require('../../db');
const validar = require('../../middlewares/validar');
const { autenticar } = require('../../middlewares/autenticar');
const { exigirPerfil } = require('../../middlewares/restaurante');

const rotas = Router({ mergeParams: true });

rotas.use(autenticar, exigirPerfil('gerente'));

const FUSO = 'America/Sao_Paulo';

const schemaPeriodo = z
  .object({
    de: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
    ate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
  })
  .refine(
    ({ de, ate }) => !de || !ate || de <= ate,
    { message: 'A data inicial deve ser anterior ou igual à final.' }
  );

// Limites inclusivo/exclusivo no horário de Brasília.
// As colunas criado_em e concluido_em são timestamptz.
const periodoSQL = `
  WITH datas AS (
    SELECT
      COALESCE(
        $2::date,
        (CURRENT_TIMESTAMP AT TIME ZONE '${FUSO}')::date - 30
      ) AS data_inicio,
      COALESCE(
        $3::date,
        (CURRENT_TIMESTAMP AT TIME ZONE '${FUSO}')::date
      ) AS data_fim
  ),
  periodo AS (
    SELECT
      data_inicio::timestamp
        AT TIME ZONE '${FUSO}' AS inicio,
      (data_fim + 1)::timestamp
        AT TIME ZONE '${FUSO}' AS fim
    FROM datas
  )
`;

rotas.get(
  '/resumo',
  validar(schemaPeriodo, 'query'),
  async (req, res, proximo) => {
    try {
      const { de, ate } = req.query;
      const parametros = [req.restaurante.id, de || null, ate || null];

      const { rows } = await db.query(
        `${periodoSQL}
         SELECT
           COUNT(*) FILTER (
             WHERE p.status <> 'rascunho'
           )::int AS pedidos_total,

           COUNT(*) FILTER (
             WHERE p.status = 'concluido'
           )::int AS pedidos_concluidos,

           COUNT(*) FILTER (
             WHERE p.status = 'cancelado'
           )::int AS pedidos_cancelados,

           COUNT(*) FILTER (
             WHERE p.status NOT IN (
               'concluido', 'cancelado', 'rascunho'
             )
           )::int AS pedidos_em_andamento,

           COALESCE(
             SUM(p.subtotal) FILTER (
               WHERE p.status = 'concluido'
             ), 0
           ) AS subtotal,

           COALESCE(
             SUM(p.taxa_entrega) FILTER (
               WHERE p.status = 'concluido'
             ), 0
           ) AS taxa_entrega,

           COALESCE(
             SUM(p.taxa_servico) FILTER (
               WHERE p.status = 'concluido'
             ), 0
           ) AS taxa_servico,

           COALESCE(
             SUM(p.total) FILTER (
               WHERE p.status = 'concluido'
             ), 0
           ) AS faturamento,

           COALESCE(
             AVG(p.total) FILTER (
               WHERE p.status = 'concluido'
             ), 0
           ) AS ticket_medio

         FROM pedidos p
         CROSS JOIN periodo

         WHERE p.restaurante_id = $1
           AND (
             CASE
               WHEN p.status = 'concluido'
                 THEN p.concluido_em
               ELSE p.criado_em
             END
           ) >= periodo.inicio
           AND (
             CASE
               WHEN p.status = 'concluido'
                 THEN p.concluido_em
               ELSE p.criado_em
             END
           ) < periodo.fim`,
        parametros
      );

      const { rows: porTipo } = await db.query(
        `${periodoSQL}
         SELECT
           p.tipo,
           COUNT(*)::int AS pedidos,
           COALESCE(SUM(p.total), 0) AS faturamento

         FROM pedidos p
         CROSS JOIN periodo

         WHERE p.restaurante_id = $1
           AND p.status = 'concluido'
           AND p.concluido_em >= periodo.inicio
           AND p.concluido_em < periodo.fim

         GROUP BY p.tipo
         ORDER BY faturamento DESC`,
        parametros
      );

      const resumo = rows[0];

      res.json({
        possui_dados: Number(resumo.pedidos_total) > 0,
        periodo: {
          de: de || null,
          ate: ate || null,
        },
        ...resumo,
        porTipo,
      });
    } catch (erro) {
      proximo(erro);
    }
  }
);

rotas.get(
  '/mais-vendidos',
  validar(schemaPeriodo, 'query'),
  async (req, res, proximo) => {
    try {
      const { de, ate } = req.query;

      const { rows } = await db.query(
        `${periodoSQL}
         SELECT
           i.produto_nome,
           SUM(i.quantidade)::int AS unidades,
           COALESCE(SUM(i.total), 0) AS receita

         FROM pedido_itens i

         JOIN pedidos p
           ON p.id = i.pedido_id

         CROSS JOIN periodo

         WHERE p.restaurante_id = $1
           AND p.status = 'concluido'
           AND i.status <> 'cancelado'
           AND p.concluido_em >= periodo.inicio
           AND p.concluido_em < periodo.fim

         GROUP BY i.produto_nome
         ORDER BY unidades DESC, receita DESC
         LIMIT 10`,
        [req.restaurante.id, de || null, ate || null]
      );

      res.json(rows);
    } catch (erro) {
      proximo(erro);
    }
  }
);

// Relatório de mesas — mantido como estava.
rotas.get('/mesas', async (req, res, proximo) => {
  try {
    const { rows } = await db.query(
      `SELECT
         m.numero,

         COUNT(s.id)::int AS comandas,

         COALESCE(
           AVG(
             EXTRACT(
               EPOCH FROM (s.fechada_em - s.aberta_em)
             ) / 60
           ),
           0
         )::int AS minutos_medios,

         COALESCE(SUM(p.total), 0) AS faturamento

       FROM mesas m

       LEFT JOIN sessoes_mesa s
         ON s.mesa_id = m.id
         AND s.status = 'fechada'

       LEFT JOIN pedidos p
         ON p.sessao_mesa_id = s.id
         AND p.status = 'concluido'

       WHERE m.restaurante_id = $1

       GROUP BY m.numero
       ORDER BY m.numero`,
      [req.restaurante.id]
    );

    res.json(rows);
  } catch (erro) {
    proximo(erro);
  }
});

module.exports = rotas;
