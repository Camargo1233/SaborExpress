# SaborExpress — Análise Técnica e Roadmap de Melhorias

**Versão:** 1.0 · **Data:** 17/08/2026
**Base analisada:** `SaborExpress` (Flutter, 33 arquivos Dart) e `SaborExpress_backend` (Node/Express, 3 arquivos)

---

## Resumo executivo

O projeto tem um **front-end bem avançado** — 24 telas cobrindo os três perfis (cliente, garçom, gerente), identidade visual consistente e navegação completa. O que existe funciona como *protótipo navegável*.

O problema é que **nada disso está ligado a lugar nenhum**. O `pubspec.yaml` não tem sequer um cliente HTTP (`http` ou `dio`), então o app não consegue conversar com a API nem em teoria. O back-end tem 3 arquivos e uma única rota. O banco tem um schema razoável para um restaurante só, mas sem multi-tenant, sem comanda de mesa e com o status de pedido misturando produção e financeiro.

Encontrei **38 pontos de melhoria**, sendo **7 críticos** — dois deles com risco real de vazamento de credenciais. Este documento lista todos, com arquivo, linha e correção proposta.

| Severidade | Quantidade | Significado |
|---|--:|---|
| 🔴 **P0 — Crítico** | 7 | Segurança ou dado exposto. Corrigir antes de qualquer demonstração pública. |
| 🟠 **P1 — Alto** | 12 | Impede o sistema de funcionar de verdade ou produz resultado errado. |
| 🟡 **P2 — Médio** | 13 | Qualidade, manutenção e experiência do usuário. |
| 🔵 **P3 — Evolução** | 6 | O que fazer depois que o essencial estiver de pé. |

---

## 🔴 P0 — Críticos (segurança)

### P0-1. Autenticação inteira no cliente, com senha no código
`lib/Telas/login_tela.dart:28-50`

```dart
if (email == 'admin@sabor.com' && senha == '123') {
  Navigator.pushReplacementNamed(context, '/adm/home');
}
...
final clienteMockado = email.contains('@') && ...;   // qualquer e-mail entra
```

Qualquer pessoa que digite um e-mail com "@" entra como cliente, e as credenciais de gerente estão escritas no binário do app — recuperáveis com um simples `strings` no APK.

**Correção:** já implementada. `POST /api/auth/login` valida no servidor com bcrypt e devolve um JWT; a tela passa a apenas enviar e-mail/senha e guardar o token.

### P0-2. Credenciais de administrador exibidas na tela de login
`lib/Telas/login_tela.dart:107`

> "Para testar: admin@sabor.com ou garcom@sabor.com com senha 123."

**Correção:** remover o texto. Para a banca do TCC, deixe as credenciais no README, não na interface.

### P0-3. Senha do usuário salva em texto puro no dispositivo
`lib/Telas/cadastro_tela.dart:51-53`

```dart
await prefs.setString('senha', senha);
```

`SharedPreferences` não é criptografado. Em um aparelho com root, a senha sai limpa.

**Correção:** nunca armazenar senha. Guardar apenas o token JWT, e de preferência em `flutter_secure_storage`.

### P0-4. Endpoint que devolve o hash de senha de todos os usuários
`SaborExpress_backend/routes.js`

```js
const { rows } = await db.query("SELECT * FROM usuarios");
res.json(rows);
```

Sem autenticação e com `SELECT *`, essa rota entrega `senha_hash` de todo mundo para quem chamar `GET /usuarios`.

**Correção:** já implementada. A API nova nunca seleciona `senha_hash` em resposta, e `/equipe` exige perfil de gerente.

### P0-5. Arquivo `.env` sem `.gitignore` no back-end
`SaborExpress_backend/` — existe `.env` com a senha do banco e **não existe** `.gitignore`.

**Correção:** `.gitignore` já criado no back-end novo. Se o `.env` já tiver ido para o Git alguma vez, **troque a senha do banco** — remover o arquivo não apaga o histórico.

### P0-6. Senhas de produção documentadas em texto no repositório
`database/README.md` traz a senha do usuário `sabor_app` **e** a senha do superusuário `postgres`.

**Correção:** substituir por `.env.example` com valores de exemplo, e documentar apenas o *nome* das variáveis.

### P0-7. Coleta de dados de cartão dentro do app
`lib/Telas/cadastro_cartao_tela.dart` captura número, validade e CVV em campos comuns e navega direto para a tela de sucesso.

Guardar ou trafegar PAN/CVV pelo seu próprio servidor coloca o projeto dentro do escopo PCI-DSS — algo que nenhum TCC quer carregar.

