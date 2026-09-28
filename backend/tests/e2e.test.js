/**
 * Teste end-to-end da API do SaborExpress.
 * Sobe o app em memoria (supertest), usa o PostgreSQL real e percorre os
 * tres fluxos do negocio -- mesa, delivery e retirada -- alem das regras
 * que precisam BARRAR operacoes invalidas.
 *
 * Pre-requisito: banco criado e .env apontando para ele.
 * Executar: npm test
 */
process.env.NODE_ENV = 'test';

const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { execFileSync } = require('node:child_process');
const path = require('node:path');
const request = require('supertest');

const app = require('../src/app');
const db = require('../src/db');

const API = '/api';
const SENHA = 'senha123';

const ctx = {}; // guarda tokens e ids entre os testes

function autorizado(requisicao, token) {
  return requisicao.set('Authorization', `Bearer ${token}`);
}

before(() => {
  // Banco limpo e populado a cada execucao: teste nao depende de rodada anterior.
  execFileSync(process.execPath, [path.join(__dirname, '..', 'scripts', 'migrate.js'), '--reset'], {
    stdio: 'pipe',
  });
});

after(async () => {
  await db.encerrar();
});

// ---------------------------------------------------------------------
test('saude da API responde com banco ok', async () => {
  const resposta = await request(app).get(`${API}/saude`).expect(200);
  assert.equal(resposta.body.banco, 'ok');
});

test('login funciona e devolve os vinculos do funcionario', async () => {
  const gerente = await request(app)
    .post(`${API}/auth/login`)
    .send({ email: 'gerente@saborexpress.com', senha: SENHA })
    .expect(200);

  assert.ok(gerente.body.token, 'deveria devolver token');
  assert.equal(gerente.body.vinculos[0].perfil, 'gerente');
  assert.equal(gerente.body.usuario.senha_hash, undefined, 'nao pode vazar hash de senha');

  ctx.tokenGerente = gerente.body.token;
  ctx.restauranteId = gerente.body.vinculos[0].restaurante_id;

  const garcom = await request(app)
    .post(`${API}/auth/login`)
    .send({ email: 'garcom@saborexpress.com', senha: SENHA })
    .expect(200);
  ctx.tokenGarcom = garcom.body.token;

  const cliente = await request(app)
    .post(`${API}/auth/login`)
    .send({ email: 'cliente@email.com', senha: SENHA })
    .expect(200);
  ctx.tokenCliente = cliente.body.token;
  ctx.clienteId = cliente.body.usuario.id;

  const bella = await request(app)
    .post(`${API}/auth/login`)
    .send({ email: 'gerente@cantinabella.com', senha: SENHA })
    .expect(200);
  ctx.tokenBella = bella.body.token;
  ctx.restauranteBellaId = bella.body.vinculos[0].restaurante_id;
});

test('login com senha errada nao revela se o e-mail existe', async () => {
  const inexistente = await request(app)
    .post(`${API}/auth/login`)
    .send({ email: 'naoexiste@email.com', senha: 'qualquer1' })
    .expect(401);

  const senhaErrada = await request(app)
    .post(`${API}/auth/login`)
    .send({ email: 'cliente@email.com', senha: 'errada12' })
    .expect(401);

  assert.equal(inexistente.body.erro, senhaErrada.body.erro);
});

test('cadastro exige senha forte', async () => {
  const fraca = await request(app)
    .post(`${API}/auth/registrar`)
    .send({ nome: 'Teste Fraco', email: 'fraco@email.com', senha: '123' })
    .expect(400);
  assert.equal(fraca.body.codigo, 'VALIDACAO');

  await request(app)
    .post(`${API}/auth/registrar`)
    .send({ nome: 'Novo Cliente', email: 'novo@email.com', senha: 'abc12345' })
    .expect(201);
});

test('cardapio publico mostra so o que esta ativo e disponivel', async () => {
  const resposta = await request(app)
    .get(`${API}/restaurantes/sabor-express/produtos`)
    .expect(200);

  assert.ok(resposta.body.length >= 6);
  assert.ok(resposta.body.every((p) => p.disponivel && p.ativo));
  assert.equal(typeof resposta.body[0].preco, 'number', 'preco deve chegar como numero');

  ctx.produtos = Object.fromEntries(resposta.body.map((p) => [p.nome, p]));
});

