# Como rodar o SaborExpress no seu PC

**Resumo:** são duas janelas de terminal abertas ao mesmo tempo — uma para a API, outra para o app.

> ⚠️ **Importante:** hoje o app Flutter **ainda não conversa com a API**. Ele funciona com dados de exemplo escritos no próprio código (`lib/Dados/produtos_mock.dart`), porque o `pubspec.yaml` ainda não tem um cliente HTTP. Então "os dois juntos" hoje significa *os dois rodando lado a lado*, não integrados. Conectar os dois é o próximo passo (fase P1 do roadmap).

---

## Caminho rápido (scripts prontos)

### Janela 1 — API

1. Abra a pasta `backend`.
2. Clique com o botão direito em **`iniciar-api.ps1`** → *Executar com PowerShell*.
3. Ele vai pedir a senha do usuário `postgres` (Enter usa `postgres`).

O script confere o Node, liga o serviço do PostgreSQL se estiver parado, cria o banco, gera o `.env`, instala as dependências, aplica o schema, roda os 29 testes e sobe a API. No final abre o navegador em:

```
http://localhost:3000/api/restaurantes/sabor-express/produtos
```

Se aparecer uma lista de produtos em JSON, **a API está no ar**.

### Janela 2 — App Flutter

1. Copie **`abrir-no-chrome.ps1`** para `app-flutter\tools\`.
2. Clique com o botão direito nele → *Executar com PowerShell*.

Ele acha o Flutter (PATH → puro → SDK ao lado do projeto), roda `flutter pub get` e abre o app em `http://127.0.0.1:8088`.

---

## Caminho manual (se o script falhar)

### API

```powershell
cd <pasta-do-pacote>\backend

# 1. o PostgreSQL está rodando?
Get-Service postgresql*
# se disser Stopped, abra o PowerShell COMO ADMINISTRADOR e:
#   Start-Service postgresql-x64-17

# 2. criar o banco (uma vez só)
$env:PGPASSWORD = 'sua_senha'
& 'C:\Program Files\PostgreSQL\17\bin\psql.exe' -U postgres -h localhost -c "create database sabor_express;"

# 3. configuração
Copy-Item .env.example .env
notepad .env      # ajuste DB_USER, DB_PASSWORD e troque o JWT_SECRET

# 4. dependências e banco
npm install
npm run db:reset

# 5. subir
npm run dev
```

Testar no navegador:

| URL | O que mostra |
|---|---|
| `http://localhost:3000/api/saude` | `{"status":"ok","banco":"ok"}` |
| `http://localhost:3000/api/restaurantes` | os 2 restaurantes de exemplo |
| `http://localhost:3000/api/restaurantes/sabor-express/produtos` | o cardápio |

As demais rotas exigem token — o navegador sozinho não passa. Para testá-las use o **Thunder Client** ou **REST Client** no VS Code, ou o Postman/Insomnia:

```
POST http://localhost:3000/api/auth/login
Content-Type: application/json

{ "email": "gerente@saborexpress.com", "senha": "senha123" }
```

Copie o `token` da resposta e mande nas próximas chamadas no header:

```
Authorization: Bearer SEU_TOKEN_AQUI
```

### App Flutter

```powershell
cd <pasta-do-pacote>\app-flutter

flutter pub get
flutter run -d chrome
```

Se o Flutter não estiver no PATH, use o caminho do puro (que está no seu `android\local.properties`):

```powershell
& "$env:USERPROFILE\.puro\envs\stable\flutter\bin\flutter.bat" run -d chrome
```

Se o Chrome não for detectado:

```powershell
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8088
# depois abra http://127.0.0.1:8088 no navegador
```

Com o app rodando, no terminal: **`r`** recarrega, **`R`** reinicia, **`q`** encerra.

---

## Roteiro para demonstrar (bom para gravar vídeo da defesa)

**No app (dados de exemplo):**
1. Splash → Cadastrar → Login.
2. Cardápio → tocar em um produto → escolher quantidade → adicionar ao carrinho.
3. Carrinho → Sacola → escolher Delivery / Retirada / Mesa → Pix → confirmar → acompanhar status.
4. Menu ☰ → Área do garçom: mesas, abrir pedido, fechar conta.
5. Menu ☰ → Área do gerente: cardápio, pedidos, relatórios.

**Na API (regras de negócio de verdade):**
1. `GET /api/saude` — está no ar.
2. `POST /api/auth/login` como garçom — pega o token.
3. `GET /api/restaurantes/sabor-express/mesas` — mesa 1 livre.
4. `POST .../mesas/{id}/sessoes` — mesa vira **ocupada**.
5. `POST .../pedidos` + `POST .../pedidos/{id}/itens` — veja `subtotal`, `taxa_servico` (10%) e `total` calculados pelo servidor.
6. Tente `PATCH .../pedidos/{id}/status` com `"pronto"` direto — a API recusa com `TRANSICAO_INVALIDA`. **Esse é o momento que impressiona a banca:** a regra existe e é aplicada.
7. `npm test` — os 29 testes passando na frente do avaliador.

---

## Problemas comuns no Windows

| Erro | Causa | Solução |
|---|---|---|
| `execução de scripts foi desabilitada` | política do PowerShell | rode com `powershell -ExecutionPolicy Bypass -File .\iniciar-api.ps1` |
| `ECONNREFUSED 127.0.0.1:5432` | PostgreSQL parado | `Start-Service postgresql*` (como administrador) |
| `password authentication failed` | senha errada no `.env` | ajuste `DB_PASSWORD` |
| `database "sabor_express" does not exist` | banco não criado | rode o passo 2 do caminho manual |
| `EADDRINUSE :3000` | porta ocupada | mude `PORT=3001` no `.env` |
| `Porta 8088 em uso` | app já rodando | feche o terminal antigo ou use `--web-port 8089` |
| `flutter: não é reconhecido` | Flutter fora do PATH | use o caminho do puro mostrado acima |
| Tela branca no navegador | build web incompleto | `flutter clean` e depois `flutter pub get` |

---

## Depois: ligar o app na API

Para "os dois juntos" virar integração de verdade, a ordem é:

1. `flutter pub add http` no projeto Flutter.
2. Criar `lib/servicos/api_cliente.dart` com a URL base `http://localhost:3000/api` e o token guardado.
3. Trocar o login mockado por `POST /auth/login`.
4. Trocar `ProdutoRepository` (que devolve `produtos_mock.dart`) por `GET /restaurantes/{r}/produtos`.
5. Carrinho passa a ser o pedido em `rascunho` no servidor.

Detalhe de CORS: para web, o `.env` da API já libera `http://localhost:8088` e `http://127.0.0.1:8088`. Se rodar o app em outra porta, acrescente em `CORS_ORIGINS`.
