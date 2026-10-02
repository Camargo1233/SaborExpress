\-- =====================================================================

\-- SaborExpress - Schema v2 (multi-restaurante)

\-- PostgreSQL 14+

\-- Executar:  psql -U \<user> -d sabor_express -f 001_schema.sql

\-- =====================================================================

\-- Convencoes adotadas:

\--   \* Toda entidade operacional pertence a um restaurante (restaurante_id).

\--   \* Dinheiro sempre em numeric(10,2). Nunca float/double.

\--   \* Nomes de tabelas no plural, colunas em snake_case, sem acentos.

\--   \* Timestamps sempre timestamptz (guardam o fuso).

\--   \* Chaves estrangeiras compostas (restaurante_id, id) impedem que um

\--     recurso de um restaurante seja usado em outro (isolamento de tenant).

\-- =====================================================================



create extension if not exists pgcrypto;



\-- ---------------------------------------------------------------------

\-- 1. Tipos enumerados

\-- ---------------------------------------------------------------------

do $$

begin

  if not exists (select 1 from pg_type where typname = 'perfil_acesso') then

    create type perfil_acesso as enum ('gerente', 'garcom', 'cozinha', 'entregador');

  end if;



  if not exists (select 1 from pg_type where typname = 'mesa_status') then

    create type mesa_status as enum ('livre', 'ocupada', 'reservada', 'interditada');

  end if;



  if not exists (select 1 from pg_type where typname = 'sessao_status') then

    create type sessao_status as enum ('aberta', 'fechada', 'cancelada');

  end if;



  if not exists (select 1 from pg_type where typname = 'pedido_tipo') then

    create type pedido_tipo as enum ('mesa', 'delivery', 'retirada');

  end if;



  if not exists (select 1 from pg_type where typname = 'pedido_canal') then

    create type pedido_canal as enum ('app_cliente', 'garcom', 'balcao');

  end if;



  -- Ciclo de PRODUCAO do pedido (nao se mistura com o financeiro).

  if not exists (select 1 from pg_type where typname = 'pedido_status') then

    create type pedido_status as enum (

      'rascunho',

      'confirmado',

      'em_preparo',

      'pronto',

      'em_entrega',

      'concluido',

      'cancelado'

    );

  end if;



  -- Ciclo FINANCEIRO do pedido (independente da producao).

  if not exists (select 1 from pg_type where typname = 'pedido_pagamento_status') then

    create type pedido_pagamento_status as enum (

      'nao_iniciado',

      'pendente',

      'parcial',

      'pago',

      'estornado'

    );

  end if;



  if not exists (select 1 from pg_type where typname = 'item_status') then

    create type item_status as enum (

      'pendente',

      'enviado_cozinha',

      'em_preparo',

      'pronto',

      'entregue',

      'cancelado'

    );

  end if;



  if not exists (select 1 from pg_type where typname = 'pagamento_metodo') then

    create type pagamento_metodo as enum (

      'pix',

      'cartao_credito',

      'cartao_debito',

      'dinheiro',

      'vale_refeicao',

      'na_entrega',

      'no_local'

    );

  end if;



  if not exists (select 1 from pg_type where typname = 'pagamento_status') then

    create type pagamento_status as enum (

      'pendente',

      'aprovado',

      'recusado',

      'cancelado',

      'estornado'

    );

  end if;

end

$$;



\-- ---------------------------------------------------------------------

\-- 2. Funcao utilitaria: manter atualizado_em

\-- ---------------------------------------------------------------------

create or replace function set_atualizado_em()

returns trigger

language plpgsql

as $$

begin

  new\.atualizado_em = now();

  return new;

end;

$$;



\-- ---------------------------------------------------------------------

\-- 3. Restaurantes (tenant)

\-- ---------------------------------------------------------------------