// ---------------------------------------------------------------------
// Fluxo 1: MESA (garcom)
// ---------------------------------------------------------------------
test('garcom abre comanda, lanca pedido e a mesa fica ocupada', async () => {
  const mesas = await autorizado(
    request(app).get(`${API}/restaurantes/${ctx.restauranteId}/mesas`),
    ctx.tokenGarcom
  ).expect(200);

  const mesa1 = mesas.body.find((m) => m.numero === 1);
  assert.equal(mesa1.status, 'livre');
  ctx.mesaId = mesa1.id;

  const sessao = await autorizado(
    request(app)
      .post(`${API}/restaurantes/${ctx.restauranteId}/mesas/${ctx.mesaId}/sessoes`)
      .send({ qtdPessoas: 3 }),
    ctx.tokenGarcom
  ).expect(201);
  ctx.sessaoId = sessao.body.id;

  const depois = await autorizado(
    request(app).get(`${API}/restaurantes/${ctx.restauranteId}/mesas`),
    ctx.tokenGarcom
  ).expect(200);
  assert.equal(depois.body.find((m) => m.numero === 1).status, 'ocupada');
});

test('nao e possivel abrir duas comandas na mesma mesa', async () => {
  const conflito = await autorizado(
    request(app)
      .post(`${API}/restaurantes/${ctx.restauranteId}/mesas/${ctx.mesaId}/sessoes`)
      .send({ qtdPessoas: 2 }),
    ctx.tokenGarcom
  ).expect(409);
  assert.match(conflito.body.erro, /comanda aberta/i);
});

test('pedido de mesa calcula subtotal e taxa de servico de 10%', async () => {
  const pedido = await autorizado(
    request(app)
      .post(`${API}/restaurantes/${ctx.restauranteId}/pedidos`)
      .send({ tipo: 'mesa', sessaoMesaId: ctx.sessaoId }),
    ctx.tokenGarcom
  ).expect(201);
  ctx.pedidoMesaId = pedido.body.id;
  assert.match(pedido.body.codigo, /^\d{8}-\d{4}$/);

  await autorizado(
    request(app)
      .post(`${API}/restaurantes/${ctx.restauranteId}/pedidos/${ctx.pedidoMesaId}/itens`)
      .send({ produtoId: ctx.produtos['Pizza de Bacon'].id, quantidade: 1 }),
    ctx.tokenGarcom
  ).expect(201);

  const comBebida = await autorizado(
    request(app)
      .post(`${API}/restaurantes/${ctx.restauranteId}/pedidos/${ctx.pedidoMesaId}/itens`)
      .send({
        produtoId: ctx.produtos['Coca-Cola Lata 350ml'].id,
        quantidade: 2,
        observacao: 'Bem gelada',
      }),
    ctx.tokenGarcom
  ).expect(201);

  // 45,00 + (2 x 6,00) = 57,00 -> servico 10% = 5,70 -> total 62,70
  assert.equal(comBebida.body.pedido.subtotal, 57);
  assert.equal(comBebida.body.pedido.taxa_servico, 5.7);
  assert.equal(comBebida.body.pedido.total, 62.7);
});

test('produto de outro restaurante nao entra no pedido', async () => {
  const bella = await request(app)
    .get(`${API}/restaurantes/cantina-bella/produtos`)
    .expect(200);
  const nhoque = bella.body.find((p) => p.nome === 'Nhoque ao Sugo');

  const negado = await autorizado(
    request(app)
      .post(`${API}/restaurantes/${ctx.restauranteId}/pedidos/${ctx.pedidoMesaId}/itens`)
      .send({ produtoId: nhoque.id, quantidade: 1 }),
    ctx.tokenGarcom
  ).expect(404);
  assert.match(negado.body.erro, /Produto nao encontrado/i);
});

