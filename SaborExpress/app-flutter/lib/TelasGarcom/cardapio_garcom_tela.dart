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
    "Macarrão",
    "Bebidas",
  ];

  @override
  void initState() {
    super.initState();

    produtosFuture = carregarProdutos();
  }

  Future<List<Produto>> carregarProdutos() async {
    try {
      final produtos = await repository.listarProdutos();

      return produtos;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      body: SafeArea(
        child: Column(
          children: [
            // TOPO
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

            const SizedBox(height: 15),

            // CATEGORIAS
            SizedBox(
              height: 45,

              child: ListView.builder(
                scrollDirection: Axis.horizontal,

                itemCount: categorias.length,

                itemBuilder: (context, index) {
                  final categoria = categorias[index];

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
                            color: categoriaSelecionada == categoria
                                ? Colors.green
                                : Colors.transparent,

                            width: 3,
                          ),
                        ),
                      ),

                      child: Text(
                        categoria,

                        style: TextStyle(
                          color: categoriaSelecionada == categoria
                              ? Colors.green
                              : Colors.grey,

                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const Divider(height: 1),

            Expanded(
              child: FutureBuilder<List<Produto>>(
                future: produtosFuture,

                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final produtos = snapshot.data ?? [];

                  if (produtos.isEmpty) {
                    return const Center(
                      child: Text("Nenhum produto encontrado"),
                    );
                  }

                  List<Produto> filtrados = produtos;

                  // FILTRO DE PESQUISA

                  if (pesquisaController.text.isNotEmpty) {
                    filtrados = produtos.where((produto) {
                      return produto.nome.toLowerCase().contains(
                        pesquisaController.text.toLowerCase(),
                      );
                    }).toList();
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

                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(12),

                              child: Image.network(
                                produto.imagem,

                                width: 70,

                                height: 70,

                                fit: BoxFit.cover,

                                errorBuilder: (_, __, ___) {
                                  return Container(
                                    width: 70,

                                    height: 70,

                                    color: Colors.grey.shade300,

                                    child: const Icon(Icons.fastfood),
                                  );
                                },
                              ),
                            ),

                            title: Text(
                              produto.nome,

                              style: const TextStyle(
                                color: Colors.green,

                                fontSize: 17,

                                fontWeight: FontWeight.bold,
                              ),
                            ),

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

                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,

                                foregroundColor: Colors.white,

                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),

                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      "${produto.nome} adicionado ao pedido",
                                    ),

                                    duration: const Duration(seconds: 1),
                                  ),
                                );
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
}