create table if not exists restaurantes (

  id                      uuid primary key default gen_random_uuid(),

  nome                    varchar(120) not null,

  slug                    varchar(80)  not null unique,

  cnpj                    varchar(18),

  telefone                varchar(30),

  -- Parametros comerciais (RN-CAL-\*)

  taxa_servico_percentual numeric(5,2) not null default 10.00

                          check (taxa_servico_percentual >= 0 and taxa_servico_percentual <= 100),

  taxa_entrega_padrao     numeric(10,2) not null default 0 check (taxa_entrega_padrao >= 0),

  pedido_minimo_delivery  numeric(10,2) not null default 0 check (pedido_minimo_delivery >= 0),

  frete_gratis_acima_de   numeric(10,2) check (frete_gratis_acima_de >= 0),

  raio_entrega_km         numeric(6,2) check (raio_entrega_km > 0),

  aceita_delivery         boolean not null default true,

  aceita_retirada         boolean not null default true,

  aceita_mesa             boolean not null default true,

  aberto                  boolean not null default true,

  ativo                   boolean not null default true,

  criado_em               timestamptz not null default now(),

  atualizado_em           timestamptz not null default now()

);



drop trigger if exists trg_restaurantes_atualizado_em on restaurantes;

create trigger trg_restaurantes_atualizado_em

  before update on restaurantes

  for each row execute function set_atualizado_em();



\-- ---------------------------------------------------------------------

\-- 4. Usuarios (globais na plataforma) e vinculo com restaurantes

\-- ---------------------------------------------------------------------

create table if not exists usuarios (

  id             uuid primary key default gen_random_uuid(),

  nome           varchar(120) not null,

  email          varchar(160) not null,

  telefone       varchar(30),

  senha_hash     text not null,

  ativo          boolean not null default true,

  ultimo_login_em timestamptz,

  criado_em      timestamptz not null default now(),

  atualizado_em  timestamptz not null default now()

);



\-- E-mail unico ignorando maiusculas/minusculas (RN-USR-002)

create unique index if not exists uq_usuarios_email_lower on usuarios (lower(email));



drop trigger if exists trg_usuarios_atualizado_em on usuarios;

create trigger trg_usuarios_atualizado_em

  before update on usuarios

  for each row execute function set_atualizado_em();



\-- Um usuario pode ser funcionario de mais de um restaurante, com um

\-- perfil por restaurante. Cliente NAO tem linha aqui (RN-USR-003).

create table if not exists restaurante_membros (

  id             uuid primary key default gen_random_uuid(),

  restaurante_id uuid not null references restaurantes(id) on delete cascade,

  usuario_id     uuid not null references usuarios(id) on delete cascade,

  perfil         perfil_acesso not null,

  ativo          boolean not null default true,

  criado_em      timestamptz not null default now(),

  constraint uq_membro_por_restaurante unique (restaurante_id, usuario_id)

);



create index if not exists idx_membros_usuario on restaurante_membros(usuario_id);



\-- ---------------------------------------------------------------------

\-- 5. Enderecos do cliente

\-- ---------------------------------------------------------------------

create table if not exists enderecos (

  id           uuid primary key default gen_random_uuid(),

  usuario_id   uuid not null references usuarios(id) on delete cascade,

  apelido      varchar(80) not null default 'Principal',

  cep          varchar(9)  not null,

  logradouro   varchar(160) not null,

  numero       varchar(20) not null,

  complemento  varchar(120),

  bairro       varchar(100) not null,

  cidade       varchar(100) not null,

  estado       char(2) not null,

  referencia   varchar(160),

  latitude     numeric(10,7),

  longitude    numeric(10,7),

  principal    boolean not null default false,

  ativo        boolean not null default true,

  criado_em    timestamptz not null default now()

);



create index if not exists idx_enderecos_usuario on enderecos(usuario_id);

\-- No maximo um endereco principal por usuario (RN-USR-005)

create unique index if not exists uq_endereco_principal

  on enderecos(usuario_id) where principal and ativo;



\-- ---------------------------------------------------------------------

\-- 6. Catalogo

\-- ---------------------------------------------------------------------

create table if not exists categorias (

  id             uuid not null default gen_random_uuid(),

  restaurante_id uuid not null references restaurantes(id) on delete cascade,

  nome           varchar(80) not null,

  descricao      text,

  ordem          int not null default 0,

  ativo          boolean not null default true,

  criado_em      timestamptz not null default now(),

  atualizado_em  timestamptz not null default now(),

  primary key (id),

  constraint uq_categoria_nome_por_restaurante unique (restaurante_id, nome),

  -- permite FK composta a partir de produtos

  constraint uq_categoria_tenant unique (restaurante_id, id)

);