test('cliente recusa a taxa de servico e ela sai da conta', async () => {
  await autorizado(
    request(app)
      .patch(`${API}/restaurantes/${ctx.restauranteId}/sessoes/${ctx.sessaoId}/servico`)
      .send({ aceito: false }),
    ctx.tokenGarcom
  ).expect(200);

  const pedido = await autorizado(
    request(app).get(`${API}/restaurantes/${ctx.restauranteId}/pedidos/${ctx.pedidoMesaId}`),
    ctx.tokenGarcom
  ).expect(200);

  assert.equal(pedido.body.taxa_servico, 0);
  assert.equal(pedido.body.total, 57);

  // volta a aceitar para o restante do teste
  await autorizado(
    request(app)
      .patch(`${API}/restaurantes/${ctx.restauranteId}/sessoes/${ctx.sessaoId}/servico`)
      .send({ aceito: true }),
    ctx.tokenGarcom
  ).expect(200);
});

test('transicao de status invalida e recusada', async () => {
  const erro = await autorizado(
    request(app)
      .patch(`${API}/restaurantes/${ctx.restauranteId}/pedidos/${ctx.pedidoMesaId}/status`)
      .send({ status: 'pronto' }),
    ctx.tokenGarcom
  ).expect(422);

  assert.equal(erro.body.codigo, 'TRANSICAO_INVALIDA');
});

test('pedido confirmado vai para a fila da cozinha e fecha o ciclo', async () => {
  await autorizado(
    request(app).post(`${API}/restaurantes/${ctx.restauranteId}/pedidos/${ctx.pedidoMesaId}/confirmar`),
    ctx.tokenGarcom
  ).expect(200);

  const fila = await autorizado(
    request(app).get(`${API}/restaurantes/${ctx.restauranteId}/cozinha/fila`),
    ctx.tokenGarcom
  ).expect(200);

  assert.equal(fila.body.length, 2);

  // cozinha marca os dois itens como prontos -> pedido vira "pronto" sozinho
  for (const item of fila.body) {
    await autorizado(
      request(app)
        .patch(`${API}/restaurantes/${ctx.restauranteId}/cozinha/itens/${item.item_id}/status`)
        .send({ status: 'em_preparo' }),
      ctx.tokenGarcom
    ).expect(200);
  }
  for (const item of fila.body) {
    await autorizado(
      request(app)
        .patch(`${API}/restaurantes/${ctx.restauranteId}/cozinha/itens/${item.item_id}/status`)
        .send({ status: 'pronto' }),
      ctx.tokenGarcom
    ).expect(200);
  }

  const pedido = await autorizado(
    request(app).get(`${API}/restaurantes/${ctx.restauranteId}/pedidos/${ctx.pedidoMesaId}`),
    ctx.tokenGarcom
  ).expect(200);
  assert.equal(pedido.body.status, 'pronto');
  assert.ok(pedido.body.historico.length >= 3, 'historico de status deve estar registrado');
});

test('pedido nao pode ser concluido sem pagamento', async () => {
  const erro = await autorizado(
    request(app)
      .patch(`${API}/restaurantes/${ctx.restauranteId}/pedidos/${ctx.pedidoMesaId}/status`)
      .send({ status: 'concluido' }),
    ctx.tokenGarcom
  ).expect(422);

  assert.equal(erro.body.codigo, 'PAGAMENTO_PENDENTE');
});

