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
 * ============================================================
 * RESUMO FINANCEIRO E OPERACIONAL
 * ============================================================
 *
 * Os dados são calculados diretamente a partir do banco.
 *
 * O período é informado pelo Flutter:
 *
 * Hoje:
 *   de = hoje
 *   ate = hoje
 *
 * Semana:
 *   de = segunda-feira
 *   ate = hoje
 *
 * Mês:
 *   de = primeiro dia do mês
 *   ate = hoje
 *
 * Ano:
 *   de = primeiro dia do ano
 *   ate = hoje
 *
 * O faturamento considera somente pedidos concluídos.
 */
rotas.get(
  '/resumo',
  validar(schemaPeriodo, 'query'),
  async (req, res, proximo) => {
    try {
      const { de, ate } = req.query;

      const { rows } = await db.query(
        `
        with periodo as (
          select
            coalesce(
              $2::date,
              current_date
            ) as inicio,

            coalesce(
              $3::date,
              current_date
            ) + interval '1 day' as fim
        )

        select
          count(*)::int as pedidos_total,

          count(*) filter (
            where p.status = 'concluido'
          )::int as pedidos_concluidos,

          count(*) filter (
            where p.status = 'cancelado'
          )::int as pedidos_cancelados,

          count(*) filter (
            where p.status not in (
              'concluido',
              'cancelado',
              'rascunho'
            )
          )::int as pedidos_em_andamento,

          coalesce(
            sum(p.subtotal) filter (
              where p.status = 'concluido'
            ),
            0
          ) as subtotal,

          coalesce(
            sum(p.taxa_entrega) filter (
              where p.status = 'concluido'
            ),
            0
          ) as taxa_entrega,

          coalesce(
            sum(p.taxa_servico) filter (
              where p.status = 'concluido'
            ),
            0
          ) as taxa_servico,

          coalesce(
            sum(p.total) filter (
              where p.status = 'concluido'
            ),
            0
          ) as faturamento,

          coalesce(
            avg(p.total) filter (
              where p.status = 'concluido'
            ),
            0
          ) as ticket_medio

        from pedidos p
        cross join periodo

        where p.restaurante_id = $1

          and p.criado_em >= periodo.inicio

          and p.criado_em < periodo.fim
        `,
        [
          req.restaurante.id,
          de || null,
          ate || null,
        ]
      );

      const resumo = rows[0];

      // ========================================================
      // FATURAMENTO POR TIPO
      // ========================================================

      const { rows: porTipo } = await db.query(
        `
        select
          p.tipo,

          count(*)::int as pedidos,

          coalesce(
            sum(p.total),
            0
          ) as faturamento

        from pedidos p

        where p.restaurante_id = $1

          and p.status = 'concluido'

          and p.criado_em >= coalesce(
            $2::date,
            current_date
          )

          and p.criado_em < (
            coalesce(
              $3::date,
              current_date
            ) + interval '1 day'
          )

        group by p.tipo

        order by faturamento desc
        `,
        [
          req.restaurante.id,
          de || null,
          ate || null,
        ]
      );

      // ========================================================
      // VERIFICAR SE EXISTEM DADOS
      // ========================================================

      const possuiDados =
        Number(resumo?.pedidos_total ?? 0) > 0;

      res.json({
        possui_dados: possuiDados,

        periodo: {
          de: de || null,
          ate: ate || null,
        },

        pedidos_total:
          resumo?.pedidos_total ?? 0,

        pedidos_concluidos:
          resumo?.pedidos_concluidos ?? 0,

        pedidos_cancelados:
          resumo?.pedidos_cancelados ?? 0,

        pedidos_em_andamento:
          resumo?.pedidos_em_andamento ?? 0,

        subtotal:
          resumo?.subtotal ?? 0,

        taxa_entrega:
          resumo?.taxa_entrega ?? 0,

        taxa_servico:
          resumo?.taxa_servico ?? 0,

        faturamento:
          resumo?.faturamento ?? 0,

        ticket_medio:
          resumo?.ticket_medio ?? 0,

        porTipo,
      });
    } catch (erro) {
      proximo(erro);
    }
  }
);