drop trigger if exists trg_categorias_atualizado_em on categorias;

create trigger trg_categorias_atualizado_em

  before update on categorias

  for each row execute function set_atualizado_em();



create table if not exists produtos (

  id             uuid not null default gen_random_uuid(),

  restaurante_id uuid not null references restaurantes(id) on delete cascade,

  categoria_id   uuid,

  nome           varchar(120) not null,

  descricao      text,

  preco          numeric(10,2) not null check (preco >= 0),

  imagem_url     text,

  tempo_preparo_min int check (tempo_preparo_min >= 0),

  destaque       boolean not null default false,

  disponivel     boolean not null default true,   -- acabou no estoque hoje

  ativo          boolean not null default true,   -- exclusao logica (RN-CAT-004)

  criado_em      timestamptz not null default now(),

  atualizado_em  timestamptz not null default now(),

  primary key (id),

  constraint uq_produto_tenant unique (restaurante_id, id),

  constraint uq_produto_nome_por_restaurante unique (restaurante_id, nome),

  -- garante que a categoria pertence ao MESMO restaurante do produto

  constraint fk_produto_categoria

    foreign key (restaurante_id, categoria_id)

    references categorias(restaurante_id, id) on delete set null

);



drop trigger if exists trg_produtos_atualizado_em on produtos;

create trigger trg_produtos_atualizado_em

  before update on produtos

  for each row execute function set_atualizado_em();



create index if not exists idx_produtos_restaurante on produtos(restaurante_id);

create index if not exists idx_produtos_categoria on produtos(categoria_id);

create index if not exists idx_produtos_cardapio

  on produtos(restaurante_id, ativo, disponivel);



\-- ---------------------------------------------------------------------

\-- 7. Mesas e sessoes (comandas)

\-- ---------------------------------------------------------------------

create table if not exists mesas (

  id             uuid not null default gen_random_uuid(),

  restaurante_id uuid not null references restaurantes(id) on delete cascade,

  numero         int not null check (numero > 0),

  apelido        varchar(40),

  capacidade     int not null default 4 check (capacidade > 0),

  status         mesa_status not null default 'livre',

  ativo          boolean not null default true,

  criado_em      timestamptz not null default now(),

  atualizado_em  timestamptz not null default now(),

  primary key (id),

  constraint uq_mesa_numero_por_restaurante unique (restaurante_id, numero),

  constraint uq_mesa_tenant unique (restaurante_id, id)

);



drop trigger if exists trg_mesas_atualizado_em on mesas;

create trigger trg_mesas_atualizado_em

  before update on mesas

  for each row execute function set_atualizado_em();



\-- Sessao = periodo em que a mesa esta ocupada por um grupo de clientes.

\-- E a "comanda": pode ter varios pedidos (rodadas) ate o fechamento.

create table if not exists sessoes_mesa (

  id             uuid not null default gen_random_uuid(),

  restaurante_id uuid not null references restaurantes(id) on delete cascade,

  mesa_id        uuid not null,

  aberta_por     uuid references usuarios(id),

  fechada_por    uuid references usuarios(id),

  status         sessao_status not null default 'aberta',

  qtd_pessoas    int not null default 1 check (qtd_pessoas > 0),

  servico_aceito boolean not null default true,  -- gorjeta e facultativa (RN-CAL-005)

  aberta_em      timestamptz not null default now(),

  fechada_em     timestamptz,

  observacao     text,

  primary key (id),

  constraint uq_sessao_tenant unique (restaurante_id, id),

  constraint fk_sessao_mesa

    foreign key (restaurante_id, mesa_id)

    references mesas(restaurante_id, id) on delete cascade,

  constraint chk_sessao_fechamento check (

    (status = 'aberta' and fechada_em is null)

    or (status <> 'aberta' and fechada_em is not null)

  )

);



\-- RN-MESA-002: no maximo UMA sessao aberta por mesa.

create unique index if not exists uq_sessao_aberta_por_mesa

  on sessoes_mesa(mesa_id) where status = 'aberta';



create index if not exists idx_sessoes_restaurante on sessoes_mesa(restaurante_id, status);



\-- Mantem mesas.status sincronizado com a sessao (fonte da verdade = sessao).