test('conta dividida: dois pagamentos parciais fecham o pedido', async () => {
  const parcial1 = await autorizado(
    request(app)
      .post(`${API}/restaurantes/${ctx.restauranteId}/pedidos/${ctx.pedidoMesaId}/pagamentos`)
      .send({ metodo: 'dinheiro', valor: 30 }),
    ctx.tokenGarcom
  ).expect(201);

  await autorizado(
    request(app).post(`${API}/restaurantes/${ctx.restauranteId}/pagamentos/${parcial1.body.id}/confirmar`),
    ctx.tokenGarcom
  ).expect(200);

  const meio = await autorizado(
    request(app).get(`${API}/restaurantes/${ctx.restauranteId}/pedidos/${ctx.pedidoMesaId}`),
    ctx.tokenGarcom
  ).expect(200);
  assert.equal(meio.body.status_pagamento, 'parcial');

  // tentar pagar mais do que falta e barrado
  const excedente = await autorizado(
    request(app)
      .post(`${API}/restaurantes/${ctx.restauranteId}/pedidos/${ctx.pedidoMesaId}/pagamentos`)
      .send({ metodo: 'pix', valor: 100 }),
    ctx.tokenGarcom
  ).expect(422);
  assert.equal(excedente.body.codigo, 'VALOR_EXCEDE_TOTAL');

  // sem informar valor, cobra exatamente o saldo restante (62,70 - 30 = 32,70)
  const parcial2 = await autorizado(
    request(app)
      .post(`${API}/restaurantes/${ctx.restauranteId}/pedidos/${ctx.pedidoMesaId}/pagamentos`)
      .send({ metodo: 'pix', idempotencyKey: 'chave-conta-mesa-01' }),
    ctx.tokenGarcom
  ).expect(201);
  assert.equal(parcial2.body.valor, 32.7);
  assert.ok(parcial2.body.qr_code, 'pix deve devolver QR Code');

  // reenviar a MESMA chave nao cria uma segunda cobranca
  const repetido = await autorizado(
    request(app)
      .post(`${API}/restaurantes/${ctx.restauranteId}/pedidos/${ctx.pedidoMesaId}/pagamentos`)
      .send({ metodo: 'pix', idempotencyKey: 'chave-conta-mesa-01' }),
    ctx.tokenGarcom
  ).expect(200);
  assert.equal(repetido.body.id, parcial2.body.id);

  await autorizado(
    request(app).post(`${API}/restaurantes/${ctx.restauranteId}/pagamentos/${parcial2.body.id}/confirmar`),
    ctx.tokenGarcom
  ).expect(200);

  const pago = await autorizado(
    request(app).get(`${API}/restaurantes/${ctx.restauranteId}/pedidos/${ctx.pedidoMesaId}`),
    ctx.tokenGarcom
  ).expect(200);
  assert.equal(pago.body.status_pagamento, 'pago');
});

test('comanda so fecha depois que o pedido e concluido, e libera a mesa', async () => {
  const cedo = await autorizado(
    request(app).post(`${API}/restaurantes/${ctx.restauranteId}/sessoes/${ctx.sessaoId}/fechar`),
    ctx.tokenGarcom
  ).expect(422);
  assert.equal(cedo.body.codigo, 'PEDIDO_EM_PRODUCAO');

  await autorizado(
    request(app)
      .patch(`${API}/restaurantes/${ctx.restauranteId}/pedidos/${ctx.pedidoMesaId}/status`)
      .send({ status: 'concluido' }),
    ctx.tokenGarcom
  ).expect(200);

  await autorizado(
    request(app).post(`${API}/restaurantes/${ctx.restauranteId}/sessoes/${ctx.sessaoId}/fechar`),
    ctx.tokenGarcom
  ).expect(200);

  const mesas = await autorizado(
    request(app).get(`${API}/restaurantes/${ctx.restauranteId}/mesas`),
    ctx.tokenGarcom
  ).expect(200);
  assert.equal(mesas.body.find((m) => m.numero === 1).status, 'livre');
});

