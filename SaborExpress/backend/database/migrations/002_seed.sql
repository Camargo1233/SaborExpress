-- =====================================================================
-- SaborExpress - Dados de demonstracao
-- Executar depois de 001_schema.sql
-- Senha de todos os usuarios de teste: senha123
-- Hash gerado com pgcrypto (bcrypt $2a$), compativel com bcryptjs.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Restaurantes (dois, para provar o isolamento multi-tenant)
-- ---------------------------------------------------------------------
insert into restaurantes (nome, slug, telefone, taxa_servico_percentual,
                          taxa_entrega_padrao, pedido_minimo_delivery,
                          frete_gratis_acima_de, raio_entrega_km)
values
  ('Sabor Express',  'sabor-express',  '(11) 4000-1000', 10.00, 10.00, 25.00, 120.00, 8.0),
  ('Cantina Bella',  'cantina-bella',  '(11) 4000-2000', 12.00,  8.00, 30.00, 150.00, 6.0)
on conflict (slug) do nothing;

-- ---------------------------------------------------------------------
-- Usuarios
-- ---------------------------------------------------------------------
insert into usuarios (nome, email, telefone, senha_hash)
values
  ('Davi Gerente',   'gerente@saborexpress.com', '(11) 99999-0001', crypt('senha123', gen_salt('bf'))),
  ('Ana Garcom',     'garcom@saborexpress.com',  '(11) 99999-0002', crypt('senha123', gen_salt('bf'))),
  ('Bruno Cozinha',  'cozinha@saborexpress.com', '(11) 99999-0003', crypt('senha123', gen_salt('bf'))),
  ('Carla Cliente',  'cliente@email.com',        '(11) 98888-0001', crypt('senha123', gen_salt('bf'))),
  ('Marco Bella',    'gerente@cantinabella.com', '(11) 97777-0001', crypt('senha123', gen_salt('bf')))
on conflict do nothing;

-- ---------------------------------------------------------------------
-- Vinculos funcionario <-> restaurante
-- ---------------------------------------------------------------------
insert into restaurante_membros (restaurante_id, usuario_id, perfil)
select r.id, u.id, v.perfil::perfil_acesso
from (values
  ('sabor-express', 'gerente@saborexpress.com', 'gerente'),
  ('sabor-express', 'garcom@saborexpress.com',  'garcom'),
  ('sabor-express', 'cozinha@saborexpress.com', 'cozinha'),
  ('cantina-bella', 'gerente@cantinabella.com', 'gerente')
) as v(slug, email, perfil)
join restaurantes r on r.slug = v.slug
join usuarios u on lower(u.email) = v.email
on conflict (restaurante_id, usuario_id) do nothing;

-- ---------------------------------------------------------------------
-- Endereco do cliente
-- ---------------------------------------------------------------------
insert into enderecos (usuario_id, apelido, cep, logradouro, numero, bairro, cidade, estado, principal)
select u.id, 'Casa', '01000-000', 'Rua Exemplo', '123', 'Centro', 'Sao Paulo', 'SP', true
from usuarios u
where lower(u.email) = 'cliente@email.com'
  and not exists (select 1 from enderecos e where e.usuario_id = u.id);

-- ---------------------------------------------------------------------
-- Categorias (Sabor Express)
-- ---------------------------------------------------------------------
insert into categorias (restaurante_id, nome, descricao, ordem)
select r.id, c.nome, c.descricao, c.ordem
from restaurantes r
join (values
  ('Pizzas',     'Pizzas tradicionais e especiais', 1),
  ('Lanches',    'Lanches artesanais',              2),
  ('Massas',     'Massas e pratos quentes',         3),
  ('Bebidas',    'Refrigerantes, sucos e agua',     4),
  ('Sobremesas', 'Doces e sobremesas da casa',      5)
) as c(nome, descricao, ordem) on true
where r.slug = 'sabor-express'
on conflict (restaurante_id, nome) do nothing;