create or replace function sincronizar_status_mesa()

returns trigger

language plpgsql

as $$

begin

  if new\.status = 'aberta' then

    update mesas set status = 'ocupada' where id = new\.mesa_id;

  else

    update mesas set status = 'livre'

     where id = new\.mesa_id

       and not exists (

         select 1 from sessoes_mesa s

          where s.mesa_id = new\.mesa_id and s.status = 'aberta' and s.id <> new\.id

       );

  end if;

  return new;

end;

$$;



drop trigger if exists trg_sessao_sincroniza_mesa on sessoes_mesa;

create trigger trg_sessao_sincroniza_mesa

  after insert or update of status on sessoes_mesa

  for each row execute function sincronizar_status_mesa();



\-- ---------------------------------------------------------------------

\-- 8. Pedidos

\-- ---------------------------------------------------------------------

create table if not exists pedidos (

  id              uuid not null default gen_random_uuid(),

  restaurante_id  uuid not null references restaurantes(id) on delete cascade,

  numero_dia      int,                       -- preenchido por trigger

  codigo          varchar(24),               -- ex.: 20260817-0007

  cliente_id      uuid references usuarios(id),

  criado_por      uuid references usuarios(id),  -- garcom/atendente, quando aplicavel

  sessao_mesa_id  uuid,

  endereco_id     uuid references enderecos(id),

  tipo            pedido_tipo not null,

  canal           pedido_canal not null default 'app_cliente',

  status          pedido_status not null default 'rascunho',

  status_pagamento pedido_pagamento_status not null default 'nao_iniciado',

  subtotal        numeric(10,2) not null default 0 check (subtotal >= 0),

  desconto        numeric(10,2) not null default 0 check (desconto >= 0),

  taxa_entrega    numeric(10,2) not null default 0 check (taxa_entrega >= 0),

  taxa_servico    numeric(10,2) not null default 0 check (taxa_servico >= 0),

  total           numeric(10,2) not null default 0 check (total >= 0),

  observacao      text,

  motivo_cancelamento text,

  previsao_entrega_min int,

  criado_em       timestamptz not null default now(),

  atualizado_em   timestamptz not null default now(),

  confirmado_em   timestamptz,

  concluido_em    timestamptz,

  cancelado_em    timestamptz,

  primary key (id),

  constraint uq_pedido_tenant unique (restaurante_id, id),

  constraint uq_pedido_codigo unique (restaurante_id, codigo),

  constraint fk_pedido_sessao

    foreign key (restaurante_id, sessao_mesa_id)

    references sessoes_mesa(restaurante_id, id) on delete restrict,



  -- RN-PED-002: coerencia entre tipo e vinculos

  constraint chk_pedido_mesa check (

    tipo <> 'mesa' or (sessao_mesa_id is not null and endereco_id is null and taxa_entrega = 0)

  ),

  constraint chk_pedido_retirada check (

    tipo <> 'retirada' or (sessao_mesa_id is null and endereco_id is null

                           and taxa_entrega = 0 and taxa_servico = 0)

  ),

  constraint chk_pedido_delivery check (

    tipo <> 'delivery' or (sessao_mesa_id is null and taxa_servico = 0)

  ),

  -- Endereco so e obrigatorio a partir da confirmacao (RN-PED-003)

  constraint chk_delivery_endereco check (

    status = 'rascunho' or tipo <> 'delivery' or endereco_id is not null

  ),

  -- RN-CAL-007: o total sempre fecha com as parcelas

  constraint chk_total_consistente check (

    total = subtotal - desconto + taxa_entrega + taxa_servico

  ),

  constraint chk_desconto_limite check (desconto <= subtotal),

  constraint chk_cancelamento check (

    status <> 'cancelado' or motivo_cancelamento is not null

  )

);



drop trigger if exists trg_pedidos_atualizado_em on pedidos;

create trigger trg_pedidos_atualizado_em

  before update on pedidos

  for each row execute function set_atualizado_em();



create index if not exists idx_pedidos_restaurante_status on pedidos(restaurante_id, status);

create index if not exists idx_pedidos_cliente on pedidos(cliente_id, criado_em desc);

create index if not exists idx_pedidos_sessao on pedidos(sessao_mesa_id);