// ---------------------------------------------------------------------
// Fluxo 2: DELIVERY (cliente)
// ---------------------------------------------------------------------
test('delivery respeita pedido minimo e calcula a taxa de entrega', async () => {
  const enderecos = await autorizado(request(app).get(`${API}/meus/enderecos`), ctx.tokenCliente)
    .expect(200);
  ctx.enderecoId = enderecos.body[0].id;

  const pedido = await autorizado(
    request(app)
      .post(`${API}/restaurantes/${ctx.restauranteId}/pedidos`)
      .send({ tipo: 'delivery', enderecoId: ctx.enderecoId }),
    ctx.tokenCliente
  ).expect(201);
  ctx.pedidoDeliveryId = pedido.body.id;

  // Item barato: fica abaixo do pedido minimo de R$ 25,00
  await autorizado(
    request(app)
      .post(`${API}/restaurantes/${ctx.restauranteId}/pedidos/${ctx.pedidoDeliveryId}/itens`)
      .send({ produtoId: ctx.produtos['Coca-Cola Lata 350ml'].id, quantidade: 1 }),
    ctx.tokenCliente
  ).expect(201);

  const abaixo = await autorizado(
    request(app).post(`${API}/restaurantes/${ctx.restauranteId}/pedidos/${ctx.pedidoDeliveryId}/confirmar`),
    ctx.tokenCliente
  ).expect(422);
  assert.equal(abaixo.body.codigo, 'PEDIDO_MINIMO');

  // Agora passa do minimo, mas nao do frete gratis (R$ 120,00)
  await autorizado(
    request(app)
      .post(`${API}/restaurantes/${ctx.restauranteId}/pedidos/${ctx.pedidoDeliveryId}/itens`)
      .send({ produtoId: ctx.produtos['Pizza Calabresa'].id, quantidade: 1 }),
    ctx.tokenCliente
  ).expect(201);

  const confirmado = await autorizado(
    request(app).post(`${API}/restaurantes/${ctx.restauranteId}/pedidos/${ctx.pedidoDeliveryId}/confirmar`),
    ctx.tokenCliente
  ).expect(200);

  assert.equal(confirmado.body.subtotal, 48);
  assert.equal(confirmado.body.taxa_entrega, 10);
  assert.equal(confirmado.body.taxa_servico, 0, 'delivery nao cobra taxa de servico');
  assert.equal(confirmado.body.total, 58);
});

test('cliente nao enxerga pedido de outro cliente', async () => {
  const outro = await request(app)
    .post(`${API}/auth/registrar`)
    .send({ nome: 'Intruso Silva', email: 'intruso@email.com', senha: 'abc12345' })
    .expect(201);

  const negado = await autorizado(
    request(app).get(`${API}/restaurantes/${ctx.restauranteId}/pedidos/${ctx.pedidoDeliveryId}`),
    outro.body.token
  ).expect(403);

  assert.equal(negado.body.codigo, 'PROIBIDO');
});

test('cliente nao pode se promover a gerente nem ver relatorio', async () => {
  const negado = await autorizado(
    request(app).get(`${API}/restaurantes/${ctx.restauranteId}/relatorios/resumo`),
    ctx.tokenCliente
  ).expect(403);
  assert.match(negado.body.erro, /equipe deste restaurante/i);
});

test('pagamento em dinheiro nao pode ser aprovado pelo proprio cliente', async () => {
  const pagamento = await autorizado(
    request(app)
      .post(`${API}/restaurantes/${ctx.restauranteId}/pedidos/${ctx.pedidoDeliveryId}/pagamentos`)
      .send({ metodo: 'na_entrega' }),
    ctx.tokenCliente
  ).expect(201);

  const negado = await autorizado(
    request(app).post(`${API}/restaurantes/${ctx.restauranteId}/pagamentos/${pagamento.body.id}/confirmar`),
    ctx.tokenCliente
  ).expect(403);
  assert.match(negado.body.erro, /equipe do restaurante/i);

  // o entregador (aqui, o garcom) confirma no recebimento
  await autorizado(
    request(app).post(`${API}/restaurantes/${ctx.restauranteId}/pagamentos/${pagamento.body.id}/confirmar`),
    ctx.tokenGarcom
  ).expect(200);
});

test('delivery percorre em_preparo -> pronto -> em_entrega -> concluido', async () => {
  const rota = `${API}/restaurantes/${ctx.restauranteId}/pedidos/${ctx.pedidoDeliveryId}/status`;

  for (const status of ['em_preparo', 'pronto', 'em_entrega', 'concluido']) {
    await autorizado(request(app).patch(rota).send({ status }), ctx.tokenGarcom).expect(200);
  }

  const final = await autorizado(
    request(app).get(`${API}/restaurantes/${ctx.restauranteId}/pedidos/${ctx.pedidoDeliveryId}`),
    ctx.tokenGarcom
  ).expect(200);

  assert.equal(final.body.status, 'concluido');
  assert.ok(final.body.itens.every((i) => i.status === 'entregue'));
});

