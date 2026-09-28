const { Router } = require('express');

const db = require('./db');
const { carregarRestaurante } = require('./middlewares/restaurante');
const { autenticar } = require('./middlewares/autenticar');

const authRotas = require('./modules/auth/auth.routes');
const enderecosRotas = require('./modules/usuarios/enderecos.routes');
const usuariosRotas = require('./modules/usuarios/usuarios.routes');
const catalogoRotas = require('./modules/catalogo/catalogo.routes');
const mesasRotas = require('./modules/mesas/mesas.routes');
const pedidosRotas = require('./modules/pedidos/pedidos.routes');
const pagamentosRotas = require('./modules/pagamentos/pagamentos.routes');
const relatoriosRotas = require('./modules/relatorios/relatorios.routes');
const pedidosServico = require('./modules/pedidos/pedidos.service');

const rotas = Router();

// ------------------------------ Saude ------------------------------
rotas.get('/saude', async (_req, res) => {
  try {
    await db.query('select 1');
    res.json({ status: 'ok', banco: 'ok', horario: new Date().toISOString() });
  } catch (erro) {
    res.status(503).json({ status: 'degradado', banco: 'indisponivel', erro: erro.message });
  }
});

// --------------------------- Autenticacao ---------------------------
rotas.use('/auth', authRotas);

// ------------------------ Recursos do cliente ------------------------
rotas.use('/meus/enderecos', enderecosRotas);

rotas.get('/meus/pedidos', autenticar, async (req, res, proximo) => {
  try {
    res.json(await pedidosServico.meusPedidos(req.usuario.id));
  } catch (erro) {
    proximo(erro);
  }
});

// -------------------------- Restaurantes ----------------------------
rotas.get('/restaurantes', async (_req, res, proximo) => {
  try {
    const { rows } = await db.query(
      `select id, nome, slug, telefone, aberto, aceita_delivery, aceita_retirada,
              aceita_mesa, taxa_entrega_padrao, pedido_minimo_delivery,
              frete_gratis_acima_de, taxa_servico_percentual
         from restaurantes
        where ativo = true
        order by nome`
    );
    res.json(rows);
  } catch (erro) {
    proximo(erro);
  }
});

// Tudo abaixo daqui vive dentro de UM restaurante (limite do tenant).
rotas.use('/restaurantes/:restauranteId', carregarRestaurante);

rotas.get('/restaurantes/:restauranteId', (req, res) => res.json(req.restaurante));

rotas.use('/restaurantes/:restauranteId', catalogoRotas);
rotas.use('/restaurantes/:restauranteId', mesasRotas);
rotas.use('/restaurantes/:restauranteId', pedidosRotas);
rotas.use('/restaurantes/:restauranteId', pagamentosRotas);
rotas.use('/restaurantes/:restauranteId/relatorios', relatoriosRotas);
rotas.use('/restaurantes/:restauranteId/equipe', usuariosRotas);

module.exports = rotas;