create index if not exists idx_pedidos_periodo on pedidos(restaurante_id, criado_em desc);



\-- Numeracao diaria por restaurante (RN-PED-001)

create table if not exists pedido_contadores (

  restaurante_id uuid not null references restaurantes(id) on delete cascade,

  dia            date not null,

  ultimo_numero  int  not null default 0,

  primary key (restaurante_id, dia)

);



create or replace function gerar_codigo_pedido()
returns trigger
language plpgsql
as $$
declare
  v_dia date := (now() at time zone 'America/Sao_Paulo')::date;
  v_numero int;
  v_codigo text;
begin
  -- Mantem o sequencial diario somente para controle interno.
  insert into pedido_contadores (
    restaurante_id,
    dia,
    ultimo_numero
  )
  values (
    new.restaurante_id,
    v_dia,
    1
  )
  on conflict (restaurante_id, dia)
  do update
    set ultimo_numero = pedido_contadores.ultimo_numero + 1
  returning ultimo_numero into v_numero;

  new.numero_dia := v_numero;

  -- Codigo publico: SOMENTE 4 digitos aleatorios, sem data e sem sequencial.
  -- Exemplos: 5837, 2419, 8064.
  loop
    v_codigo := (1000 + floor(random() * 9000))::int::text;

    exit when not exists (
      select 1
      from pedidos
      where restaurante_id = new.restaurante_id
        and codigo = v_codigo
    );
  end loop;

  new.codigo := v_codigo;

  return new;
end;
$$;


drop trigger if exists trg_pedido_codigo on pedidos;

create trigger trg_pedido_codigo

  before insert on pedidos

  for each row when (new\.codigo is null)

  execute function gerar_codigo_pedido();



\-- ---------------------------------------------------------------------

\-- 9. Itens do pedido (com snapshot do produto)

\-- ---------------------------------------------------------------------

create table if not exists pedido_itens (

  id              uuid primary key default gen_random_uuid(),

  restaurante_id  uuid not null,

  pedido_id       uuid not null,

  produto_id      uuid,

  -- Snapshot: o historico nao pode mudar se o produto for renomeado (RN-PED-006)

  produto_nome    varchar(120) not null,

  preco_unitario  numeric(10,2) not null check (preco_unitario >= 0),

  quantidade      int not null check (quantidade > 0),

  total           numeric(10,2) generated always as (quantidade \* preco_unitario) stored,

  observacao      text,

  status          item_status not null default 'pendente',

  cancelado_por   uuid references usuarios(id),

  motivo_cancelamento text,

  criado_em       timestamptz not null default now(),

  atualizado_em   timestamptz not null default now(),

  constraint fk_item_pedido

    foreign key (restaurante_id, pedido_id)

    references pedidos(restaurante_id, id) on delete cascade,

  -- garante que o produto e do mesmo restaurante do pedido (RN-SEG-004)

  constraint fk_item_produto

    foreign key (restaurante_id, produto_id)

    references produtos(restaurante_id, id) on delete set null,

  constraint chk_item_cancelado check (

    status <> 'cancelado' or motivo_cancelamento is not null

  )

);



drop trigger if exists trg_itens_atualizado_em on pedido_itens;

create trigger trg_itens_atualizado_em

  before update on pedido_itens

  for each row execute function set_atualizado_em();



create index if not exists idx_itens_pedido on pedido_itens(pedido_id);

create index if not exists idx_itens_kds on pedido_itens(restaurante_id, status);



\-- ---------------------------------------------------------------------

\-- 10. Historico de status (auditoria)

\-- ---------------------------------------------------------------------

create table if not exists pedido_status_historico (

  id            uuid primary key default gen_random_uuid(),

  pedido_id     uuid not null references pedidos(id) on delete cascade,

  status_antigo pedido_status,

  status_novo   pedido_status not null,

  alterado_por  uuid references usuarios(id),

  observacao    text,

  criado_em     timestamptz not null default now()

);



create index if not exists idx_historico_pedido on pedido_status_historico(pedido_id, criado_em);



create or replace function registrar_status_pedido()

returns trigger

language plpgsql

as $$

