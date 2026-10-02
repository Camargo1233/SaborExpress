const { Router } = require('express');
const { z } = require('zod');

const db = require('../../db');
const servico = require('./mesas.service');
const validar = require('../../middlewares/validar');
const { autenticar } = require('../../middlewares/autenticar');
const { exigirPerfil } = require('../../middlewares/restaurante');

const rotas = Router({ mergeParams: true });

// ============================================================
// AUTENTICAÇÃO
// ============================================================

rotas.use(autenticar);

// ============================================================
// SCHEMAS
// ============================================================

const schemaMesa = z.object({
  numero: z.number().int().positive(),
  apelido: z.string().trim().max(40).optional(),
  capacidade: z.number().int().positive().max(50).optional(),
});

const schemaAbertura = z.object({
  qtdPessoas: z.number().int().positive().max(50).optional(),
});

// ============================================================
// MESAS DISPONÍVEIS PARA O CLIENTE
// ============================================================
//
// O cliente não precisa fazer parte da equipe.
//
// Retorna somente:
// - mesas ativas
// - mesas livres
// - mesas sem sessão aberta
//
// IMPORTANTE:
// esta rota precisa ficar ANTES de /mesas/:mesaId/...,
// para evitar conflitos de rota.
// ============================================================

rotas.get(
  '/mesas/disponiveis',
  async (req, res, proximo) => {
    try {
      console.log('>>> ENTROU EM /mesas/disponiveis');
      console.log('Usuario:', req.usuario);
      console.log('Restaurante:', req.restaurante?.slug);

      const { rows } = await db.query(
        `
        select
          m.id,
          m.numero,
          m.apelido,
          m.capacidade,
          m.status

        from mesas m

        where m.restaurante_id = $1
          and m.ativo = true
          and m.status = 'livre'

          and not exists (
            select 1
            from sessoes_mesa s
            where s.restaurante_id = m.restaurante_id
              and s.mesa_id = m.id
              and s.status = 'aberta'
          )

        order by m.numero
        `,
        [req.restaurante.id]
      );

      console.log('Mesas disponíveis encontradas:', rows.length);

      res.json(rows);
    } catch (erro) {
      proximo(erro);
    }
  }
);

// ============================================================
// RESERVAR MESA - CLIENTE
// ============================================================
//
// Reserva = abrir sessão da mesa.
//
// A mesma sessão será enxergada pelo garçom e gerente.
// O service já impede duas sessões abertas simultaneamente.
// ============================================================

rotas.post(
  '/mesas/:mesaId/reservar',
  validar(schemaAbertura),
  async (req, res, proximo) => {
    try {
      const sessao = await servico.abrirSessao(
        req.restaurante,
        req.params.mesaId,
        req.usuario,
        req.body
      );

      res.status(201).json(sessao);
    } catch (erro) {
      proximo(erro);
    }
  }
);

// ============================================================
// LISTAR TODAS AS MESAS - EQUIPE
// ============================================================

rotas.get(
  '/mesas',
  exigirPerfil('gerente', 'garcom', 'cozinha'),
  async (req, res, proximo) => {
    try {
      res.json(
        await servico.listarMesas(req.restaurante)
      );
    } catch (erro) {
      proximo(erro);
    }
  }
);

// ============================================================
// CRIAR MESA
// ============================================================

rotas.post(
  '/mesas',
  exigirPerfil('gerente'),
  validar(schemaMesa),
  async (req, res, proximo) => {
    try {
      res.status(201).json(
        await servico.criarMesa(
          req.restaurante,
          req.body
        )
      );
    } catch (erro) {
      proximo(erro);
    }
  }
);

// ============================================================
// ABRIR COMANDA / OCUPAR MESA - EQUIPE
// ============================================================

rotas.post(
  '/mesas/:mesaId/sessoes',
  exigirPerfil('gerente', 'garcom'),
  validar(schemaAbertura),
  async (req, res, proximo) => {
    try {
      const sessao = await servico.abrirSessao(
        req.restaurante,
        req.params.mesaId,
        req.usuario,
        req.body
      );

      res.status(201).json(sessao);
    } catch (erro) {
      proximo(erro);
    }
  }
);

// ============================================================
// CONTA CONSOLIDADA DA COMANDA
// ============================================================

rotas.get(
  '/sessoes/:sessaoId',
  exigirPerfil('gerente', 'garcom', 'cozinha'),
  async (req, res, proximo) => {
    try {
      res.json(
        await servico.detalharSessao(
          req.restaurante,
          req.params.sessaoId
        )
      );
    } catch (erro) {
      proximo(erro);
    }
  }
);

// ============================================================
// ACEITAR / RECUSAR TAXA DE SERVIÇO
// ============================================================

rotas.patch(
  '/sessoes/:sessaoId/servico',
  exigirPerfil('gerente', 'garcom'),
  validar(
    z.object({
      aceito: z.boolean(),
    })
  ),
  async (req, res, proximo) => {
    try {
      res.json(
        await servico.definirServico(
          req.restaurante,
          req.params.sessaoId,
          req.body.aceito
        )
      );
    } catch (erro) {
      proximo(erro);
    }
  }
);

// ============================================================
// FECHAR COMANDA / LIBERAR MESA
// ============================================================

rotas.post(
  '/sessoes/:sessaoId/fechar',
  exigirPerfil('gerente', 'garcom'),
  async (req, res, proximo) => {
    try {
      res.json(
        await servico.fecharSessao(
          req.restaurante,
          req.params.sessaoId,
          req.usuario
        )
      );
    } catch (erro) {
      proximo(erro);
    }
  }
);

// ============================================================
// ATIVIDADES RECENTES DAS MESAS
// ============================================================

rotas.get(
  '/atividades-recentes',
  exigirPerfil('gerente'),
  async (req, res, proximo) => {
    try {
      const { rows } = await db.query(
        `
        select *
        from (
          select
            s.id as sessao_id,
            m.id as mesa_id,
            m.numero as mesa_numero,
            'reservada'::text as tipo,
            'Mesa ' || m.numero || ' foi reservada' as mensagem,
            s.aberta_em as data_evento,
            null::numeric as valor

          from sessoes_mesa s

          join mesas m
            on m.id = s.mesa_id

          where s.restaurante_id = $1
            and s.status = 'aberta'

          union all

          select
            s.id as sessao_id,
            m.id as mesa_id,
            m.numero as mesa_numero,
            'fechada'::text as tipo,
            'Mesa ' || m.numero || ' teve o pedido fechado'
              as mensagem,
            s.fechada_em as data_evento,

            coalesce(
              (
                select sum(p.total)
                from pedidos p
                where p.sessao_mesa_id = s.id
                  and p.status <> 'cancelado'
              ),
              0
            ) as valor

          from sessoes_mesa s

          join mesas m
            on m.id = s.mesa_id

          where s.restaurante_id = $1
            and s.status = 'fechada'
            and s.fechada_em is not null

        ) atividades

        order by data_evento desc

        limit 10
        `,
        [req.restaurante.id]
      );

      res.json(rows);
    } catch (erro) {
      proximo(erro);
    }
  }
);

// ============================================================
// EXPORTAR ROTAS
// ============================================================

module.exports = rotas;