# Banco de dados — SaborExpress

PostgreSQL 14 ou superior. Usa a extensão `pgcrypto` (já vem com o PostgreSQL padrão).

## Arquivos

| Arquivo | Para que serve |
|---|---|
| `dump_completo.sql` | Estrutura **e** dados de exemplo. É o caminho mais rápido: um comando e o banco está pronto. |
| `001_schema.sql` | Só a estrutura: tipos, tabelas, índices, constraints, funções e triggers. |
| `002_seed.sql` | Só os dados de demonstração (2 restaurantes, 5 usuários, cardápio, mesas). |

## Opção A — restaurar o dump (mais rápido)

```bash
psql -U postgres -c "create database sabor_express;"
psql -U postgres -d sabor_express -f dump_completo.sql
```

Windows, com o `psql` fora do PATH:

```powershell
$env:PGPASSWORD = 'sua_senha'
& "C:\Program Files\PostgreSQL\17\bin\psql.exe" -U postgres -c "create database sabor_express;"
& "C:\Program Files\PostgreSQL\17\bin\psql.exe" -U postgres -d sabor_express -f dump_completo.sql
```

## Opção B — aplicar os scripts na ordem

```bash
psql -U postgres -c "create database sabor_express;"
psql -U postgres -d sabor_express -f 001_schema.sql
psql -U postgres -d sabor_express -f 002_seed.sql
```

## Opção C — pelo Node (recomendado para quem vai desenvolver)

De dentro de `backend/`, com o `.env` configurado:

```bash
npm run db:migrate    # aplica o que ainda não foi aplicado
npm run db:reset      # apaga tudo e recria do zero
```

O controle de quais scripts já rodaram fica na tabela `_migracoes`.

---

## Conferindo se deu certo

```sql
select nome, slug from restaurantes;
-- Sabor Express | sabor-express
-- Cantina Bella | cantina-bella

select count(*) from produtos;   -- 9
select count(*) from mesas;      -- 13
```

Senha de todos os usuários de exemplo: **`senha123`** (guardada como hash bcrypt, nunca em texto).

---

## Modelo de dados em uma olhada

```
restaurantes ──┬── restaurante_membros ── usuarios ── enderecos
               ├── categorias ── produtos
               ├── mesas ── sessoes_mesa (comanda)
               └── pedidos ──┬── pedido_itens
                             ├── pagamentos
                             └── pedido_status_historico
```

**Pontos da modelagem que valem atenção:**

- `restaurante_id` está em toda entidade operacional. As chaves estrangeiras compostas `(restaurante_id, id)` impedem, no próprio banco, que um pedido de um restaurante use produto de outro.
- `sessoes_mesa` é a comanda: uma mesa ocupada pode acumular vários pedidos (as rodadas). Um índice único parcial garante no máximo **uma** comanda aberta por mesa.
- `pedido_itens` guarda `produto_nome` e `preco_unitario` copiados no momento do pedido. Renomear ou mudar o preço de um produto não altera o histórico.
- `pedidos` tem **dois** status independentes: `status` (produção) e `status_pagamento` (financeiro).
- A função `recalcular_pedido(uuid)` é a única fonte de verdade dos valores. Toda alteração de item a chama dentro da mesma transação.
- Triggers cuidam sozinhos de: `atualizado_em`, histórico de mudança de status, sincronização do status da mesa com a comanda e numeração diária do pedido (`20260817-0001`).
