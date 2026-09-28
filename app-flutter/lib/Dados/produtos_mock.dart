import '../models/produto.dart';

final List<Produto> produtosMock = [
  Produto(
    id: '1',
    nome: "Pizza de Bacon",
    descricao: "Molho artesanal, mussarela, bacon crocante e orégano.",
    preco: 45.00,
    imagem:
        "https://images.unsplash.com/photo-1513104890138-7c749659a591?w=600",
    categoria: "Pizzas",
    destaque: true,
  ),
  Produto(
    id: '2',
    nome: "Pizza Calabresa",
    descricao: "Calabresa fatiada, cebola roxa, mussarela e azeitonas.",
    preco: 42.00,
    imagem:
        "https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=600",
    categoria: "Pizzas",
    destaque: true,
  ),
  Produto(
    id: '3',
    nome: "Coca-Cola",
    descricao: "Lata 350ml",
    preco: 6.00,
    imagem:
        "https://images.unsplash.com/photo-1629203851122-3726ecdf080e?w=600",
    categoria: "Bebidas",
    destaque: true,
  ),
  Produto(
    id: '4',
    nome: "X-Bacon Artesanal",
    descricao: "Hambúrguer, queijo, bacon, alface, tomate e molho da casa.",
    preco: 28.00,
    imagem:
        "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=600",
    categoria: "Lanches",
  ),
  Produto(
    id: '5',
    nome: "Espaguete Alho e Óleo",
    descricao: "Massa fresca, alho dourado, azeite e cheiro-verde.",
    preco: 34.90,
    imagem:
        "https://images.unsplash.com/photo-1621996346565-e3dbc646d9a9?w=600",
    categoria: "Macarrão",
  ),
  Produto(
    id: '6',
    nome: "Pudim da Casa",
    descricao: "Pudim cremoso com calda de caramelo.",
    preco: 12.00,
    imagem: "https://images.unsplash.com/photo-1551024506-0bccd828d307?w=600",
    categoria: "Sobremesas",
  ),
];