begin

  if tg_op = 'INSERT' then

    insert into pedido_status_historico (pedido_id, status_antigo, status_novo, alterado_por)

    values (new\.id, null, new\.status, new\.criado_por);

  elsif new\.status is distinct from old.status then

    insert into pedido_status_historico (pedido_id, status_antigo, status_novo, alterado_por)

    values (new\.id, old.status, new\.status, new\.criado_por);

  end if;

  return new;

end;

$$;



drop trigger if exists trg_pedido_historico on pedidos;

create trigger trg_pedido_historico

  after insert or update of status on pedidos

  for each row execute function registrar_status_pedido();



\-- ---------------------------------------------------------------------

\-- 11. Pagamentos

\-- ---------------------------------------------------------------------

create table if not exists pagamentos (

  id                    uuid primary key default gen_random_uuid(),

  restaurante_id        uuid not null,

  pedido_id             uuid not null,

  metodo                pagamento_metodo not null,

  status                pagamento_status not null default 'pendente',

  valor                 numeric(10,2) not null check (valor > 0),

  troco_para            numeric(10,2) check (troco_para >= 0),

  provedor              varchar(40) not null default 'mock',

  provedor_pagamento_id varchar(160),

  -- Chave de idempotencia: impede cobranca duplicada (RN-PAG-006)

  idempotency_key       varchar(120),

  qr_code               text,

  link_pagamento        text,

  resposta_provedor     jsonb,

  registrado_por        uuid references usuarios(id),

  criado_em             timestamptz not null default now(),

  atualizado_em         timestamptz not null default now(),

  aprovado_em           timestamptz,

  constraint fk_pagamento_pedido

    foreign key (restaurante_id, pedido_id)

    references pedidos(restaurante_id, id) on delete cascade,

  constraint uq_pagamento_idempotency unique (restaurante_id, idempotency_key)

);



drop trigger if exists trg_pagamentos_atualizado_em on pagamentos;

create trigger trg_pagamentos_atualizado_em

  before update on pagamentos

  for each row execute function set_atualizado_em();



create index if not exists idx_pagamentos_pedido on pagamentos(pedido_id);

create index if not exists idx_pagamentos_status on pagamentos(restaurante_id, status);



\-- ---------------------------------------------------------------------

\-- 12. Recalculo de totais (fonte unica da verdade dos valores)

\-- ---------------------------------------------------------------------

\-- Recalcula subtotal, taxa de servico e total de um pedido a partir dos

\-- itens NAO cancelados. Chamada pelo backend dentro da transacao.

create or replace function recalcular_pedido(p_pedido_id uuid)

returns void

language plpgsql

as $$

declare

  v_subtotal numeric(10,2);

  v_pedido   pedidos%rowtype;

  v_perc     numeric(5,2);

  v_servico_aceito boolean;

  v_taxa_servico numeric(10,2) := 0;

begin

  select \* into v_pedido from pedidos where id = p_pedido_id for update;

  if not found then

    raise exception 'Pedido % nao encontrado', p_pedido_id;

  end if;



  select coalesce(sum(total), 0) into v_subtotal

    from pedido_itens

   where pedido_id = p_pedido_id

     and status <> 'cancelado';



  if v_pedido.tipo = 'mesa' then

    select r.taxa_servico_percentual, coalesce(s.servico_aceito, true)

      into v_perc, v_servico_aceito

      from restaurantes r

      left join sessoes_mesa s on s.id = v_pedido.sessao_mesa_id

     where r.id = v_pedido.restaurante_id;



    if v_servico_aceito then

      v_taxa_servico := round(v_subtotal \* v_perc / 100.0, 2);

    end if;

  end if;



  update pedidos

     set subtotal     = v_subtotal,

         taxa_servico = v_taxa_servico,

         desconto     = least(desconto, v_subtotal),

         total        = v_subtotal - least(desconto, v_subtotal)

                        + taxa_entrega + v_taxa_servico

   where id = p_pedido_id;

end;

$$;



\-- ---------------------------------------------------------------------

\-- 13. Visao de apoio para o relatorio gerencial

\-- ---------------------------------------------------------------------

create or replace view vw_pedidos_faturados as

select p.restaurante_id,

       p.id as pedido_id,

       p.codigo,

       p.tipo,

       p.criado_em,

       p.concluido_em,

       p.total

  from pedidos p

 where p.status = 'concluido';
