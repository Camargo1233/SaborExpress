# SaborExpress - API

API REST do sistema de restaurante SaborExpress. Atende os tres canais de venda
(salao/mesa, delivery e retirada) e funciona em modo **multi-restaurante**: a
mesma base atende varios estabelecimentos, cada um enxergando apenas os proprios
dados.

Stack: **Node.js + Express + PostgreSQL** (driver `pg`, sem ORM), autenticacao
**JWT + bcrypt**, validacao com **Zod**.

---

## 1. Subindo o projeto

```bash
# 1. dependencias
npm install

# 2. configuracao
cp .env.example .env      # edite DB_* e JWT_SECRET

# 3. banco (cria schema + dados de demonstracao)
npm run db:migrate        # aplica o que falta
npm run db:reset          # apaga tudo e recria (uso em desenvolvimento)

# 4. servidor
npm run dev               # com reload automatico
npm start                 # producao

# 5. testes end-to-end (29 casos cobrindo as regras de negocio)
npm test
```

A API sobe em `http://localhost:3000/api`. Verifique com `GET /api/saude`.

### Usuarios de demonstracao (senha `senha123`)

| E-mail | Perfil | Restaurante |
|---|---|---|
| `gerente@saborexpress.com` | gerente | Sabor Express |
| `garcom@saborexpress.com` | garcom | Sabor Express |
| `cozinha@saborexpress.com` | cozinha | Sabor Express |
| `gerente@cantinabella.com` | gerente | Cantina Bella |
| `cliente@email.com` | cliente | (nenhum - cliente e global) |

---

## 2. Organizacao das pastas

```
src/
  app.js                 monta o Express (helmet, cors, rate limit, rotas, erros)
  server.js              sobe o servidor e trata desligamento gracioso
  routes.js              mapa de rotas: o que e publico e o que vive sob um restaurante
  config/env.js          leitura e validacao das variaveis de ambiente
  db/index.js            pool de conexoes + helper de transacao
  middlewares/
    autenticar.js        Bearer token -> req.usuario
    restaurante.js       :restauranteId -> req.restaurante + checagem de perfil
    validar.js           Zod na borda: nada invalido chega no service
    erro.js              tratador central + traducao de erros do PostgreSQL
  modules/
    auth/                registro, login, /eu
    usuarios/            equipe do restaurante + enderecos do cliente
    catalogo/            categorias e produtos
    mesas/               mesas e comandas (sessoes)
    pedidos/             pedido, itens, maquina de estados e fila da cozinha
    pagamentos/          cobranca (mock), conta dividida, estorno
    relatorios/          faturamento, mais vendidos, ocupacao de mesas
database/migrations/     001_schema.sql, 002_seed.sql
scripts/migrate.js       executor de migrations com controle do que ja rodou
tests/e2e.test.js        teste ponta a ponta contra o banco real
```

Cada modulo segue tres camadas:

- **routes** - HTTP: caminho, permissao, validacao do payload.
- **service** - regra de negocio. E aqui que as RNs vivem.
- **repository** - SQL. Nenhuma regra, so acesso a dados.

---

## 3. Mapa de endpoints

Prefixo comum: `/api`. `{r}` = id ou slug do restaurante.

### Publico

| Metodo | Rota | Descricao |
|---|---|---|
| GET | `/saude` | healthcheck (usa o banco) |
| POST | `/auth/registrar` | cria conta de **cliente** |
| POST | `/auth/login` | devolve token + vinculos |
| GET | `/restaurantes` | lista restaurantes ativos |
| GET | `/restaurantes/{r}` | dados e parametros comerciais |
| GET | `/restaurantes/{r}/categorias` | categorias do cardapio |
| GET | `/restaurantes/{r}/produtos` | cardapio (`?categoriaId=&busca=&destaque=true`) |
| GET | `/restaurantes/{r}/produtos/:id` | detalhe do produto |

### Cliente autenticado

| Metodo | Rota | Descricao |
|---|---|---|
| GET | `/auth/eu` | usuario logado + onde trabalha |
| GET/POST | `/meus/enderecos` | enderecos de entrega |
| DELETE | `/meus/enderecos/:id` | remove endereco (logico) |
| GET | `/meus/pedidos` | historico em todos os restaurantes |

### Pedido (cliente ou equipe)

| Metodo | Rota | Descricao |
|---|---|---|
| POST | `/restaurantes/{r}/pedidos` | abre rascunho (`tipo`: mesa/delivery/retirada) |
| GET | `/restaurantes/{r}/pedidos` | lista (`?status=&tipo=&apenasAtivos=true`) |
| GET | `/restaurantes/{r}/pedidos/:id` | pedido + itens + historico de status |
| POST | `/restaurantes/{r}/pedidos/:id/itens` | adiciona item |
| PATCH | `/restaurantes/{r}/pedidos/:id/itens/:item` | muda quantidade/observacao |
| DELETE | `/restaurantes/{r}/pedidos/:id/itens/:item` | cancela item (com motivo) |
| POST | `/restaurantes/{r}/pedidos/:id/confirmar` | fecha o carrinho e envia a cozinha |
| PATCH | `/restaurantes/{r}/pedidos/:id/status` | transicao validada pela maquina de estados |

