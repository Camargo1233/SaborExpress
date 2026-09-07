--
-- PostgreSQL database dump
--

\restrict dhKdcw6Nv6yOQf8U6PJ5lCnzyuLn7iUfQggrKbLnMv7CFoD5Ay43U8Tpi9HR1A6

-- Dumped from database version 16.13 (Ubuntu 16.13-0ubuntu0.24.04.1)
-- Dumped by pg_dump version 16.13 (Ubuntu 16.13-0ubuntu0.24.04.1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

-- *not* creating schema, since initdb creates it


--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS '';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: item_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.item_status AS ENUM (
    'pendente',
    'enviado_cozinha',
    'em_preparo',
    'pronto',
    'entregue',
    'cancelado'
);


--
-- Name: mesa_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.mesa_status AS ENUM (
    'livre',
    'ocupada',
    'reservada',
    'interditada'
);


--
-- Name: pagamento_metodo; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.pagamento_metodo AS ENUM (
    'pix',
    'cartao_credito',
    'cartao_debito',
    'dinheiro',
    'vale_refeicao',
    'na_entrega',
    'no_local'
);


--
-- Name: pagamento_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.pagamento_status AS ENUM (
    'pendente',
    'aprovado',
    'recusado',
    'cancelado',
    'estornado'
);


--
-- Name: pedido_canal; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.pedido_canal AS ENUM (
    'app_cliente',
    'garcom',
    'balcao'
);


--
-- Name: pedido_pagamento_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.pedido_pagamento_status AS ENUM (
    'nao_iniciado',
    'pendente',
    'parcial',
    'pago',
    'estornado'
);


--
-- Name: pedido_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.pedido_status AS ENUM (
    'rascunho',
    'confirmado',
    'em_preparo',
    'pronto',
    'em_entrega',
    'concluido',
    'cancelado'
);


--
-- Name: pedido_tipo; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.pedido_tipo AS ENUM (
    'mesa',
    'delivery',
    'retirada'
);


--
-- Name: perfil_acesso; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.perfil_acesso AS ENUM (
    'gerente',
    'garcom',
    'cozinha',
    'entregador'
);


--
-- Name: sessao_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.sessao_status AS ENUM (
    'aberta',
    'fechada',
    'cancelada'
);


--
-- Name: gerar_codigo_pedido(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.gerar_codigo_pedido() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
  v_dia date := (now() at time zone 'America/Sao_Paulo')::date;
  v_numero int;
begin
  insert into pedido_contadores (restaurante_id, dia, ultimo_numero)
  values (new.restaurante_id, v_dia, 1)
  on conflict (restaurante_id, dia)
  do update set ultimo_numero = pedido_contadores.ultimo_numero + 1
  returning ultimo_numero into v_numero;

  new.numero_dia := v_numero;
  new.codigo := to_char(v_dia, 'YYYYMMDD') || '-' || lpad(v_numero::text, 4, '0');
  return new;
end;
$$;


--
-- Name: recalcular_pedido(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.recalcular_pedido(p_pedido_id uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$
declare
  v_subtotal numeric(10,2);
  v_pedido   pedidos%rowtype;
  v_perc     numeric(5,2);
  v_servico_aceito boolean;
  v_taxa_servico numeric(10,2) := 0;
begin
  select * into v_pedido from pedidos where id = p_pedido_id for update;
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
      v_taxa_servico := round(v_subtotal * v_perc / 100.0, 2);
    end if;
  end if;

  update pedidos
     set subtotal     = v_subtotal,
         taxa_servico = v_taxa_servico,
         desconto     = least(desconto, v_subtotal),
         total        = v_subtotal - least(desconto, v_subtotal)
                        + taxa_entrega + v_taxa_servico
   where id = p_pedido_id;
end;
$$;


--
-- Name: registrar_status_pedido(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.registrar_status_pedido() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  if tg_op = 'INSERT' then
    insert into pedido_status_historico (pedido_id, status_antigo, status_novo, alterado_por)
    values (new.id, null, new.status, new.criado_por);
  elsif new.status is distinct from old.status then
    insert into pedido_status_historico (pedido_id, status_antigo, status_novo, alterado_por)
    values (new.id, old.status, new.status, new.criado_por);
  end if;
  return new;
end;
$$;


--
-- Name: set_atualizado_em(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_atualizado_em() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  new.atualizado_em = now();
  return new;
end;
$$;


--
-- Name: sincronizar_status_mesa(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sincronizar_status_mesa() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  if new.status = 'aberta' then
    update mesas set status = 'ocupada' where id = new.mesa_id;
  else
    update mesas set status = 'livre'
     where id = new.mesa_id
       and not exists (
         select 1 from sessoes_mesa s
          where s.mesa_id = new.mesa_id and s.status = 'aberta' and s.id <> new.id
       );
  end if;
  return new;
end;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: _migracoes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public._migracoes (
    arquivo text NOT NULL,
    aplicada_em timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: categorias; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.categorias (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    restaurante_id uuid NOT NULL,
    nome character varying(80) NOT NULL,
    descricao text,
    ordem integer DEFAULT 0 NOT NULL,
    ativo boolean DEFAULT true NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    atualizado_em timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: enderecos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.enderecos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    usuario_id uuid NOT NULL,
    apelido character varying(80) DEFAULT 'Principal'::character varying NOT NULL,
    cep character varying(9) NOT NULL,
    logradouro character varying(160) NOT NULL,
    numero character varying(20) NOT NULL,
    complemento character varying(120),
    bairro character varying(100) NOT NULL,
    cidade character varying(100) NOT NULL,
    estado character(2) NOT NULL,
    referencia character varying(160),
    latitude numeric(10,7),
    longitude numeric(10,7),
    principal boolean DEFAULT false NOT NULL,
    ativo boolean DEFAULT true NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: mesas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mesas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    restaurante_id uuid NOT NULL,
    numero integer NOT NULL,
    apelido character varying(40),
    capacidade integer DEFAULT 4 NOT NULL,
    status public.mesa_status DEFAULT 'livre'::public.mesa_status NOT NULL,
    ativo boolean DEFAULT true NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    atualizado_em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT mesas_capacidade_check CHECK ((capacidade > 0)),
    CONSTRAINT mesas_numero_check CHECK ((numero > 0))
);


--
-- Name: pagamentos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pagamentos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    restaurante_id uuid NOT NULL,
    pedido_id uuid NOT NULL,
    metodo public.pagamento_metodo NOT NULL,
    status public.pagamento_status DEFAULT 'pendente'::public.pagamento_status NOT NULL,
    valor numeric(10,2) NOT NULL,
    troco_para numeric(10,2),
    provedor character varying(40) DEFAULT 'mock'::character varying NOT NULL,
    provedor_pagamento_id character varying(160),
    idempotency_key character varying(120),
    qr_code text,
    link_pagamento text,
    resposta_provedor jsonb,
    registrado_por uuid,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    atualizado_em timestamp with time zone DEFAULT now() NOT NULL,
    aprovado_em timestamp with time zone,
    CONSTRAINT pagamentos_troco_para_check CHECK ((troco_para >= (0)::numeric)),
    CONSTRAINT pagamentos_valor_check CHECK ((valor > (0)::numeric))
);


--
-- Name: pedido_contadores; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pedido_contadores (
    restaurante_id uuid NOT NULL,
    dia date NOT NULL,
    ultimo_numero integer DEFAULT 0 NOT NULL
);


--
-- Name: pedido_itens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pedido_itens (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    restaurante_id uuid NOT NULL,
    pedido_id uuid NOT NULL,
    produto_id uuid,
    produto_nome character varying(120) NOT NULL,
    preco_unitario numeric(10,2) NOT NULL,
    quantidade integer NOT NULL,
    total numeric(10,2) GENERATED ALWAYS AS (((quantidade)::numeric * preco_unitario)) STORED,
    observacao text,
    status public.item_status DEFAULT 'pendente'::public.item_status NOT NULL,
    cancelado_por uuid,
    motivo_cancelamento text,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    atualizado_em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_item_cancelado CHECK (((status <> 'cancelado'::public.item_status) OR (motivo_cancelamento IS NOT NULL))),
    CONSTRAINT pedido_itens_preco_unitario_check CHECK ((preco_unitario >= (0)::numeric)),
    CONSTRAINT pedido_itens_quantidade_check CHECK ((quantidade > 0))
);


--
-- Name: pedido_status_historico; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pedido_status_historico (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    pedido_id uuid NOT NULL,
    status_antigo public.pedido_status,
    status_novo public.pedido_status NOT NULL,
    alterado_por uuid,
    observacao text,
    criado_em timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: pedidos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pedidos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    restaurante_id uuid NOT NULL,
    numero_dia integer,
    codigo character varying(24),
    cliente_id uuid,
    criado_por uuid,
    sessao_mesa_id uuid,
    endereco_id uuid,
    tipo public.pedido_tipo NOT NULL,
    canal public.pedido_canal DEFAULT 'app_cliente'::public.pedido_canal NOT NULL,
    status public.pedido_status DEFAULT 'rascunho'::public.pedido_status NOT NULL,
    status_pagamento public.pedido_pagamento_status DEFAULT 'nao_iniciado'::public.pedido_pagamento_status NOT NULL,
    subtotal numeric(10,2) DEFAULT 0 NOT NULL,
    desconto numeric(10,2) DEFAULT 0 NOT NULL,
    taxa_entrega numeric(10,2) DEFAULT 0 NOT NULL,
    taxa_servico numeric(10,2) DEFAULT 0 NOT NULL,
    total numeric(10,2) DEFAULT 0 NOT NULL,
    observacao text,
    motivo_cancelamento text,
    previsao_entrega_min integer,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    atualizado_em timestamp with time zone DEFAULT now() NOT NULL,
    confirmado_em timestamp with time zone,
    concluido_em timestamp with time zone,
    cancelado_em timestamp with time zone,
    CONSTRAINT chk_cancelamento CHECK (((status <> 'cancelado'::public.pedido_status) OR (motivo_cancelamento IS NOT NULL))),
    CONSTRAINT chk_delivery_endereco CHECK (((status = 'rascunho'::public.pedido_status) OR (tipo <> 'delivery'::public.pedido_tipo) OR (endereco_id IS NOT NULL))),
    CONSTRAINT chk_desconto_limite CHECK ((desconto <= subtotal)),
    CONSTRAINT chk_pedido_delivery CHECK (((tipo <> 'delivery'::public.pedido_tipo) OR ((sessao_mesa_id IS NULL) AND (taxa_servico = (0)::numeric)))),
    CONSTRAINT chk_pedido_mesa CHECK (((tipo <> 'mesa'::public.pedido_tipo) OR ((sessao_mesa_id IS NOT NULL) AND (endereco_id IS NULL) AND (taxa_entrega = (0)::numeric)))),
    CONSTRAINT chk_pedido_retirada CHECK (((tipo <> 'retirada'::public.pedido_tipo) OR ((sessao_mesa_id IS NULL) AND (endereco_id IS NULL) AND (taxa_entrega = (0)::numeric) AND (taxa_servico = (0)::numeric)))),
    CONSTRAINT chk_total_consistente CHECK ((total = (((subtotal - desconto) + taxa_entrega) + taxa_servico))),
    CONSTRAINT pedidos_desconto_check CHECK ((desconto >= (0)::numeric)),
    CONSTRAINT pedidos_subtotal_check CHECK ((subtotal >= (0)::numeric)),
    CONSTRAINT pedidos_taxa_entrega_check CHECK ((taxa_entrega >= (0)::numeric)),
    CONSTRAINT pedidos_taxa_servico_check CHECK ((taxa_servico >= (0)::numeric)),
    CONSTRAINT pedidos_total_check CHECK ((total >= (0)::numeric))
);


--
-- Name: produtos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.produtos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    restaurante_id uuid NOT NULL,
    categoria_id uuid,
    nome character varying(120) NOT NULL,
    descricao text,
    preco numeric(10,2) NOT NULL,
    imagem_url text,
    tempo_preparo_min integer,
    destaque boolean DEFAULT false NOT NULL,
    disponivel boolean DEFAULT true NOT NULL,
    ativo boolean DEFAULT true NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    atualizado_em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT produtos_preco_check CHECK ((preco >= (0)::numeric)),
    CONSTRAINT produtos_tempo_preparo_min_check CHECK ((tempo_preparo_min >= 0))
);


--
-- Name: restaurante_membros; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.restaurante_membros (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    restaurante_id uuid NOT NULL,
    usuario_id uuid NOT NULL,
    perfil public.perfil_acesso NOT NULL,
    ativo boolean DEFAULT true NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: restaurantes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.restaurantes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nome character varying(120) NOT NULL,
    slug character varying(80) NOT NULL,
    cnpj character varying(18),
    telefone character varying(30),
    taxa_servico_percentual numeric(5,2) DEFAULT 10.00 NOT NULL,
    taxa_entrega_padrao numeric(10,2) DEFAULT 0 NOT NULL,
    pedido_minimo_delivery numeric(10,2) DEFAULT 0 NOT NULL,
    frete_gratis_acima_de numeric(10,2),
    raio_entrega_km numeric(6,2),
    aceita_delivery boolean DEFAULT true NOT NULL,
    aceita_retirada boolean DEFAULT true NOT NULL,
    aceita_mesa boolean DEFAULT true NOT NULL,
    aberto boolean DEFAULT true NOT NULL,
    ativo boolean DEFAULT true NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    atualizado_em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT restaurantes_frete_gratis_acima_de_check CHECK ((frete_gratis_acima_de >= (0)::numeric)),
    CONSTRAINT restaurantes_pedido_minimo_delivery_check CHECK ((pedido_minimo_delivery >= (0)::numeric)),
    CONSTRAINT restaurantes_raio_entrega_km_check CHECK ((raio_entrega_km > (0)::numeric)),
    CONSTRAINT restaurantes_taxa_entrega_padrao_check CHECK ((taxa_entrega_padrao >= (0)::numeric)),
    CONSTRAINT restaurantes_taxa_servico_percentual_check CHECK (((taxa_servico_percentual >= (0)::numeric) AND (taxa_servico_percentual <= (100)::numeric)))
);


--
-- Name: sessoes_mesa; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sessoes_mesa (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    restaurante_id uuid NOT NULL,
    mesa_id uuid NOT NULL,
    aberta_por uuid,
    fechada_por uuid,
    status public.sessao_status DEFAULT 'aberta'::public.sessao_status NOT NULL,
    qtd_pessoas integer DEFAULT 1 NOT NULL,
    servico_aceito boolean DEFAULT true NOT NULL,
    aberta_em timestamp with time zone DEFAULT now() NOT NULL,
    fechada_em timestamp with time zone,
    observacao text,
    CONSTRAINT chk_sessao_fechamento CHECK ((((status = 'aberta'::public.sessao_status) AND (fechada_em IS NULL)) OR ((status <> 'aberta'::public.sessao_status) AND (fechada_em IS NOT NULL)))),
    CONSTRAINT sessoes_mesa_qtd_pessoas_check CHECK ((qtd_pessoas > 0))
);


--
-- Name: usuarios; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.usuarios (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nome character varying(120) NOT NULL,
    email character varying(160) NOT NULL,
    telefone character varying(30),
    senha_hash text NOT NULL,
    ativo boolean DEFAULT true NOT NULL,
    ultimo_login_em timestamp with time zone,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    atualizado_em timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: vw_pedidos_faturados; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_pedidos_faturados AS
 SELECT restaurante_id,
    id AS pedido_id,
    codigo,
    tipo,
    criado_em,
    concluido_em,
    total
   FROM public.pedidos p
  WHERE (status = 'concluido'::public.pedido_status);


--
-- Data for Name: _migracoes; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public._migracoes (arquivo, aplicada_em) FROM stdin;
001_schema.sql	2026-08-24 14:42:29.303544+00
002_seed.sql	2026-08-24 14:42:29.39361+00
\.


--
-- Data for Name: categorias; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.categorias (id, restaurante_id, nome, descricao, ordem, ativo, criado_em, atualizado_em) FROM stdin;
c98c9fdd-114c-45ca-96d1-7c5afe953dec	ce874d28-ef12-48e5-8dce-af8e63ea6cfd	Pizzas	Pizzas tradicionais e especiais	1	t	2026-08-24 14:42:29.39361+00	2026-08-24 14:42:29.39361+00
d3cb23f1-fdd6-463e-aa80-8c6f24ef808c	ce874d28-ef12-48e5-8dce-af8e63ea6cfd	Lanches	Lanches artesanais	2	t	2026-08-24 14:42:29.39361+00	2026-08-24 14:42:29.39361+00
e5b9a01e-c5e9-4b9c-a54c-7764c4de74dc	ce874d28-ef12-48e5-8dce-af8e63ea6cfd	Massas	Massas e pratos quentes	3	t	2026-08-24 14:42:29.39361+00	2026-08-24 14:42:29.39361+00
3935a818-92a4-4808-9e2e-72b5324e004e	ce874d28-ef12-48e5-8dce-af8e63ea6cfd	Bebidas	Refrigerantes, sucos e agua	4	t	2026-08-24 14:42:29.39361+00	2026-08-24 14:42:29.39361+00
fd13d321-8772-4507-afcb-7b08ab387e23	ce874d28-ef12-48e5-8dce-af8e63ea6cfd	Sobremesas	Doces e sobremesas da casa	5	t	2026-08-24 14:42:29.39361+00	2026-08-24 14:42:29.39361+00
e56d5bf4-dede-47c9-b8df-f87fca4f7193	cf462d8e-3ab8-4217-8321-2d4c3bb14de4	Massas	Massas frescas artesanais	1	t	2026-08-24 14:42:29.39361+00	2026-08-24 14:42:29.39361+00
3939b8e9-8efd-4bbe-81c9-b4936108d908	cf462d8e-3ab8-4217-8321-2d4c3bb14de4	Bebidas	Vinhos e refrigerantes	2	t	2026-08-24 14:42:29.39361+00	2026-08-24 14:42:29.39361+00
\.


--
-- Data for Name: enderecos; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.enderecos (id, usuario_id, apelido, cep, logradouro, numero, complemento, bairro, cidade, estado, referencia, latitude, longitude, principal, ativo, criado_em) FROM stdin;
6524913f-a6d1-48d6-a53a-4f804f300f94	15fd5764-3359-4330-9ef7-d2692f844d31	Casa	01000-000	Rua Exemplo	123	\N	Centro	Sao Paulo	SP	\N	\N	\N	t	t	2026-08-24 14:42:29.39361+00
\.


--
-- Data for Name: mesas; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.mesas (id, restaurante_id, numero, apelido, capacidade, status, ativo, criado_em, atualizado_em) FROM stdin;
5bc140fb-ba75-4406-a48e-350928be27fd	ce874d28-ef12-48e5-8dce-af8e63ea6cfd	1	\N	4	livre	t	2026-08-24 14:42:29.39361+00	2026-08-24 14:42:29.39361+00
bdf4f8dd-2ed5-4b83-8146-1f02d4f5acf4	ce874d28-ef12-48e5-8dce-af8e63ea6cfd	2	\N	4	livre	t	2026-08-24 14:42:29.39361+00	2026-08-24 14:42:29.39361+00
21bedf5c-94eb-4fc7-b86d-db58bf5f6411	ce874d28-ef12-48e5-8dce-af8e63ea6cfd	3	\N	4	livre	t	2026-08-24 14:42:29.39361+00	2026-08-24 14:42:29.39361+00
eb58366c-95f7-42c1-84e7-b3040dabddfa	ce874d28-ef12-48e5-8dce-af8e63ea6cfd	4	\N	6	livre	t	2026-08-24 14:42:29.39361+00	2026-08-24 14:42:29.39361+00
d6e0896c-4ce1-4daf-b468-73d0a86e264d	ce874d28-ef12-48e5-8dce-af8e63ea6cfd	5	\N	2	livre	t	2026-08-24 14:42:29.39361+00	2026-08-24 14:42:29.39361+00
92f183b0-17ae-4ea6-bf9c-3027f5907751	ce874d28-ef12-48e5-8dce-af8e63ea6cfd	6	\N	6	livre	t	2026-08-24 14:42:29.39361+00	2026-08-24 14:42:29.39361+00
11fa7671-9954-45f9-a37f-f5986e0b563b	ce874d28-ef12-48e5-8dce-af8e63ea6cfd	7	\N	2	livre	t	2026-08-24 14:42:29.39361+00	2026-08-24 14:42:29.39361+00
fa5b73fc-aa1d-40da-ab56-0b476b86e704	ce874d28-ef12-48e5-8dce-af8e63ea6cfd	8	\N	4	livre	t	2026-08-24 14:42:29.39361+00	2026-08-24 14:42:29.39361+00
53f91660-cc2b-4dbe-8ae1-d32331b1ae91	ce874d28-ef12-48e5-8dce-af8e63ea6cfd	9	\N	4	livre	t	2026-08-24 14:42:29.39361+00	2026-08-24 14:42:29.39361+00
a5dbfb6c-7017-44e1-99da-cc6d8ada9341	ce874d28-ef12-48e5-8dce-af8e63ea6cfd	10	\N	8	livre	t	2026-08-24 14:42:29.39361+00	2026-08-24 14:42:29.39361+00
633c2ad8-81c1-4f8b-8dac-4a2a7639084c	cf462d8e-3ab8-4217-8321-2d4c3bb14de4	1	\N	2	livre	t	2026-08-24 14:42:29.39361+00	2026-08-24 14:42:29.39361+00
58f9191f-5d7f-4728-a7b3-0b2fa79a9164	cf462d8e-3ab8-4217-8321-2d4c3bb14de4	2	\N	4	livre	t	2026-08-24 14:42:29.39361+00	2026-08-24 14:42:29.39361+00
e2916f4e-99b4-4a6e-9105-560cab553637	cf462d8e-3ab8-4217-8321-2d4c3bb14de4	3	\N	4	livre	t	2026-08-24 14:42:29.39361+00	2026-08-24 14:42:29.39361+00
\.


--
-- Data for Name: pagamentos; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.pagamentos (id, restaurante_id, pedido_id, metodo, status, valor, troco_para, provedor, provedor_pagamento_id, idempotency_key, qr_code, link_pagamento, resposta_provedor, registrado_por, criado_em, atualizado_em, aprovado_em) FROM stdin;
\.


--
-- Data for Name: pedido_contadores; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.pedido_contadores (restaurante_id, dia, ultimo_numero) FROM stdin;
\.


--
-- Data for Name: pedido_itens; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.pedido_itens (id, restaurante_id, pedido_id, produto_id, produto_nome, preco_unitario, quantidade, observacao, status, cancelado_por, motivo_cancelamento, criado_em, atualizado_em) FROM stdin;
\.


--
-- Data for Name: pedido_status_historico; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.pedido_status_historico (id, pedido_id, status_antigo, status_novo, alterado_por, observacao, criado_em) FROM stdin;
\.


--
-- Data for Name: pedidos; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.pedidos (id, restaurante_id, numero_dia, codigo, cliente_id, criado_por, sessao_mesa_id, endereco_id, tipo, canal, status, status_pagamento, subtotal, desconto, taxa_entrega, taxa_servico, total, observacao, motivo_cancelamento, previsao_entrega_min, criado_em, atualizado_em, confirmado_em, concluido_em, cancelado_em) FROM stdin;
\.


--
-- Data for Name: produtos; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.produtos (id, restaurante_id, categoria_id, nome, descricao, preco, imagem_url, tempo_preparo_min, destaque, disponivel, ativo, criado_em, atualizado_em) FROM stdin;
d7d43ffd-cb11-4a65-8f63-4909a2f95c3e	ce874d28-ef12-48e5-8dce-af8e63ea6cfd	3935a818-92a4-4808-9e2e-72b5324e004e	Suco de Laranja 500ml	Suco natural feito na hora.	9.50	\N	5	f	t	t	2026-08-24 14:42:29.39361+00	2026-08-24 14:42:29.39361+00
3567a606-0a07-4410-81c6-a16bf16bab1f	ce874d28-ef12-48e5-8dce-af8e63ea6cfd	3935a818-92a4-4808-9e2e-72b5324e004e	Coca-Cola Lata 350ml	Lata 350ml gelada.	6.00	https://images.unsplash.com/photo-1629203851122-3726ecdf080e?w=600	1	t	t	t	2026-08-24 14:42:29.39361+00	2026-08-24 14:42:29.39361+00
d937c8a8-2526-4f5f-9836-2968895acc77	ce874d28-ef12-48e5-8dce-af8e63ea6cfd	c98c9fdd-114c-45ca-96d1-7c5afe953dec	Pizza Calabresa	Calabresa fatiada, cebola roxa, mussarela e azeitonas.	42.00	https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=600	25	t	t	t	2026-08-24 14:42:29.39361+00	2026-08-24 14:42:29.39361+00
e8f3b2ce-db13-4fb3-94b0-dff4a218a559	ce874d28-ef12-48e5-8dce-af8e63ea6cfd	c98c9fdd-114c-45ca-96d1-7c5afe953dec	Pizza de Bacon	Molho artesanal, mussarela, bacon crocante e oregano.	45.00	https://images.unsplash.com/photo-1513104890138-7c749659a591?w=600	25	t	t	t	2026-08-24 14:42:29.39361+00	2026-08-24 14:42:29.39361+00
d6e592f0-d696-4a63-a0b7-293573731d80	ce874d28-ef12-48e5-8dce-af8e63ea6cfd	d3cb23f1-fdd6-463e-aa80-8c6f24ef808c	X-Bacon Artesanal	Hamburguer, queijo, bacon, alface, tomate e molho da casa.	28.00	https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=600	15	f	t	t	2026-08-24 14:42:29.39361+00	2026-08-24 14:42:29.39361+00
6328859b-6bc8-475a-85c8-8e5a81a4c3e5	ce874d28-ef12-48e5-8dce-af8e63ea6cfd	e5b9a01e-c5e9-4b9c-a54c-7764c4de74dc	Espaguete Alho e Oleo	Massa fresca, alho dourado, azeite e cheiro-verde.	34.90	https://images.unsplash.com/photo-1621996346565-e3dbc646d9a9?w=600	18	f	t	t	2026-08-24 14:42:29.39361+00	2026-08-24 14:42:29.39361+00
d513ad51-f9b9-45cd-ac7d-73b272c18e0f	ce874d28-ef12-48e5-8dce-af8e63ea6cfd	fd13d321-8772-4507-afcb-7b08ab387e23	Pudim da Casa	Pudim cremoso com calda de caramelo.	12.00	https://images.unsplash.com/photo-1551024506-0bccd828d307?w=600	5	f	t	t	2026-08-24 14:42:29.39361+00	2026-08-24 14:42:29.39361+00
156e4fa1-d9d6-4c73-8d61-10aa138ddf56	cf462d8e-3ab8-4217-8321-2d4c3bb14de4	e56d5bf4-dede-47c9-b8df-f87fca4f7193	Nhoque ao Sugo	Nhoque artesanal com molho de tomate italiano.	39.00	\N	20	t	t	t	2026-08-24 14:42:29.39361+00	2026-08-24 14:42:29.39361+00
78e9eb44-2f9a-41b0-82a5-bbbd9279ebda	cf462d8e-3ab8-4217-8321-2d4c3bb14de4	3939b8e9-8efd-4bbe-81c9-b4936108d908	Agua com Gas	Garrafa 500ml.	7.00	\N	1	f	t	t	2026-08-24 14:42:29.39361+00	2026-08-24 14:42:29.39361+00
\.


--
-- Data for Name: restaurante_membros; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.restaurante_membros (id, restaurante_id, usuario_id, perfil, ativo, criado_em) FROM stdin;
7ae2e7dc-7688-4182-a6d8-2a98ea4d7049	ce874d28-ef12-48e5-8dce-af8e63ea6cfd	44b0d0f9-b3ae-444f-be58-a17ff397a070	cozinha	t	2026-08-24 14:42:29.39361+00
534775ff-a47c-4481-a16b-3269e74fa3ca	ce874d28-ef12-48e5-8dce-af8e63ea6cfd	498a90aa-ad3b-4ac1-955f-075f85c3d3b1	garcom	t	2026-08-24 14:42:29.39361+00
1aefd0cb-620e-4207-a9fd-fc0e873602ea	ce874d28-ef12-48e5-8dce-af8e63ea6cfd	3906f131-8cad-44cc-8174-30a5d4afbd16	gerente	t	2026-08-24 14:42:29.39361+00
1cbe348c-138b-4f37-8118-c97d51206ad9	cf462d8e-3ab8-4217-8321-2d4c3bb14de4	47e66854-afd6-402e-b24f-a71655eafba8	gerente	t	2026-08-24 14:42:29.39361+00
\.


--
-- Data for Name: restaurantes; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.restaurantes (id, nome, slug, cnpj, telefone, taxa_servico_percentual, taxa_entrega_padrao, pedido_minimo_delivery, frete_gratis_acima_de, raio_entrega_km, aceita_delivery, aceita_retirada, aceita_mesa, aberto, ativo, criado_em, atualizado_em) FROM stdin;
ce874d28-ef12-48e5-8dce-af8e63ea6cfd	Sabor Express	sabor-express	\N	(11) 4000-1000	10.00	10.00	25.00	120.00	8.00	t	t	t	t	t	2026-08-24 14:42:29.39361+00	2026-08-24 14:42:29.39361+00
cf462d8e-3ab8-4217-8321-2d4c3bb14de4	Cantina Bella	cantina-bella	\N	(11) 4000-2000	12.00	8.00	30.00	150.00	6.00	t	t	t	t	t	2026-08-24 14:42:29.39361+00	2026-08-24 14:42:29.39361+00
\.


--
-- Data for Name: sessoes_mesa; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.sessoes_mesa (id, restaurante_id, mesa_id, aberta_por, fechada_por, status, qtd_pessoas, servico_aceito, aberta_em, fechada_em, observacao) FROM stdin;
\.


--
-- Data for Name: usuarios; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.usuarios (id, nome, email, telefone, senha_hash, ativo, ultimo_login_em, criado_em, atualizado_em) FROM stdin;
3906f131-8cad-44cc-8174-30a5d4afbd16	Davi Gerente	gerente@saborexpress.com	(11) 99999-0001	$2a$06$D9Tln7yDLPzMGM88..7Q5e0Ip6OM6jIkzIUcI372A9Dx.W0iJNaVq	t	\N	2026-08-24 14:42:29.39361+00	2026-08-24 14:42:29.39361+00
498a90aa-ad3b-4ac1-955f-075f85c3d3b1	Ana Garcom	garcom@saborexpress.com	(11) 99999-0002	$2a$06$bYlRcd2woI0r4Tb4nq9UCOWfXXE2FXAQEKRdrQng/7OYT.ayTYwP.	t	\N	2026-08-24 14:42:29.39361+00	2026-08-24 14:42:29.39361+00
44b0d0f9-b3ae-444f-be58-a17ff397a070	Bruno Cozinha	cozinha@saborexpress.com	(11) 99999-0003	$2a$06$o2xHLrlnMM4xVVEhmNbAme8JZgGenQqgYSgb05mZlU2wweWZEDzBm	t	\N	2026-08-24 14:42:29.39361+00	2026-08-24 14:42:29.39361+00
15fd5764-3359-4330-9ef7-d2692f844d31	Carla Cliente	cliente@email.com	(11) 98888-0001	$2a$06$T0/hDLG5Aq4MEewGmRjzsOJcYyaGQ4THDgq56zqPTmoYY7dT9RVx6	t	\N	2026-08-24 14:42:29.39361+00	2026-08-24 14:42:29.39361+00
47e66854-afd6-402e-b24f-a71655eafba8	Marco Bella	gerente@cantinabella.com	(11) 97777-0001	$2a$06$JSlD5zE36HT/eaQw7Oq3HeOTjLHGR.3v0b0QCLx4xNqiu2WaS6DpS	t	\N	2026-08-24 14:42:29.39361+00	2026-08-24 14:42:29.39361+00
\.


--
-- Name: _migracoes _migracoes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public._migracoes
    ADD CONSTRAINT _migracoes_pkey PRIMARY KEY (arquivo);


--
-- Name: categorias categorias_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categorias
    ADD CONSTRAINT categorias_pkey PRIMARY KEY (id);


--
-- Name: enderecos enderecos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enderecos
    ADD CONSTRAINT enderecos_pkey PRIMARY KEY (id);


--
-- Name: mesas mesas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mesas
    ADD CONSTRAINT mesas_pkey PRIMARY KEY (id);


--
-- Name: pagamentos pagamentos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pagamentos
    ADD CONSTRAINT pagamentos_pkey PRIMARY KEY (id);


--
-- Name: pedido_contadores pedido_contadores_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pedido_contadores
    ADD CONSTRAINT pedido_contadores_pkey PRIMARY KEY (restaurante_id, dia);


--
-- Name: pedido_itens pedido_itens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pedido_itens
    ADD CONSTRAINT pedido_itens_pkey PRIMARY KEY (id);


--
-- Name: pedido_status_historico pedido_status_historico_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pedido_status_historico
    ADD CONSTRAINT pedido_status_historico_pkey PRIMARY KEY (id);


--
-- Name: pedidos pedidos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pedidos
    ADD CONSTRAINT pedidos_pkey PRIMARY KEY (id);


--
-- Name: produtos produtos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.produtos
    ADD CONSTRAINT produtos_pkey PRIMARY KEY (id);


--
-- Name: restaurante_membros restaurante_membros_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.restaurante_membros
    ADD CONSTRAINT restaurante_membros_pkey PRIMARY KEY (id);


--
-- Name: restaurantes restaurantes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.restaurantes
    ADD CONSTRAINT restaurantes_pkey PRIMARY KEY (id);


--
-- Name: restaurantes restaurantes_slug_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.restaurantes
    ADD CONSTRAINT restaurantes_slug_key UNIQUE (slug);


--
-- Name: sessoes_mesa sessoes_mesa_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessoes_mesa
    ADD CONSTRAINT sessoes_mesa_pkey PRIMARY KEY (id);


--
-- Name: categorias uq_categoria_nome_por_restaurante; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categorias
    ADD CONSTRAINT uq_categoria_nome_por_restaurante UNIQUE (restaurante_id, nome);


--
-- Name: categorias uq_categoria_tenant; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categorias
    ADD CONSTRAINT uq_categoria_tenant UNIQUE (restaurante_id, id);


--
-- Name: restaurante_membros uq_membro_por_restaurante; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.restaurante_membros
    ADD CONSTRAINT uq_membro_por_restaurante UNIQUE (restaurante_id, usuario_id);


--
-- Name: mesas uq_mesa_numero_por_restaurante; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mesas
    ADD CONSTRAINT uq_mesa_numero_por_restaurante UNIQUE (restaurante_id, numero);


--
-- Name: mesas uq_mesa_tenant; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mesas
    ADD CONSTRAINT uq_mesa_tenant UNIQUE (restaurante_id, id);


--
-- Name: pagamentos uq_pagamento_idempotency; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pagamentos
    ADD CONSTRAINT uq_pagamento_idempotency UNIQUE (restaurante_id, idempotency_key);


--
-- Name: pedidos uq_pedido_codigo; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pedidos
    ADD CONSTRAINT uq_pedido_codigo UNIQUE (restaurante_id, codigo);


--
-- Name: pedidos uq_pedido_tenant; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pedidos
    ADD CONSTRAINT uq_pedido_tenant UNIQUE (restaurante_id, id);


--
-- Name: produtos uq_produto_nome_por_restaurante; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.produtos
    ADD CONSTRAINT uq_produto_nome_por_restaurante UNIQUE (restaurante_id, nome);


--
-- Name: produtos uq_produto_tenant; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.produtos
    ADD CONSTRAINT uq_produto_tenant UNIQUE (restaurante_id, id);


--
-- Name: sessoes_mesa uq_sessao_tenant; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessoes_mesa
    ADD CONSTRAINT uq_sessao_tenant UNIQUE (restaurante_id, id);


--
-- Name: usuarios usuarios_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_pkey PRIMARY KEY (id);


--
-- Name: idx_enderecos_usuario; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_enderecos_usuario ON public.enderecos USING btree (usuario_id);


--
-- Name: idx_historico_pedido; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_historico_pedido ON public.pedido_status_historico USING btree (pedido_id, criado_em);


--
-- Name: idx_itens_kds; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_itens_kds ON public.pedido_itens USING btree (restaurante_id, status);


--
-- Name: idx_itens_pedido; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_itens_pedido ON public.pedido_itens USING btree (pedido_id);


--
-- Name: idx_membros_usuario; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_membros_usuario ON public.restaurante_membros USING btree (usuario_id);


--
-- Name: idx_pagamentos_pedido; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pagamentos_pedido ON public.pagamentos USING btree (pedido_id);


--
-- Name: idx_pagamentos_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pagamentos_status ON public.pagamentos USING btree (restaurante_id, status);


--
-- Name: idx_pedidos_cliente; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pedidos_cliente ON public.pedidos USING btree (cliente_id, criado_em DESC);


--
-- Name: idx_pedidos_periodo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pedidos_periodo ON public.pedidos USING btree (restaurante_id, criado_em DESC);


--
-- Name: idx_pedidos_restaurante_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pedidos_restaurante_status ON public.pedidos USING btree (restaurante_id, status);


--
-- Name: idx_pedidos_sessao; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pedidos_sessao ON public.pedidos USING btree (sessao_mesa_id);


--
-- Name: idx_produtos_cardapio; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_produtos_cardapio ON public.produtos USING btree (restaurante_id, ativo, disponivel);


--
-- Name: idx_produtos_categoria; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_produtos_categoria ON public.produtos USING btree (categoria_id);


--
-- Name: idx_produtos_restaurante; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_produtos_restaurante ON public.produtos USING btree (restaurante_id);


--
-- Name: idx_sessoes_restaurante; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sessoes_restaurante ON public.sessoes_mesa USING btree (restaurante_id, status);


--
-- Name: uq_endereco_principal; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_endereco_principal ON public.enderecos USING btree (usuario_id) WHERE (principal AND ativo);


--
-- Name: uq_sessao_aberta_por_mesa; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_sessao_aberta_por_mesa ON public.sessoes_mesa USING btree (mesa_id) WHERE (status = 'aberta'::public.sessao_status);


--
-- Name: uq_usuarios_email_lower; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_usuarios_email_lower ON public.usuarios USING btree (lower((email)::text));


--
-- Name: categorias trg_categorias_atualizado_em; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_categorias_atualizado_em BEFORE UPDATE ON public.categorias FOR EACH ROW EXECUTE FUNCTION public.set_atualizado_em();


--
-- Name: pedido_itens trg_itens_atualizado_em; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_itens_atualizado_em BEFORE UPDATE ON public.pedido_itens FOR EACH ROW EXECUTE FUNCTION public.set_atualizado_em();


--
-- Name: mesas trg_mesas_atualizado_em; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_mesas_atualizado_em BEFORE UPDATE ON public.mesas FOR EACH ROW EXECUTE FUNCTION public.set_atualizado_em();


--
-- Name: pagamentos trg_pagamentos_atualizado_em; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_pagamentos_atualizado_em BEFORE UPDATE ON public.pagamentos FOR EACH ROW EXECUTE FUNCTION public.set_atualizado_em();


--
-- Name: pedidos trg_pedido_codigo; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_pedido_codigo BEFORE INSERT ON public.pedidos FOR EACH ROW WHEN ((new.codigo IS NULL)) EXECUTE FUNCTION public.gerar_codigo_pedido();


--
-- Name: pedidos trg_pedido_historico; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_pedido_historico AFTER INSERT OR UPDATE OF status ON public.pedidos FOR EACH ROW EXECUTE FUNCTION public.registrar_status_pedido();


--
-- Name: pedidos trg_pedidos_atualizado_em; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_pedidos_atualizado_em BEFORE UPDATE ON public.pedidos FOR EACH ROW EXECUTE FUNCTION public.set_atualizado_em();


--
-- Name: produtos trg_produtos_atualizado_em; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_produtos_atualizado_em BEFORE UPDATE ON public.produtos FOR EACH ROW EXECUTE FUNCTION public.set_atualizado_em();


--
-- Name: restaurantes trg_restaurantes_atualizado_em; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_restaurantes_atualizado_em BEFORE UPDATE ON public.restaurantes FOR EACH ROW EXECUTE FUNCTION public.set_atualizado_em();


--
-- Name: sessoes_mesa trg_sessao_sincroniza_mesa; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_sessao_sincroniza_mesa AFTER INSERT OR UPDATE OF status ON public.sessoes_mesa FOR EACH ROW EXECUTE FUNCTION public.sincronizar_status_mesa();


--
-- Name: usuarios trg_usuarios_atualizado_em; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_usuarios_atualizado_em BEFORE UPDATE ON public.usuarios FOR EACH ROW EXECUTE FUNCTION public.set_atualizado_em();


--
-- Name: categorias categorias_restaurante_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categorias
    ADD CONSTRAINT categorias_restaurante_id_fkey FOREIGN KEY (restaurante_id) REFERENCES public.restaurantes(id) ON DELETE CASCADE;


--
-- Name: enderecos enderecos_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enderecos
    ADD CONSTRAINT enderecos_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;


--
-- Name: pedido_itens fk_item_pedido; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pedido_itens
    ADD CONSTRAINT fk_item_pedido FOREIGN KEY (restaurante_id, pedido_id) REFERENCES public.pedidos(restaurante_id, id) ON DELETE CASCADE;


--
-- Name: pedido_itens fk_item_produto; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pedido_itens
    ADD CONSTRAINT fk_item_produto FOREIGN KEY (restaurante_id, produto_id) REFERENCES public.produtos(restaurante_id, id) ON DELETE SET NULL;


--
-- Name: pagamentos fk_pagamento_pedido; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pagamentos
    ADD CONSTRAINT fk_pagamento_pedido FOREIGN KEY (restaurante_id, pedido_id) REFERENCES public.pedidos(restaurante_id, id) ON DELETE CASCADE;


--
-- Name: pedidos fk_pedido_sessao; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pedidos
    ADD CONSTRAINT fk_pedido_sessao FOREIGN KEY (restaurante_id, sessao_mesa_id) REFERENCES public.sessoes_mesa(restaurante_id, id) ON DELETE RESTRICT;


--
-- Name: produtos fk_produto_categoria; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.produtos
    ADD CONSTRAINT fk_produto_categoria FOREIGN KEY (restaurante_id, categoria_id) REFERENCES public.categorias(restaurante_id, id) ON DELETE SET NULL;


--
-- Name: sessoes_mesa fk_sessao_mesa; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessoes_mesa
    ADD CONSTRAINT fk_sessao_mesa FOREIGN KEY (restaurante_id, mesa_id) REFERENCES public.mesas(restaurante_id, id) ON DELETE CASCADE;


--
-- Name: mesas mesas_restaurante_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mesas
    ADD CONSTRAINT mesas_restaurante_id_fkey FOREIGN KEY (restaurante_id) REFERENCES public.restaurantes(id) ON DELETE CASCADE;


--
-- Name: pagamentos pagamentos_registrado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pagamentos
    ADD CONSTRAINT pagamentos_registrado_por_fkey FOREIGN KEY (registrado_por) REFERENCES public.usuarios(id);


--
-- Name: pedido_contadores pedido_contadores_restaurante_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pedido_contadores
    ADD CONSTRAINT pedido_contadores_restaurante_id_fkey FOREIGN KEY (restaurante_id) REFERENCES public.restaurantes(id) ON DELETE CASCADE;


--
-- Name: pedido_itens pedido_itens_cancelado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pedido_itens
    ADD CONSTRAINT pedido_itens_cancelado_por_fkey FOREIGN KEY (cancelado_por) REFERENCES public.usuarios(id);


--
-- Name: pedido_status_historico pedido_status_historico_alterado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pedido_status_historico
    ADD CONSTRAINT pedido_status_historico_alterado_por_fkey FOREIGN KEY (alterado_por) REFERENCES public.usuarios(id);


--
-- Name: pedido_status_historico pedido_status_historico_pedido_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pedido_status_historico
    ADD CONSTRAINT pedido_status_historico_pedido_id_fkey FOREIGN KEY (pedido_id) REFERENCES public.pedidos(id) ON DELETE CASCADE;


--
-- Name: pedidos pedidos_cliente_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pedidos
    ADD CONSTRAINT pedidos_cliente_id_fkey FOREIGN KEY (cliente_id) REFERENCES public.usuarios(id);


--
-- Name: pedidos pedidos_criado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pedidos
    ADD CONSTRAINT pedidos_criado_por_fkey FOREIGN KEY (criado_por) REFERENCES public.usuarios(id);


--
-- Name: pedidos pedidos_endereco_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pedidos
    ADD CONSTRAINT pedidos_endereco_id_fkey FOREIGN KEY (endereco_id) REFERENCES public.enderecos(id);


--
-- Name: pedidos pedidos_restaurante_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pedidos
    ADD CONSTRAINT pedidos_restaurante_id_fkey FOREIGN KEY (restaurante_id) REFERENCES public.restaurantes(id) ON DELETE CASCADE;


--
-- Name: produtos produtos_restaurante_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.produtos
    ADD CONSTRAINT produtos_restaurante_id_fkey FOREIGN KEY (restaurante_id) REFERENCES public.restaurantes(id) ON DELETE CASCADE;


--
-- Name: restaurante_membros restaurante_membros_restaurante_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.restaurante_membros
    ADD CONSTRAINT restaurante_membros_restaurante_id_fkey FOREIGN KEY (restaurante_id) REFERENCES public.restaurantes(id) ON DELETE CASCADE;


--
-- Name: restaurante_membros restaurante_membros_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.restaurante_membros
    ADD CONSTRAINT restaurante_membros_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;


--
-- Name: sessoes_mesa sessoes_mesa_aberta_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessoes_mesa
    ADD CONSTRAINT sessoes_mesa_aberta_por_fkey FOREIGN KEY (aberta_por) REFERENCES public.usuarios(id);


--
-- Name: sessoes_mesa sessoes_mesa_fechada_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessoes_mesa
    ADD CONSTRAINT sessoes_mesa_fechada_por_fkey FOREIGN KEY (fechada_por) REFERENCES public.usuarios(id);


--
-- Name: sessoes_mesa sessoes_mesa_restaurante_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessoes_mesa
    ADD CONSTRAINT sessoes_mesa_restaurante_id_fkey FOREIGN KEY (restaurante_id) REFERENCES public.restaurantes(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict dhKdcw6Nv6yOQf8U6PJ5lCnzyuLn7iUfQggrKbLnMv7CFoD5Ay43U8Tpi9HR1A6

