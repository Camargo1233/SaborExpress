# SaborExpress — Sistema de Gestão de Restaurante

Projeto de TCC — **Davi Paulino**
Aplicativo **Flutter** + API **Node.js/Express** + banco **PostgreSQL**

---

## O que é

Sistema de gestão de restaurante que atende três canais de venda dentro de um modelo **multi-restaurante** (vários estabelecimentos na mesma base, com dados isolados entre si):

| Canal | Como funciona |
|---|---|
| **Salão (mesa)** | Garçom abre a comanda, lança as rodadas, fecha a conta. Taxa de serviço de 10% facultativa. |
| **Delivery** | Cliente pede pelo app, com endereço, pedido mínimo e taxa de entrega (grátis acima de um valor). |
| **Retirada** | Cliente pede pelo app e busca no balcão. Sem taxa nenhuma. |

Perfis de acesso: **cliente, garçom, cozinha, entregador e gerente**.

---

## O que tem em cada pasta

```
SaborExpress-TCC/
├── LEIA-ME.md          ← você está aqui
├── backend/            API REST (Node.js + Express + PostgreSQL)
├── app-flutter/        Aplicativo (Flutter)
├── banco/              Scripts SQL + dump pronto para restaurar
└── docs/
    ├── REGRAS_DE_NEGOCIO.md    73 regras numeradas, diagramas de estado, matriz de permissões
    ├── ANALISE_E_MELHORIAS.md  análise técnica com 38 pontos priorizados
    └── COMO_RODAR.md           passo a passo detalhado e solução de problemas
```

---

## Rodar em 5 minutos

### Requisitos

- **Node.js 18+** — https://nodejs.org
- **PostgreSQL 14+** — https://www.postgresql.org/download/
- **Flutter 3.11+** (só se quiser rodar o app) — https://docs.flutter.dev/get-started/install

### 1. Banco de dados

```bash
# criar o banco vazio
psql -U postgres -c "create database sabor_express;"

# restaurar tudo (estrutura + dados de exemplo)
psql -U postgres -d sabor_express -f banco/dump_completo.sql
```

No Windows, se o `psql` não estiver no PATH, use o caminho completo:
`"C:\Program Files\PostgreSQL\17\bin\psql.exe"`

### 2. API

```bash
cd backend
cp .env.example .env      # no Windows: copy .env.example .env
# edite o .env: DB_USER, DB_PASSWORD e troque o JWT_SECRET
npm install
npm run dev
```

A API sobe em **http://localhost:3000/api**.
Teste no navegador: http://localhost:3000/api/saude → deve responder `{"status":"ok","banco":"ok"}`

> **Atalho no Windows:** dentro de `backend/`, clique com o botão direito em `iniciar-api.ps1` → *Executar com PowerShell*. Ele confere o Node, liga o serviço do PostgreSQL, cria o banco, gera o `.env`, instala tudo e sobe a API sozinho.

### 3. App Flutter

```bash
cd app-flutter
flutter pub get
flutter run -d chrome
```

Se o Chrome não for detectado: `flutter run -d web-server --web-port 8088` e abra http://127.0.0.1:8088

---

## Usuários de teste

Senha de todos: **`senha123`**

| E-mail | Perfil |
|---|---|
| `gerente@saborexpress.com` | Gerente do Sabor Express |
| `garcom@saborexpress.com` | Garçom |
| `cozinha@saborexpress.com` | Cozinha |
| `cliente@email.com` | Cliente |
| `gerente@cantinabella.com` | Gerente da Cantina Bella (segundo restaurante, para provar o isolamento) |

---

## Para quem vai **avaliar**

O coração do trabalho está em `docs/REGRAS_DE_NEGOCIO.md`. Os pontos que valem a leitura:

1. **Separação entre produção e financeiro** — `pedidos.status` (rascunho → confirmado → em_preparo → pronto → em_entrega → concluído) e `pedidos.status_pagamento` (não_iniciado → pendente → parcial → pago → estornado) são ciclos independentes. Misturar os dois é o erro mais comum nesse tipo de sistema.

