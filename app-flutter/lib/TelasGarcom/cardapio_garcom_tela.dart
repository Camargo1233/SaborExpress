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

  final Map<String, Map<String, dynamic>> produtosSelecionados = {};

  final List<String> categorias = [
    "Mais Pedidos",
    "Pizzas",
    "Lanches",
    "Massas",
    "Bebidas",
    "Sobremesas",
  ];

  int get quantidadeSelecionada {
    int total = 0;

    for (final item in produtosSelecionados.values) {
      total += (item["quantidade"] as num?)?.toInt() ?? 0;
    }

    return total;
  }

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

  @override
  void dispose() {
    pesquisaController.dispose();
    super.dispose();
  }

  // ============================================================
  // CARREGAR PRODUTOS
  // ============================================================

  Future<List<Produto>> carregarProdutos() async {
    return repository.listarProdutos();
  }

  Future<void> atualizar() async {
    final novoFuture = carregarProdutos();

    setState(() {
      produtosFuture = novoFuture;
    });

    try {
      await novoFuture;
    } catch (_) {
      // O FutureBuilder exibirá o erro.
    }
  }

  // ============================================================
  // FILTRAR PRODUTOS
  // ============================================================

  List<Produto> filtrarProdutos(List<Produto> produtos) {
    var filtrados = produtos.where((produto) {
      return produto.ativo && produto.disponivel;
    }).toList();

    if (categoriaSelecionada == "Mais Pedidos") {
      final destaques = filtrados.where((produto) {
        return produto.destaque;
      }).toList();

      if (destaques.isNotEmpty) {
        filtrados = destaques;
      }
    } else {
      filtrados = filtrados.where((produto) {
        return produto.categoria.toLowerCase() ==
            categoriaSelecionada.toLowerCase();
      }).toList();
    }

    final pesquisa = pesquisaController.text.trim().toLowerCase();

    if (pesquisa.isNotEmpty) {
      filtrados = filtrados.where((produto) {
        return produto.nome.toLowerCase().contains(pesquisa) ||
            produto.descricao.toLowerCase().contains(pesquisa);
      }).toList();
    }

    return filtrados;
  }

  // ============================================================
  // QUANTIDADE SELECIONADA DO PRODUTO
  // ============================================================

  int quantidadeProduto(Produto produto) {
    final item = produtosSelecionados[produto.id.toString()];

    if (item == null) {
      return 0;
    }

    return (item["quantidade"] as num?)?.toInt() ?? 0;
  }

  // ============================================================
  // ADICIONAR PRODUTO
  // ============================================================

  void selecionarProduto(Produto produto) {
    debugPrint(">>> CLIQUE + NO CARDAPIO: ${produto.nome}");

    final id = produto.id.toString();

    setState(() {
      if (produtosSelecionados.containsKey(id)) {
        final quantidadeAtual =
            (produtosSelecionados[id]!["quantidade"] as num?)?.toInt() ?? 1;

        produtosSelecionados[id]!["quantidade"] = quantidadeAtual + 1;
      } else {
        produtosSelecionados[id] = {
          "produtoId": produto.id,
          "nome": produto.nome,
          "descricao": produto.descricao,
          "preco": produto.preco,
          "imagem": produto.imagem,
          "categoria": produto.categoria,
          "quantidade": 1,
        };
      }
    });

    debugPrint(
      ">>> PRODUTO ADICIONADO LOCALMENTE. "
      "TOTAL SELECIONADO: $quantidadeSelecionada",
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 600),
          backgroundColor: Colors.green,
          content: Text("${produto.nome} adicionado."),
        ),
      );
  }

  // ============================================================
  // DIMINUIR PRODUTO
  // ============================================================

  void diminuirProduto(Produto produto) {
    final id = produto.id.toString();

    final item = produtosSelecionados[id];

    if (item == null) {
      return;
    }

    final quantidade = (item["quantidade"] as num?)?.toInt() ?? 1;

    setState(() {
      if (quantidade > 1) {
        produtosSelecionados[id]!["quantidade"] = quantidade - 1;
      } else {
        produtosSelecionados.remove(id);
      }
    });
  }

  // ============================================================
  // RETORNAR AO PEDIDO
  // ============================================================

  void voltarParaPedido() {
    Navigator.pop(context, produtosSelecionados.values.toList());
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          voltarParaPedido();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              // ==================================================
              // CABEÇALHO
              // ==================================================
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new),
                      onPressed: voltarParaPedido,
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          const Text(
                            "Cardápio",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (quantidadeSelecionada > 0)
                            Text(
                              quantidadeSelecionada == 1
                                  ? "1 item selecionado"
                                  : "$quantidadeSelecionada itens selecionados",
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              // ==================================================
              // PESQUISA
              // ==================================================
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: TextField(
                  controller: pesquisaController,
                  decoration: InputDecoration(
                    hintText: "Pesquisar produto",
                    prefixIcon: const Icon(Icons.search, color: Colors.green),
                    suffixIcon: pesquisaController.text.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              pesquisaController.clear();
                            },
                            icon: const Icon(Icons.close),
                          )
                        : null,
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

              // ==================================================
              // CATEGORIAS
              // ==================================================
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

              // ==================================================
              // PRODUTOS
              // ==================================================
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
                      return RefreshIndicator(
                        onRefresh: atualizar,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 150),
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 45,
                            ),
                            const SizedBox(height: 10),
                            const Center(
                              child: Text(
                                "Não foi possível carregar o cardápio.",
                              ),
                            ),
                            const SizedBox(height: 15),
                            Center(
                              child: ElevatedButton.icon(
                                onPressed: atualizar,
                                icon: const Icon(Icons.refresh),
                                label: const Text("Tentar novamente"),
                              ),
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

                          final quantidade = quantidadeProduto(produto);

                          return Card(
                            elevation: 3,
                            margin: const EdgeInsets.only(bottom: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  // ============================
                                  // IMAGEM
                                  // ============================
                                  ClipRRect(
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

                                  const SizedBox(width: 12),

                                  // ============================
                                  // DADOS DO PRODUTO
                                  // ============================
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          produto.nome,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.green,
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          produto.descricao,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.grey.shade700,
                                          ),
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
                                  ),

                                  const SizedBox(width: 8),

                                  // ============================
                                  // ADICIONAR / QUANTIDADE
                                  // ============================
                                  if (quantidade == 0)
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size(45, 45),
                                        padding: const EdgeInsets.all(8),
                                        shape: const CircleBorder(),
                                      ),
                                      onPressed: () {
                                        selecionarProduto(produto);
                                      },
                                      child: const Icon(Icons.add),
                                    )
                                  else
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(25),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            visualDensity:
                                                VisualDensity.compact,
                                            onPressed: () {
                                              diminuirProduto(produto);
                                            },
                                            icon: const Icon(
                                              Icons.remove_circle,
                                              color: Colors.red,
                                            ),
                                          ),
                                          Text(
                                            quantidade.toString(),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          IconButton(
                                            visualDensity:
                                                VisualDensity.compact,
                                            onPressed: () {
                                              selecionarProduto(produto);
                                            },
                                            icon: const Icon(
                                              Icons.add_circle,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),

              // ==================================================
              // BOTÃO INFERIOR
              // ==================================================
              if (quantidadeSelecionada > 0)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .08),
                        blurRadius: 8,
                        offset: const Offset(0, -3),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: voltarParaPedido,
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(
                      quantidadeSelecionada == 1
                          ? "Adicionar 1 item ao pedido"
                          : "Adicionar $quantidadeSelecionada itens ao pedido",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
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