**Correção:** o app nunca deve ver o número do cartão. Ou se usa o SDK/checkout do provedor (que devolve um token), ou se restringe a Pix e pagamento presencial. O schema novo já guarda apenas método, valor, status, provedor e id da transação (RN-PAG-008).

---

## 🟠 P1 — Alto (o sistema não funciona de verdade)

### P1-1. O app não tem cliente HTTP
`pubspec.yaml` — dependências: `shared_preferences`, `image_picker`, `cupertino_icons`. Não há `http` nem `dio`.

**Correção:** adicionar `http` (ou `dio`), criar `lib/servicos/api_cliente.dart` com base URL, injeção do token e tratamento do envelope de erro (`{erro, codigo, detalhes}`).

### P1-2. O carrinho sempre nasce com dois produtos fixos
`lib/Telas/carrinho_tela.dart:20-28`

```dart
void didChangeDependencies() {
  itens = [
    _CarrinhoItem(produto: produtosMock[0], quantidade: 1),
    _CarrinhoItem(produto: produtosMock[2], quantidade: 1),
  ];
  ...
}
```

Além de sempre começar com pizza + refrigerante, `didChangeDependencies` **roda de novo** em várias situações (mudança de tema, teclado, rotação), o que reseta o carrinho e descarta o que o usuário adicionou.

**Correção:** carrinho fora da tela — um `CarrinhoStore` (Provider/Riverpod) ou o próprio pedido em rascunho na API. Com a API nova, o carrinho *é* o pedido em `rascunho`: o servidor vira a fonte da verdade.

### P1-3. Valores viajam por `arguments` e cada tela recalcula do seu jeito
`lib/Telas/sacola_tela.dart:17-20` começa com `subtotal = 51; entrega = 10; total = 61; quantidade = 2` como *fallback*. Se os argumentos não chegarem, a tela mostra números inventados.

**Correção:** buscar o pedido pelo id (`GET /pedidos/:id`) e exibir `subtotal`, `taxa_entrega`, `taxa_servico` e `total` vindos do servidor. Nenhuma soma de dinheiro no app.

### P1-4. Taxa de entrega fixa em R$ 10,00 no código
`lib/Telas/carrinho_tela.dart:16`

**Correção:** a taxa é parâmetro do restaurante (`taxa_entrega_padrao`, `frete_gratis_acima_de`, `pedido_minimo_delivery`) e é calculada na confirmação (RN-CAL-002/003).

### P1-5. Três cardápios diferentes convivendo no mesmo app
- `lib/Dados/produtos_mock.dart` — 6 produtos (cliente e garçom)
- `lib/TelasAdm/cardapio_gerente_tela.dart:339` — outra lista, com produtos que não existem na primeira ("Marguerita", "Bacon com Milho")
- `lib/TelasGarcom/pedido_mesa_garcom_tela.dart` e `Finalizacao_garcom_tela.dart` — mais duas listas fixas

O gerente cadastra um produto e ele não aparece para o garçom nem para o cliente.

**Correção:** fonte única — `GET /restaurantes/{r}/produtos`. O `ProdutoRepository` passa a chamar a API; os mocks viram *fallback* de desenvolvimento apenas.

### P1-6. Modelo `Produto` incompatível com o banco
`lib/models/produto.dart:2,26`

```dart
final int id;             // o banco usa uuid
imagem: json['imagem'],   // a API devolve imagem_url
preco: json['preco'].toDouble(),
```

Três incompatibilidades: `int` × `uuid`, `imagem` × `imagem_url`, e o driver do PostgreSQL entrega `numeric` como **string** — `"45.00".toDouble()` estoura em tempo de execução.

**Correção:** `String id`, `imagemUrl`, e parse defensivo (`double.tryParse(json['preco'].toString()) ?? 0`). Do lado do servidor eu já configurei o `pg` para devolver `numeric` como número, então o JSON chega como `45.9`.

### P1-7. Qualquer cliente entra no painel do gerente
`lib/Telas/home_tela.dart:244` — o menu "Atalhos de teste" leva direto a `/garcom/mesa` e `/adm/home`, sem verificação nenhuma.

**Correção:** remover o atalho e definir a rota inicial pelo perfil retornado no login (`vinculos[]` da resposta de `/auth/login`). O servidor já barra as operações por perfil, mas a interface não deve nem oferecer o caminho.

### P1-8. Status da mesa é só uma cor na memória da tela
`lib/TelasGarcom/mesas_garcom_tela.dart:13-70` guarda `{"numero": "Mesa 01", "status": "...", "cor": Colors.red}`. Fechar o app perde tudo, e dois garçons veem estados diferentes.

**Correção:** `GET /restaurantes/{r}/mesas` devolve status real, total em aberto e quem abriu a comanda. A cor é decisão de UI, calculada a partir do status — não deve morar no modelo de dados.