2. **Regras que o banco garante sozinho** — não estão só no código. Exemplos:
   - `total = subtotal − desconto + taxa_entrega + taxa_serviço` é uma *check constraint*: é impossível gravar um total inconsistente.
   - Uma mesa não aceita duas comandas abertas: índice único parcial.
   - Um pedido não usa produto de outro restaurante: chave estrangeira composta `(restaurante_id, produto_id)`.
   - Todo cálculo de dinheiro roda em `numeric(10,2)` dentro da função `recalcular_pedido()` — a aplicação nunca soma valores em ponto flutuante.

3. **Prova de que as regras funcionam** — rode `npm test` dentro de `backend/`. São **29 testes end-to-end** contra um PostgreSQL de verdade, percorrendo os três canais de venda e verificando que operações inválidas são **barradas** (transição de status fora de ordem, cancelamento tardio pelo cliente, pedido abaixo do mínimo, pagamento acima do total, gerente acessando dados de outro restaurante).

Demonstração rápida que mostra a regra em ação: peça para o sistema pular do status `confirmado` direto para `pronto`. A API recusa com `TRANSICAO_INVALIDA` e explica quais transições são possíveis a partir do estado atual.

O roteiro completo de demonstração está em `docs/COMO_RODAR.md`.

---

## Para quem vai **programar**

### Organização da API

Três camadas por módulo, sem ORM (SQL explícito):

```
routes      → HTTP: caminho, permissão, validação do payload (Zod)
service     → regra de negócio. É aqui que as RNs vivem.
repository  → SQL puro. Nenhuma regra.
```

Módulos: `auth`, `usuarios`, `catalogo`, `mesas`, `pedidos`, `pagamentos`, `relatorios`.
O mapa completo de endpoints está em `backend/README.md`.

### Decisões que valem conhecer antes de mexer

- **Perfil não vai no token.** O JWT carrega só o id do usuário; o vínculo com o restaurante é lido do banco a cada requisição, para que desligar um funcionário tenha efeito imediato.
- **Exclusão é lógica.** Produtos e endereços são desativados, nunca apagados — apagar destruiria o histórico de pedidos.
- **Snapshot de preço.** Cada item do pedido guarda uma cópia do nome e do preço do produto. Mudar o cardápio não altera pedidos antigos.
- **Erros padronizados.** Toda resposta de erro tem o formato `{erro, codigo, detalhes}`. O app deve reagir ao `codigo`, nunca ao texto.

### Estado atual do app Flutter — leia antes de começar

O aplicativo **ainda não conversa com a API**. Ele funciona com dados de exemplo escritos no próprio código (`lib/Dados/produtos_mock.dart`), porque o `pubspec.yaml` ainda não tem um cliente HTTP. As telas estão todas prontas e navegáveis; falta a integração.

O caminho para conectar está descrito no fim de `docs/COMO_RODAR.md`, e a lista completa do que precisa mudar no app está em `docs/ANALISE_E_MELHORIAS.md` (seção P1).

### Sobre as pastas de plataforma

Este pacote traz o essencial do app: `lib/`, `assets/`, `web/`, `pubspec.yaml` e `pubspec.lock`. As pastas `android/`, `ios/`, `windows/`, `linux/` e `macos/` **não foram incluídas** porque são geradas automaticamente e pesam bastante. Para recriá-las:

```bash
cd app-flutter
flutter create .
```

Isso não toca em `lib/` nem nos seus assets — só devolve a estrutura das plataformas.

---

## Segurança

Este pacote **não contém** nenhum arquivo `.env`, senha real ou credencial de banco. Você precisa criar o seu `.env` a partir do `.env.example` e gerar o seu próprio `JWT_SECRET`:

```bash
node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"
```

O pagamento está **simulado** (provedor `mock`), mas com a máquina de estados correta — pronta para receber um provedor real (Pix/Mercado Pago) sem reescrever a regra. Nenhum dado de cartão é armazenado em lugar nenhum.
