import 'package:flutter/material.dart';

import '../Repositories/produto_repository.dart';
import '../models/produto.dart';

class CardapioGarcomTela extends StatefulWidget {
  const CardapioGarcomTela({super.key});

  @override
  State<CardapioGarcomTela> createState() => _CardapioGarcomTelaState();
}

class _CardapioGarcomTelaState extends State<CardapioGarcomTela> {
  final ProdutoRepository repository = ProdutoRepository();

  late Future<List<Produto>> produtosFuture;

  final TextEditingController pesquisaController = TextEditingController();

  String categoriaSelecionada = "Mais Pedidos";

  final List<String> categorias = [
    "Mais Pedidos",
    "Pizzas",
    "Lanches",
    "Massas",
    "Bebidas",
    "Sobremesas",
  ];

  @override
  void initState() {
    super.initState();

    produtosFuture = carregarProdutos();

    pesquisaController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<List<Produto>> carregarProdutos() async {
    try {
      return await repository.listarProdutos();
    } catch (e) {
      return [];
    }
  }

  Future<void> atualizar() async {
    setState(() {
      produtosFuture = carregarProdutos();
    });
  }

  @override
  void dispose() {
    pesquisaController.dispose();
    super.dispose();
  }

  List<Produto> filtrarProdutos(List<Produto> produtos) {
    var filtrados = produtos.where((produto) {
      return produto.ativo && produto.disponivel;
    }).toList();

    // ============================================================
    // FILTRO POR CATEGORIA
    // ============================================================

    if (categoriaSelecionada == "Mais Pedidos") {
      final destaques = filtrados.where((produto) {
        return produto.destaque;
      }).toList();

      // Se houver produtos em destaque, mostra somente eles.
      // Caso contrário, mostra todos.
      if (destaques.isNotEmpty) {
        filtrados = destaques;
      }
    } else {
      filtrados = filtrados.where((produto) {
        return produto.categoria.toLowerCase() ==
            categoriaSelecionada.toLowerCase();
      }).toList();
    }

    // ============================================================
    // PESQUISA
    // ============================================================

    final pesquisa = pesquisaController.text.trim().toLowerCase();

    if (pesquisa.isNotEmpty) {
      filtrados = filtrados.where((produto) {
        return produto.nome.toLowerCase().contains(pesquisa) ||
            produto.descricao.toLowerCase().contains(pesquisa);
      }).toList();
    }

    return filtrados;
  }

  void selecionarProduto(Produto produto) {
    Navigator.pop(context, {
      "produtoId": produto.id,
      "nome": produto.nome,
      "descricao": produto.descricao,
      "preco": produto.preco,
      "imagem": produto.imagem,
      "categoria": produto.categoria,
      "quantidade": 1,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      body: SafeArea(
        child: Column(
          children: [
            // =====================================================
            // TOPO
            // =====================================================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),

                  const Expanded(
                    child: Text(
                      "Cardápio",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(width: 45),
                ],
              ),
            ),

            // =====================================================
            // PESQUISA
            // =====================================================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: TextField(
                controller: pesquisaController,
                decoration: InputDecoration(
                  hintText: "Pesquisar produto",
                  prefixIcon: const Icon(Icons.search, color: Colors.green),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 15),

            // =====================================================
            // CATEGORIAS
            // =====================================================
            SizedBox(
              height: 45,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: categorias.length,
                itemBuilder: (context, index) {
                  final categoria = categorias[index];

                  final selecionada = categoriaSelecionada == categoria;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        categoriaSelecionada = categoria;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: selecionada
                                ? Colors.green
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Text(
                        categoria,
                        style: TextStyle(
                          color: selecionada ? Colors.green : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const Divider(height: 1),

            // =====================================================
            // PRODUTOS
            // =====================================================
            Expanded(
              child: FutureBuilder<List<Produto>>(
                future: produtosFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.green),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 45,
                          ),
                          const SizedBox(height: 10),
                          const Text("Não foi possível carregar o cardápio."),
                          const SizedBox(height: 15),
                          ElevatedButton(
                            onPressed: atualizar,
                            child: const Text("Tentar novamente"),
                          ),
                        ],
                      ),
                    );
                  }

                  final produtos = snapshot.data ?? [];

                  final filtrados = filtrarProdutos(produtos);

                  if (filtrados.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: atualizar,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 180),
                          Center(child: Text("Nenhum produto encontrado")),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: atualizar,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(15),
                      itemCount: filtrados.length,
                      itemBuilder: (context, index) {
                        final produto = filtrados[index];

                        return Card(
                          elevation: 3,
                          margin: const EdgeInsets.only(bottom: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(12),

                            // =====================================
                            // IMAGEM
                            // =====================================
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: produto.imagem.isNotEmpty
                                  ? Image.network(
                                      produto.imagem,
                                      width: 70,
                                      height: 70,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) {
                                        return _imagemPadrao();
                                      },
                                    )
                                  : _imagemPadrao(),
                            ),

                            // =====================================
                            // NOME
                            // =====================================
                            title: Text(
                              produto.nome,
                              style: const TextStyle(
                                color: Colors.green,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            // =====================================
                            // DESCRIÇÃO / PREÇO
                            // =====================================
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 5),

                                Text(
                                  produto.descricao,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),

                                const SizedBox(height: 5),

                                Text(
                                  "R\$ ${produto.preco.toStringAsFixed(2)}",
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),

                            // =====================================
                            // ADICIONAR
                            // =====================================
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              onPressed: () {
                                selecionarProduto(produto);
                              },
                              child: const Icon(Icons.add),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagemPadrao() {
    return Container(
      width: 70,
      height: 70,
      color: Colors.grey.shade300,
      child: const Icon(Icons.fastfood, color: Colors.grey),
    );
  }
}