// ---------------------------------------------------------------------
// Fluxo 3: RETIRADA + cancelamento
// ---------------------------------------------------------------------
test('retirada nao cobra entrega nem servico, e cliente pode cancelar antes do preparo', async () => {
  const pedido = await autorizado(
    request(app).post(`${API}/restaurantes/${ctx.restauranteId}/pedidos`).send({ tipo: 'retirada' }),
    ctx.tokenCliente
  ).expect(201);

  await autorizado(
    request(app)
      .post(`${API}/restaurantes/${ctx.restauranteId}/pedidos/${pedido.body.id}/itens`)
      .send({ produtoId: ctx.produtos['Pudim da Casa'].id, quantidade: 2 }),
    ctx.tokenCliente
  ).expect(201);

  const confirmado = await autorizado(
    request(app).post(`${API}/restaurantes/${ctx.restauranteId}/pedidos/${pedido.body.id}/confirmar`),
    ctx.tokenCliente
  ).expect(200);

  assert.equal(confirmado.body.total, 24);
  assert.equal(confirmado.body.taxa_entrega, 0);
  assert.equal(confirmado.body.taxa_servico, 0);

  const cancelado = await autorizado(
    request(app)
      .patch(`${API}/restaurantes/${ctx.restauranteId}/pedidos/${pedido.body.id}/status`)
      .send({ status: 'cancelado', motivo: 'Mudei de ideia' }),
    ctx.tokenCliente
  ).expect(200);
  assert.equal(cancelado.body.status, 'cancelado');
});

test('cliente nao cancela pedido que ja esta em preparo', async () => {
  const pedido = await autorizado(
    request(app).post(`${API}/restaurantes/${ctx.restauranteId}/pedidos`).send({ tipo: 'retirada' }),
    ctx.tokenCliente
  ).expect(201);

  await autorizado(
    request(app)
      .post(`${API}/restaurantes/${ctx.restauranteId}/pedidos/${pedido.body.id}/itens`)
      .send({ produtoId: ctx.produtos['X-Bacon Artesanal'].id, quantidade: 1 }),
    ctx.tokenCliente
  ).expect(201);

  await autorizado(
    request(app).post(`${API}/restaurantes/${ctx.restauranteId}/pedidos/${pedido.body.id}/confirmar`),
    ctx.tokenCliente
  ).expect(200);

  await autorizado(
    request(app)
      .patch(`${API}/restaurantes/${ctx.restauranteId}/pedidos/${pedido.body.id}/status`)
      .send({ status: 'em_preparo' }),
    ctx.tokenGarcom
  ).expect(200);

  const negado = await autorizado(
    request(app)
      .patch(`${API}/restaurantes/${ctx.restauranteId}/pedidos/${pedido.body.id}/status`)
      .send({ status: 'cancelado', motivo: 'Desisti' }),
    ctx.tokenCliente
  ).expect(422);

  assert.equal(negado.body.codigo, 'CANCELAMENTO_TARDIO');
});

test('cancelamento exige motivo', async () => {
  const pedido = await autorizado(
    request(app).post(`${API}/restaurantes/${ctx.restauranteId}/pedidos`).send({ tipo: 'retirada' }),
    ctx.tokenCliente
  ).expect(201);

  const semMotivo = await autorizado(
    request(app)
      .patch(`${API}/restaurantes/${ctx.restauranteId}/pedidos/${pedido.body.id}/status`)
      .send({ status: 'cancelado' }),
    ctx.tokenCliente
  ).expect(422);

  assert.equal(semMotivo.body.codigo, 'MOTIVO_OBRIGATORIO');
});

test('pedido vazio nao pode ser confirmado', async () => {
  const pedido = await autorizado(
    request(app).post(`${API}/restaurantes/${ctx.restauranteId}/pedidos`).send({ tipo: 'retirada' }),
    ctx.tokenCliente
  ).expect(201);

  const erro = await autorizado(
    request(app).post(`${API}/restaurantes/${ctx.restauranteId}/pedidos/${pedido.body.id}/confirmar`),
    ctx.tokenCliente
  ).expect(422);

  assert.equal(erro.body.codigo, 'PEDIDO_VAZIO');
});