-- Categorias (Cantina Bella)
insert into categorias (restaurante_id, nome, descricao, ordem)
select r.id, c.nome, c.descricao, c.ordem
from restaurantes r
join (values
  ('Massas',  'Massas frescas artesanais', 1),
  ('Bebidas', 'Vinhos e refrigerantes',    2)
) as c(nome, descricao, ordem) on true
where r.slug = 'cantina-bella'
on conflict (restaurante_id, nome) do nothing;

-- ---------------------------------------------------------------------
-- Produtos (Sabor Express)
-- ---------------------------------------------------------------------
insert into produtos (restaurante_id, categoria_id, nome, descricao, preco, imagem_url, destaque, tempo_preparo_min)
select r.id, c.id, p.nome, p.descricao, p.preco, p.imagem_url, p.destaque, p.tempo
from restaurantes r
join (values
  ('Pizzas',     'Pizza de Bacon',        'Molho artesanal, mussarela, bacon crocante e oregano.', 45.00, 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=600', true,  25),
  ('Pizzas',     'Pizza Calabresa',       'Calabresa fatiada, cebola roxa, mussarela e azeitonas.', 42.00, 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=600', true,  25),
  ('Lanches',    'X-Bacon Artesanal',     'Hamburguer, queijo, bacon, alface, tomate e molho da casa.', 28.00, 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=600', false, 15),
  ('Massas',     'Espaguete Alho e Oleo', 'Massa fresca, alho dourado, azeite e cheiro-verde.', 34.90, 'https://images.unsplash.com/photo-1621996346565-e3dbc646d9a9?w=600', false, 18),
  ('Bebidas',    'Coca-Cola Lata 350ml',  'Lata 350ml gelada.', 6.00, 'https://images.unsplash.com/photo-1629203851122-3726ecdf080e?w=600', true, 1),
  ('Bebidas',    'Suco de Laranja 500ml', 'Suco natural feito na hora.', 9.50, null, false, 5),
  ('Sobremesas', 'Pudim da Casa',         'Pudim cremoso com calda de caramelo.', 12.00, 'https://images.unsplash.com/photo-1551024506-0bccd828d307?w=600', false, 5)
) as p(categoria, nome, descricao, preco, imagem_url, destaque, tempo) on true
join categorias c on c.restaurante_id = r.id and c.nome = p.categoria
where r.slug = 'sabor-express'
on conflict (restaurante_id, nome) do nothing;

-- Produtos (Cantina Bella)
insert into produtos (restaurante_id, categoria_id, nome, descricao, preco, destaque, tempo_preparo_min)
select r.id, c.id, p.nome, p.descricao, p.preco, p.destaque, p.tempo
from restaurantes r
join (values
  ('Massas',  'Nhoque ao Sugo',  'Nhoque artesanal com molho de tomate italiano.', 39.00, true, 20),
  ('Bebidas', 'Agua com Gas',    'Garrafa 500ml.', 7.00, false, 1)
) as p(categoria, nome, descricao, preco, destaque, tempo) on true
join categorias c on c.restaurante_id = r.id and c.nome = p.categoria
where r.slug = 'cantina-bella'
on conflict (restaurante_id, nome) do nothing;

-- ---------------------------------------------------------------------
-- Mesas
-- ---------------------------------------------------------------------
insert into mesas (restaurante_id, numero, capacidade)
select r.id, m.numero, m.capacidade
from restaurantes r
join (values
  (1, 4), (2, 4), (3, 4), (4, 6), (5, 2), (6, 6), (7, 2), (8, 4), (9, 4), (10, 8)
) as m(numero, capacidade) on true
where r.slug = 'sabor-express'
on conflict (restaurante_id, numero) do nothing;

insert into mesas (restaurante_id, numero, capacidade)
select r.id, m.numero, m.capacidade
from restaurantes r
join (values (1, 2), (2, 4), (3, 4)) as m(numero, capacidade) on true
where r.slug = 'cantina-bella'
on conflict (restaurante_id, numero) do nothing;
