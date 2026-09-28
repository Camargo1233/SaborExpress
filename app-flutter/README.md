# SaborExpress — Aplicativo Flutter

App do sistema de gestão de restaurante. Cobre os três perfis de uso em 24 telas:
**cliente** (cardápio, carrinho, sacola, pagamento, acompanhamento), **garçom** (mesas, comanda, fechamento) e **gerente** (cardápio, pedidos, relatórios).

---

## Rodar

```bash
flutter pub get
flutter run -d chrome
```

Se o Chrome não for detectado pelo Flutter:

```bash
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8088
# depois abra http://127.0.0.1:8088
```

No Windows há um atalho pronto: `tools/abrir-no-chrome.ps1` (botão direito → *Executar com PowerShell*). Ele procura o Flutter no PATH, no puro e num SDK ao lado do projeto.

Com o app rodando, no terminal: **`r`** recarrega, **`R`** reinicia, **`q`** encerra.

---

## As pastas de plataforma não vieram no pacote

`android/`, `ios/`, `windows/`, `linux/` e `macos/` são geradas automaticamente pelo Flutter e pesam bastante, então ficaram de fora. Para recriá-las:

```bash
flutter create .
```

O comando não toca em `lib/` nem em `assets/` — só devolve a estrutura das plataformas.

---

## Organização atual

```
lib/
├── main.dart              rotas nomeadas de todas as telas
├── Dados/                 produtos de exemplo (mock)
├── Repositories/          acesso a dados (hoje devolve o mock)
├── models/                Produto
├── Telas/                 fluxo do cliente
├── TelasGarcom/           fluxo do salão
├── TelasAdm/              painel do gerente
├── utils/                 cores, tema, formatadores
└── widgets/               botão, campo de texto, cabeçalho
```

---

## Estado da integração com a API

⚠️ **O app ainda não conversa com a API.** Ele lê os produtos de `lib/Dados/produtos_mock.dart`, e o `pubspec.yaml` ainda não tem cliente HTTP. As telas estão prontas e navegáveis; o que falta é a camada de rede.

A API que este app vai consumir está na pasta `backend/` deste mesmo pacote, com todos os endpoints documentados em `backend/README.md`.

### Caminho para conectar

1. `flutter pub add http`
2. Criar `lib/servicos/api_cliente.dart` com a URL base (`http://localhost:3000/api`), o token guardado e o tratamento do envelope de erro `{erro, codigo, detalhes}`.
3. Trocar o login local por `POST /auth/login` — a resposta traz `token` e `vinculos` (onde a pessoa trabalha e com qual perfil), o que define a tela inicial.
4. Trocar `ProdutoRepository` por `GET /restaurantes/{r}/produtos`.
5. O carrinho passa a ser o pedido em `rascunho` no servidor: `POST /pedidos` e `POST /pedidos/{id}/itens`. Assim os totais, a taxa de entrega e a taxa de serviço vêm calculados pela API, e o app só exibe.

**Atenção ao modelo `Produto`:** hoje ele usa `int id`, mas a API devolve `uuid` (String), e o campo da imagem chama-se `imagem_url`, não `imagem`. São os três ajustes necessários no `fromJson`.

**CORS:** ao rodar no navegador, a origem do app precisa estar em `CORS_ORIGINS` no `.env` da API. As portas `8088` já vêm liberadas.

---

## Pontos conhecidos que precisam de correção

Estão detalhados em `docs/ANALISE_E_MELHORIAS.md`, mas os três mais urgentes:

1. `lib/Telas/login_tela.dart` — a autenticação acontece dentro do app, com credenciais escritas no código. Precisa ir para a API.
2. `lib/Telas/cadastro_tela.dart` — a senha é gravada em texto puro no `SharedPreferences`. Deve guardar apenas o token.
3. `lib/Telas/carrinho_tela.dart` — o carrinho é recriado com dois produtos fixos a cada `didChangeDependencies`, o que apaga o que o usuário adicionou quando o teclado abre ou o tema muda.

Vale também renomear `lib/TelasGarcom/Finalizacao_garcom_tela.dart` para minúsculo: o arquivo é importado como `finalizacao_garcom_tela.dart` e isso quebra o build em Linux e macOS.