// ---------------------------------------------------------------------
// Isolamento entre restaurantes e relatorios
// ---------------------------------------------------------------------
test('gerente de um restaurante nao acessa dados do outro', async () => {
  const negado = await autorizado(
    request(app).get(`${API}/restaurantes/${ctx.restauranteBellaId}/relatorios/resumo`),
    ctx.tokenGerente
  ).expect(403);
  assert.equal(negado.body.codigo, 'PROIBIDO');

  const pedidosBella = await autorizado(
    request(app).get(`${API}/restaurantes/${ctx.restauranteBellaId}/pedidos`),
    ctx.tokenBella
  ).expect(200);
  assert.equal(pedidosBella.body.length, 0, 'restaurante novo nao tem pedidos');
});

test('relatorio conta so pedidos concluidos e destaca a taxa de servico', async () => {
  const resumo = await autorizado(
    request(app).get(`${API}/restaurantes/${ctx.restauranteId}/relatorios/resumo`),
    ctx.tokenGerente
  ).expect(200);

  // 1 pedido de mesa (62,70) + 1 delivery (58,00) concluidos
  assert.equal(resumo.body.pedidos_concluidos, 2);
  assert.equal(resumo.body.faturamento, 120.7);
  assert.equal(resumo.body.taxa_servico, 5.7);
  assert.equal(resumo.body.taxa_entrega, 10);
  assert.ok(resumo.body.pedidos_cancelados >= 1);

  const maisVendidos = await autorizado(
    request(app).get(`${API}/restaurantes/${ctx.restauranteId}/relatorios/mais-vendidos`),
    ctx.tokenGerente
  ).expect(200);

  assert.ok(maisVendidos.body.length > 0);
  assert.equal(maisVendidos.body[0].produto_nome, 'Coca-Cola Lata 350ml');
});

test('gerente cadastra produto e o cardapio publico passa a mostrar', async () => {
  const novo = await autorizado(
    request(app)
      .post(`${API}/restaurantes/${ctx.restauranteId}/produtos`)
      .send({ nome: 'Pizza Portuguesa', preco: 49.9, descricao: 'Presunto, ovo e cebola.' }),
    ctx.tokenGerente
  ).expect(201);

  const negado = await autorizado(
    request(app)
      .post(`${API}/restaurantes/${ctx.restauranteId}/produtos`)
      .send({ nome: 'Pizza Pirata', preco: 10 }),
    ctx.tokenGarcom
  ).expect(403);
  assert.match(negado.body.erro, /apenas para: gerente/i);

  // garcom pode marcar que acabou, sem poder mexer no preco
  await autorizado(
    request(app)
      .patch(`${API}/restaurantes/${ctx.restauranteId}/produtos/${novo.body.id}/disponibilidade`)
      .send({ disponivel: false }),
    ctx.tokenGarcom
  ).expect(200);

  const publico = await request(app)
    .get(`${API}/restaurantes/sabor-express/produtos`)
    .expect(200);
  assert.ok(!publico.body.some((p) => p.nome === 'Pizza Portuguesa'));
});

test('produto e desativado, nunca apagado (o historico permanece)', async () => {
  const pizza = ctx.produtos['Pizza de Bacon'];
  await autorizado(
    request(app).delete(`${API}/restaurantes/${ctx.restauranteId}/produtos/${pizza.id}`),
    ctx.tokenGerente
  ).expect(200);

  const { rows } = await db.query(
    `select count(*)::int as itens from pedido_itens where produto_nome = 'Pizza de Bacon'`
  );
  assert.ok(rows[0].itens > 0, 'o item historico continua existindo com o nome congelado');
});

test('rota inexistente devolve 404 em JSON', async () => {
  const resposta = await request(app).get(`${API}/nao-existe`).expect(404);
  assert.match(resposta.body.erro, /Rota nao encontrada/);
});