/**
 * ============================================================
 * PRODUTOS MAIS PEDIDOS
 * ============================================================
 *
 * Consulta diretamente os itens dos pedidos no banco.
 *
 * Regras:
 *
 * - somente pedidos concluídos;
 * - itens cancelados não contam;
 * - soma a quantidade pedida;
 * - ordena do mais pedido para o menos pedido;
 * - respeita o período informado.
 */
rotas.get(
  '/mais-vendidos',
  validar(schemaPeriodo, 'query'),
  async (req, res, proximo) => {
    try {
      const { de, ate } = req.query;

      const { rows } = await db.query(
        `
        select
          i.produto_nome,

          sum(
            i.quantidade
          )::int as unidades,

          coalesce(
            sum(i.total),
            0
          ) as receita

        from pedido_itens i

        join pedidos p
          on p.id = i.pedido_id

        where p.restaurante_id = $1

          and p.status = 'concluido'

          and i.status <> 'cancelado'

          and p.criado_em >= coalesce(
            $2::date,
            current_date
          )

          and p.criado_em < (
            coalesce(
              $3::date,
              current_date
            ) + interval '1 day'
          )

        group by i.produto_nome

        order by
          unidades desc,
          receita desc

        limit 10
        `,
        [
          req.restaurante.id,
          de || null,
          ate || null,
        ]
      );

      res.json(rows);
    } catch (erro) {
      proximo(erro);
    }
  }
);

/**
 * ============================================================
 * HISTÓRICO DE UTILIZAÇÃO DAS MESAS
 * ============================================================
 */

rotas.get(
  '/mesas',
  async (req, res, proximo) => {
    try {
      const { rows } = await db.query(
        `
        select
          m.numero,

          count(
            s.id
          )::int as comandas,

          coalesce(
            avg(
              extract(
                epoch from (
                  s.fechada_em -
                  s.aberta_em
                )
              ) / 60
            ),
            0
          )::int as minutos_medios,

          coalesce(
            sum(
              p.total
            ),
            0
          ) as faturamento

        from mesas m

        left join sessoes_mesa s
          on s.mesa_id = m.id

          and s.status = 'fechada'

        left join pedidos p
          on p.sessao_mesa_id = s.id

          and p.status = 'concluido'

        where m.restaurante_id = $1

        group by m.numero

        order by m.numero
        `,
        [
          req.restaurante.id,
        ]
      );

      res.json(rows);
    } catch (erro) {
      proximo(erro);
    }
  }
);

/**
 * ============================================================
 * SITUAÇÃO ATUAL DAS MESAS
 * ============================================================
 *
 * Utilizado pelo dashboard do gerente.
 */

rotas.get(
  '/mesas-ocupadas',
  async (req, res, proximo) => {
    try {
      const { rows } = await db.query(
        `
        select
          count(*)::int as total_mesas,

          count(*) filter (
            where exists (
              select 1

              from sessoes_mesa s

              where s.mesa_id = m.id

                and s.status = 'aberta'
            )
          )::int as mesas_ocupadas

        from mesas m

        where m.restaurante_id = $1

          and m.ativo = true
        `,
        [
          req.restaurante.id,
        ]
      );

      const totalMesas =
        rows[0]?.total_mesas ?? 0;

      const mesasOcupadas =
        rows[0]?.mesas_ocupadas ?? 0;

      res.json({
        total_mesas:
          totalMesas,

        mesas_ocupadas:
          mesasOcupadas,

        mesas_livres:
          totalMesas - mesasOcupadas,
      });
    } catch (erro) {
      proximo(erro);
    }
  }
);

module.exports = rotas;