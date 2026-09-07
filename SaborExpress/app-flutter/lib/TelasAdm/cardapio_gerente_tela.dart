import 'package:flutter/material.dart';

import 'produto_gerente_tela.dart';
import 'adicionar_gerente_tela.dart';

class CardapioGerenteTela extends StatefulWidget {
  const CardapioGerenteTela({super.key});

  @override
  State<CardapioGerenteTela> createState() => _CardapioGerenteTelaState();
}

class _CardapioGerenteTelaState extends State<CardapioGerenteTela> {
  int categoriaSelecionada = 0;

  final categorias = [
    "Pizzas",
    "Lanches",
    "Macarrão",
    "Omeletes",
    "Bebidas",
    "Sobremesas",
  ];

  final List<Map<String, dynamic>> produtos = [
    {
      "categoria": "Pizzas",
      "nome": "Marguerita",
      "descricao": "Molho, tomate, mussarela e manjericão",
      "preco": 45.0,
    },
    {
      "categoria": "Pizzas",
      "nome": "Bacon com Milho",
      "descricao": "Bacon, milho e mussarela",
      "preco": 48.0,
    },
    {
      "categoria": "Pizzas",
      "nome": "Brócolis com Bacon",
      "descricao": "Brócolis, bacon e queijo",
      "preco": 50.0,
    },
    {
      "categoria": "Lanches",
      "nome": "X-Bacon",
      "descricao": "Hambúrguer artesanal",
      "preco": 28.0,
    },
    {
      "categoria": "Bebidas",
      "nome": "Coca-Cola",
      "descricao": "Lata 350ml",
      "preco": 6.0,
    },
  ];

  void abrirAdicionar() async {
    final produto = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdicionarGerenteTela()),
    );

    if (produto != null) {
      setState(() {
        produtos.add(produto);
      });
    }
  }

  void abrirEditar(Map<String, dynamic> produto, int index) async {
    final atualizado = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProdutoGerenteTela(produto: produto)),
    );

    if (atualizado != null) {
      setState(() {
        produtos[index] = atualizado;
      });
    }
  }

  void removerProduto(int index) {
    setState(() {
      produtos.removeAt(index);
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Produto removido")));
  }

  @override
  Widget build(BuildContext context) {
    final produtosCategoria = produtos.where((produto) {
      return produto["categoria"] == categorias[categoriaSelecionada];
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,

      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: Colors.green),
              accountName: const Text("Gerente"),
              accountEmail: const Text("admin@sabor.com"),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, color: Colors.green),
              ),
            ),

            ListTile(
              leading: const Icon(Icons.add_circle, color: Colors.green),
              title: const Text("Adicionar produto"),
              onTap: () {
                Navigator.pop(context);
                abrirAdicionar();
              },
            ),

            ListTile(
              leading: const Icon(Icons.receipt_long, color: Colors.green),
              title: const Text("Pedidos"),
              onTap: () {
                Navigator.pushNamed(context, "/adm/pedidos");
              },
            ),
          ],
        ),
      ),

      appBar: AppBar(
        backgroundColor: Colors.green,
        centerTitle: true,

        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),

        title: const Text(
          "Cardápio",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),

        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: Colors.white),
            tooltip: "Adicionar produto",
            onPressed: abrirAdicionar,
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.green,

        onPressed: abrirAdicionar,

        icon: const Icon(Icons.add),

        label: const Text("Adicionar Produto"),
      ),

      body: Column(
        children: [
          const SizedBox(height: 10),

          SizedBox(
            height: 45,

            child: ListView.builder(
              scrollDirection: Axis.horizontal,

              itemCount: categorias.length,

              itemBuilder: (context, index) {
                final selecionado = categoriaSelecionada == index;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      categoriaSelecionada = index;
                    });
                  },

                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),

                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),

                    decoration: BoxDecoration(
                      color: selecionado ? Colors.green : Colors.grey.shade200,

                      borderRadius: BorderRadius.circular(25),
                    ),

                    child: Center(
                      child: Text(
                        categorias[index],

                        style: TextStyle(
                          color: selecionado ? Colors.white : Colors.black,

                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const Divider(),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: produtosCategoria.length,
              itemBuilder: (context, index) {
                final produto = produtosCategoria[index];

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),

                    leading: CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.green.shade100,
                      child: const Icon(Icons.fastfood, color: Colors.green),
                    ),

                    title: Text(
                      produto["nome"],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.green,
                      ),
                    ),

                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(produto["descricao"]),
                          const SizedBox(height: 6),
                          Text(
                            "R\$ ${produto["preco"].toStringAsFixed(2)}",
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),

                    trailing: PopupMenuButton<String>(
                      onSelected: (valor) {
                        final indexOriginal = produtos.indexOf(produto);

                        if (valor == "editar") {
                          abrirEditar(produto, indexOriginal);
                        }

                        if (valor == "remover") {
                          removerProduto(indexOriginal);
                        }
                      },

                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: "editar",
                          child: Row(
                            children: [
                              Icon(Icons.edit, color: Colors.green),
                              SizedBox(width: 10),
                              Text("Editar"),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: "remover",
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 10),
                              Text("Remover"),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