### Salao (gerente/garcom)

| Metodo | Rota | Descricao |
|---|---|---|
| GET | `/restaurantes/{r}/mesas` | mapa de mesas com total em aberto |
| POST | `/restaurantes/{r}/mesas` | cadastra mesa (gerente) |
| POST | `/restaurantes/{r}/mesas/:id/sessoes` | abre comanda / ocupa a mesa |
| GET | `/restaurantes/{r}/sessoes/:id` | conta consolidada da mesa |
| PATCH | `/restaurantes/{r}/sessoes/:id/servico` | aceita ou recusa os 10% |
| POST | `/restaurantes/{r}/sessoes/:id/fechar` | encerra a comanda e libera a mesa |

### Cozinha (KDS)

| Metodo | Rota | Descricao |
|---|---|---|
| GET | `/restaurantes/{r}/cozinha/fila` | itens a produzir, com tempo de espera |
| PATCH | `/restaurantes/{r}/cozinha/itens/:id/status` | em_preparo / pronto / entregue |

### Pagamento

| Metodo | Rota | Descricao |
|---|---|---|
| GET | `/restaurantes/{r}/pedidos/:id/pagamentos` | pagamentos do pedido |
| POST | `/restaurantes/{r}/pedidos/:id/pagamentos` | cria cobranca (aceita `valor` para dividir a conta e `idempotencyKey`) |
| POST | `/restaurantes/{r}/pagamentos/:id/confirmar` | aprova (no futuro: webhook do provedor) |
| POST | `/restaurantes/{r}/pagamentos/:id/estornar` | estorno (so gerente, exige motivo) |

### Gestao (gerente)

| Metodo | Rota | Descricao |
|---|---|---|
| POST/PATCH/DELETE | `/restaurantes/{r}/produtos...` | cardapio |
| PATCH | `/restaurantes/{r}/produtos/:id/disponibilidade` | "acabou" (garcom/cozinha tambem) |
| GET/POST | `/restaurantes/{r}/equipe` | lista e cadastra funcionarios |
| DELETE | `/restaurantes/{r}/equipe/:usuarioId` | desliga funcionario |
| GET | `/restaurantes/{r}/relatorios/resumo` | faturamento do periodo (`?de=&ate=`) |
| GET | `/restaurantes/{r}/relatorios/mais-vendidos` | ranking de produtos |
| GET | `/restaurantes/{r}/relatorios/mesas` | ocupacao e tempo medio por mesa |

---

## 4. Formato das respostas

Sucesso: JSON do recurso.
Erro: sempre o mesmo envelope, o que facilita o tratamento no Flutter.

```json
{
  "erro": "O pedido minimo para delivery e de R$ 25.00.",
  "codigo": "PEDIDO_MINIMO",
  "detalhes": [{ "campo": "senha", "mensagem": "A senha deve ter ao menos 8 caracteres." }]
}
```

Codigos usados pelo app para reagir sem depender do texto: `VALIDACAO`,
`NAO_AUTENTICADO`, `PROIBIDO`, `NAO_ENCONTRADO`, `CONFLITO`, `PEDIDO_MINIMO`,
`PEDIDO_VAZIO`, `TRANSICAO_INVALIDA`, `ESTADO_FINAL`, `PAGAMENTO_PENDENTE`,
`CANCELAMENTO_TARDIO`, `VALOR_EXCEDE_TOTAL`, `CONTA_EM_ABERTO`,
`PEDIDO_EM_PRODUCAO`, `INDISPONIVEL`, `RESTAURANTE_FECHADO`.

---

## 5. Decisoes de projeto

- **Sem ORM.** SQL explicito deixa visivel o que vai ao banco - importante em um
  trabalho academico, onde a defesa exige explicar cada consulta.
- **Dinheiro so no banco.** Todo calculo de subtotal, taxa e total acontece na
  funcao `recalcular_pedido()` em `numeric(10,2)`. O JavaScript nunca soma
  dinheiro, o que elimina erro de ponto flutuante.
- **Producao separada de financeiro.** `pedidos.status` cuida do ciclo de
  producao; `pedidos.status_pagamento` do ciclo financeiro. Sao independentes.
- **Perfil fora do token.** O JWT carrega so o id do usuario; o perfil e lido do
  banco a cada requisicao, entao desligar alguem tem efeito imediato.
- **Isolamento por chave composta.** As FKs `(restaurante_id, id)` impedem, no
  proprio banco, que um pedido de um restaurante use produto de outro.
- **Exclusao logica.** Produtos e enderecos sao desativados, nunca apagados, para
  nao destruir o historico de pedidos.

---

## 6. Proximos passos sugeridos

1. Trocar o provedor `mock` de pagamento por Pix/Mercado Pago (webhook + assinatura).
2. WebSocket ou SSE para a fila da cozinha e o status do pedido em tempo real.
3. Grupos de opcionais por produto (borda, ponto da carne, adicionais).
4. Row Level Security no PostgreSQL como segunda barreira de multi-tenancy.
5. Cupons de desconto (a coluna `desconto` ja existe e entra no total).
