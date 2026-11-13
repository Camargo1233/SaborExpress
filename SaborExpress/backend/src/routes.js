
const { Router } = require('express');

const db = require('./db');

const {
  carregarRestaurante,
} = require('./middlewares/restaurante');

const {
  autenticar,
} = require('./middlewares/autenticar');

// ============================================================
// IMPORTAÇÃO DAS ROTAS
// ============================================================

const authRotas = require('./modules/auth/auth.routes');

const enderecosRotas = require(
  './modules/usuarios/enderecos.routes'
);

const usuariosRotas = require(
  './modules/usuarios/usuarios.routes'
);

const catalogoRotas = require(
  './modules/catalogo/catalogo.routes'
);

const mesasRotas = require(
  './modules/mesas/mesas.routes'
);

const pedidosRotas = require(
  './modules/pedidos/pedidos.routes'
);

const pagamentosRotas = require(
  './modules/pagamentos/pagamentos.routes'
);

const relatoriosRotas = require(
  './modules/relatorios/relatorios.routes'
);

const pedidosServico = require(
  './modules/pedidos/pedidos.service'
);

const rotas = Router();

// ============================================================
// SAÚDE DA API
// ============================================================

rotas.get('/saude', async (_req, res) => {
  try {
    await db.query('select 1');

    res.json({
      status: 'ok',
      banco: 'ok',
      horario: new Date().toISOString(),
    });
  } catch (erro) {
    res.status(503).json({
      status: 'degradado',
      banco: 'indisponivel',
      erro: erro.message,
    });
  }
});

// ============================================================
// AUTENTICAÇÃO
// ============================================================

rotas.use('/auth', authRotas);

// ============================================================
// ENDEREÇOS DO CLIENTE
// ============================================================

rotas.use('/meus/enderecos', enderecosRotas);

// ============================================================
// PEDIDOS DO CLIENTE
// ============================================================

rotas.get(
  '/meus/pedidos',
  autenticar,
  async (req, res, proximo) => {
    try {
      const pedidos = await pedidosServico.meusPedidos(
        req.usuario.id
      );

      res.json(pedidos);
    } catch (erro) {
      proximo(erro);
    }
  }
);

// ============================================================
// LISTAGEM DE RESTAURANTES
// ============================================================

rotas.get(
  '/restaurantes',
  async (_req, res, proximo) => {
    try {
      const { rows } = await db.query(
        `select
            id,
            nome,
            slug,
            telefone,
            aberto,
            aceita_delivery,
            aceita_retirada,
            aceita_mesa,
            taxa_entrega_padrao,
            pedido_minimo_delivery,
            frete_gratis_acima_de,
            taxa_servico_percentual
         from restaurantes
         where ativo = true
         order by nome`
      );

      res.json(rows);
    } catch (erro) {
      proximo(erro);
    }
  }
);

// ============================================================
// CARREGAR RESTAURANTE
// ============================================================

rotas.use(
  '/restaurantes/:restauranteId',
  carregarRestaurante
);

// ============================================================
// DETALHES DO RESTAURANTE
// ============================================================

rotas.get(
  '/restaurantes/:restauranteId',
  (req, res) => {
    res.json(req.restaurante);
  }
);

// ============================================================
// CATÁLOGO
// ============================================================

rotas.use(
  '/restaurantes/:restauranteId',
  catalogoRotas
);

// ============================================================
// MESAS E COMANDAS
// ============================================================

rotas.use(
  '/restaurantes/:restauranteId',
  mesasRotas
);

// ============================================================
// PEDIDOS
//
// Inclui:
// POST /pedidos
// GET  /pedidos
// GET  /pedidos/:pedidoId
// POST /pedidos/:pedidoId/enviar
// POST /pedidos/:pedidoId/confirmar
// PATCH /pedidos/:pedidoId/status
// ============================================================

rotas.use(
  '/restaurantes/:restauranteId',
  pedidosRotas
);

// ============================================================
// PAGAMENTOS - PIX E CARTÃO
// ============================================================

rotas.use(
  '/restaurantes/:restauranteId',
  pagamentosRotas
);

// ============================================================
// RELATÓRIOS
// ============================================================

rotas.use(
  '/restaurantes/:restauranteId/relatorios',
  relatoriosRotas
);

// ============================================================
// EQUIPE DO RESTAURANTE
// ============================================================

rotas.use(
  '/restaurantes/:restauranteId/equipe',
  usuariosRotas
);

module.exports = rotas;