### P1-9. "Fechar Conta" não fecha nada
`lib/TelasGarcom/pedido_mesa_garcom_tela.dart:210` chama `pushNamed('/garcom/finalizacao')` **sem argumentos** e sem aguardar retorno. A tela de finalização faz `Navigator.pop(context, true)` esperando que alguém use esse retorno para liberar a mesa — mas nesse caminho ninguém usa. Resultado: a mesa nunca é liberada.

**Correção:** `POST /sessoes/:id/fechar` no servidor, com as validações da RN-MESA-004, e a tela apenas reage à resposta.

### P1-10. Divergência de configuração entre os dois repositórios
O `.env.example` do Flutter usa `DATABASE_URL` e `POSTGRES_*`; o `db.js` do back-end lê `DB_HOST`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`, `DB_PORT`. Quem seguir o exemplo não conecta.

**Correção:** um único `.env.example`, no back-end (já entregue). O app Flutter não precisa de credenciais de banco — ele fala com a API, não com o PostgreSQL.

### P1-11. O app se conectaria direto ao banco? Não deve.
O `.env.example` na raiz do projeto Flutter sugere que o aplicativo teria a string de conexão do PostgreSQL. Um app distribuído com credenciais de banco é comprometimento garantido.

**Correção:** manter a regra atual do projeto — Flutter fala **só** com a API; só a API fala com o banco.

### P1-12. Nenhum teste automatizado
Não existe pasta `test/` no projeto Flutter, nem testes no back-end.

**Correção:** o back-end novo já vem com 29 testes end-to-end (`npm test`) cobrindo os três canais e as regras que precisam barrar operações inválidas. No Flutter, comece por *widget tests* das telas de carrinho e login, e por testes de unidade dos formatadores.

---

## 🟡 P2 — Médio (qualidade e manutenção)

### P2-1. Arquivo com nome em caixa diferente do import
`lib/TelasGarcom/Finalizacao_garcom_tela.dart` (com `F` maiúsculo) é importado como `finalizacao_garcom_tela.dart` em `main.dart:24` e em `mesas_garcom_tela.dart:3`.

Funciona no Windows (sistema de arquivos insensível a caixa) e **quebra no Linux e no macOS** — inclusive em qualquer CI. Renomeie o arquivo para minúsculo.

### P2-2. Lint de segurança desligado em vez de corrigido
`analysis_options.yaml`

```yaml
analyzer:
  errors:
    use_build_context_synchronously: ignore
```

Essa é justamente a regra que pega uso de `context` depois de um `await` — a causa clássica de crash quando a tela é fechada durante uma chamada assíncrona.

**Correção:** remover o `ignore`, adicionar `flutter_lints` em `dev_dependencies` e corrigir os pontos apontados com `if (!mounted) return;`.

### P2-3. Convenção de nomes inconsistente
`lib/Telas`, `lib/TelasAdm`, `lib/TelasGarcom`, `lib/Dados`, `lib/Repositories` em PascalCase; `lib/models`, `lib/utils`, `lib/widgets` em minúsculo.

**Correção:** o padrão Dart é tudo minúsculo com `_`. Sugestão de estrutura por funcionalidade:

```
lib/
  nucleo/        (tema, cores, formatadores, cliente HTTP)
  modelos/
  servicos/      (api_cliente, auth_servico, pedido_servico)
  estado/        (stores/providers)
  telas/
    cliente/  garcom/  gerente/
  widgets/
```

### P2-4. Formatação monetária manual
`lib/utils/formatters.dart` troca `.` por `,` na mão — sem separador de milhar. `R$ 1234,50` em vez de `R$ 1.234,50`.

**Correção:** `intl` com `NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$')`.

### P2-5. Dados de relatório escritos no código
`lib/TelasAdm/relatorio_gerente_tela.dart:17` — `faturamento = 1250.00`, com o comentário "Futuramente esses dados virão do banco/API".

**Correção:** `GET /relatorios/resumo` e `/relatorios/mais-vendidos` já entregam esses números, com filtro de período.

### P2-6. Sem tratamento de erro padronizado
As telas mostram `SnackBar` com textos soltos; não há distinção entre "sem internet", "sessão expirada" e "regra de negócio".

**Correção:** a API responde sempre `{erro, codigo, detalhes}`. Crie um `TratadorDeErro` que mapeie `codigo` para mensagem amigável e ação (ex.: `NAO_AUTENTICADO` → voltar para o login).

### P2-7. Imagens de rede sem cache
`Image.network` em listas recarrega a cada scroll.

**Correção:** `cached_network_image`, com placeholder e *fallback* (o `errorBuilder` atual já é um bom começo).

### P2-8. Sem indicador de carregamento nas ações
Botões de pagar/confirmar não bloqueiam durante a chamada — com API real, o usuário toca duas vezes e cria dois pedidos.

**Correção:** estado `carregando` no botão + a chave de idempotência que a API já aceita no pagamento (RN-PAG-006).

### P2-9. Tela de mesa do cliente não faz nada
`lib/Telas/mesa_tela.dart` — lista fixa `[1, 2, 6, 8, 9]`, mostra "Mesa reservada!" e volta, sem persistir.

**Correção:** ou implementar reserva de verdade (o enum `reservada` já existe no banco), ou remover a tela do fluxo do cliente para não prometer o que não entrega.

### P2-10. Observação do produto se perde
`lib/Telas/produto_tela.dart` envia `observacao` por argumento, mas o carrinho **sobrescreve** a observação quando o mesmo produto já existe na lista.

**Correção:** cada linha do pedido tem sua própria observação — a API já modela assim (`pedido_itens.observacao`). Dois pedidos do mesmo produto com observações diferentes devem ser duas linhas.

### P2-11. Sem tema escuro nem acessibilidade
`lib/utils/app_theme.dart` define apenas `AppTheme.light`.

**Correção:** adicionar `darkTheme` e `themeMode: ThemeMode.system`. Conferir contraste (o texto branco sobre amarelo da splash provavelmente reprova em WCAG AA).

### P2-12. Textos fixos em português no código
Nenhum suporte a internacionalização.

**Correção:** para um TCC é aceitável; se quiser pontos extras, `flutter_localizations` + `intl` com um `.arb`.

### P2-13. `README.md` ainda é o template do Flutter
"A new Flutter project."

**Correção:** README com o problema resolvido, arquitetura, como rodar, credenciais de teste e prints. É o primeiro arquivo que a banca abre.

---

## 🔵 P3 — Evolução (depois do essencial)

1. **Tempo real** — a fila da cozinha e o status do pedido pedem WebSocket ou SSE em vez do usuário puxar para atualizar.
2. **Pagamento de verdade** — trocar o provedor `mock` por Pix/Mercado Pago: webhook, validação de assinatura, reconciliação, tratamento de duplicidade.
3. **Opcionais por produto** — borda recheada, ponto da carne, adicionais. Exige `grupos_opcoes` e `opcoes` com regra de mínimo/máximo, e afeta o cálculo do item.
4. **Row Level Security** — segunda barreira de isolamento entre restaurantes, direto no PostgreSQL, além das chaves compostas.
5. **Cupons e promoções** — a coluna `desconto` já existe e entra no total; falta a tabela de cupons e as regras de validade/acúmulo.
6. **Impressão e fiscal** — impressora térmica na cozinha e, se o projeto for para produção, NFC-e.

---

## O que já está entregue neste pacote

| Entrega | Onde | Status |
|---|---|---|
| Schema v2 multi-restaurante com constraints, triggers e função de recálculo | `backend/database/migrations/001_schema.sql` | ✅ aplicado e testado |
| Dados de demonstração com 2 restaurantes | `backend/database/migrations/002_seed.sql` | ✅ |
| API REST completa em camadas (auth, catálogo, mesas, pedidos, pagamentos, relatórios) | `backend/src/` | ✅ 100% dos testes passando |
| Máquina de estados do pedido isolada e documentada | `backend/src/modules/pedidos/pedidos.maquinaDeEstados.js` | ✅ |
| 29 testes end-to-end contra PostgreSQL real | `backend/tests/e2e.test.js` | ✅ `npm test` |
| Documento de regras de negócio (73 RNs numeradas) | `docs/REGRAS_DE_NEGOCIO.md` | ✅ |
| Esta análise | `docs/ANALISE_E_MELHORIAS.md` | ✅ |

---

## Roadmap sugerido

**Semana 1 — parar o sangramento (P0)**
Remover credenciais do app, apagar a senha do `SharedPreferences`, adicionar `.gitignore` e trocar a senha do banco, tirar a coleta de cartão.

**Semanas 2–3 — ligar o app na API (P1)**
Adicionar `http`, criar a camada de serviços, migrar login/cadastro, cardápio e carrinho para a API. Ao final desta etapa o app deixa de ser protótipo.

**Semana 4 — fluxos de mesa e pagamento (P1)**
Migrar as telas do garçom para comanda real e o pagamento para o ciclo de estados da API.

**Semana 5 — gerente e relatórios (P1/P2)**
CRUD de cardápio na API e relatórios com dados reais.

**Semana 6 — polimento (P2)**
Renomear arquivos e pastas, reativar os lints, tratamento de erro padronizado, `intl`, cache de imagem, README e prints para a defesa.
