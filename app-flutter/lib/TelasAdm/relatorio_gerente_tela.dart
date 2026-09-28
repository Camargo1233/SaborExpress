import 'package:flutter/material.dart';

class RelatorioGerenteTela extends StatefulWidget {
  const RelatorioGerenteTela({super.key});

  @override
  State<RelatorioGerenteTela> createState() => _RelatorioGerenteTelaState();
}

class _RelatorioGerenteTelaState extends State<RelatorioGerenteTela> {
  int filtroSelecionado = 0;

  final filtros = ["Hoje", "Semana", "Mês"];

  // Futuramente esses dados virão do banco/API

  double faturamento = 1250.00;

  int quantidadePedidos = 32;

  String produtoMaisVendido = "Pizza de Bacon";

  final produtos = [
    {"nome": "Pizza de Bacon", "pedidos": 15},

    {"nome": "Pizza Margherita", "pedidos": 12},

    {"nome": "Frango com Catupiry", "pedidos": 9},

    {"nome": "Espaguete ao Alho e Óleo", "pedidos": 7},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      body: SafeArea(
        child: Column(
          children: [
            // CABEÇALHO
            Container(
              padding: const EdgeInsets.all(20),

              decoration: const BoxDecoration(
                color: Colors.green,

                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),

                  bottomRight: Radius.circular(30),
                ),
              ),

              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.white,
                    ),

                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),

                  const Expanded(
                    child: Text(
                      "Relatórios",

                      textAlign: TextAlign.center,

                      style: TextStyle(
                        color: Colors.white,

                        fontSize: 28,

                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const Icon(Icons.bar_chart, color: Colors.white, size: 32),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // FILTROS
            SizedBox(
              height: 45,

              child: ListView.builder(
                scrollDirection: Axis.horizontal,

                itemCount: filtros.length,

                itemBuilder: (context, index) {
                  bool selecionado = filtroSelecionado == index;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        filtroSelecionado = index;
                      });
                    },

                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),

                      padding: const EdgeInsets.symmetric(
                        horizontal: 25,
                        vertical: 10,
                      ),

                      decoration: BoxDecoration(
                        color: selecionado
                            ? Colors.green
                            : Colors.grey.shade200,

                        borderRadius: BorderRadius.circular(25),
                      ),

                      child: Text(
                        filtros[index],

                        style: TextStyle(
                          color: selecionado ? Colors.white : Colors.black,

                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),

                child: Column(
                  children: [
                    Row(
                      children: [
                        _cardIndicador(
                          Icons.attach_money,

                          "Faturamento",

                          "R\$ ${faturamento.toStringAsFixed(2)}",
                        ),

                        const SizedBox(width: 15),

                        _cardIndicador(
                          Icons.receipt_long,

                          "Pedidos",

                          quantidadePedidos.toString(),
                        ),
                      ],
                    ),

                    const SizedBox(height: 15),

                    _cardProdutoMaisVendido(),

                    const SizedBox(height: 30),

                    Align(
                      alignment: Alignment.centerLeft,

                      child: Text(
                        "Produtos mais vendidos",

                        style: const TextStyle(
                          fontSize: 22,

                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const SizedBox(height: 15),

                    ListView.builder(
                      shrinkWrap: true,

                      physics: const NeverScrollableScrollPhysics(),

                      itemCount: produtos.length,

                      itemBuilder: (context, index) {
                        final produto = produtos[index];

                        return Card(
                          elevation: 3,

                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),

                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.green.shade100,

                              child: const Icon(
                                Icons.local_pizza,

                                color: Colors.green,
                              ),
                            ),

                            title: Text(
                              produto["nome"].toString(),

                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            trailing: Text(
                              "${produto["pedidos"]} pedidos",

                              style: const TextStyle(
                                color: Colors.green,

                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardIndicador(IconData icon, String titulo, String valor) {
    return Expanded(
      child: Container(
        height: 120,

        decoration: BoxDecoration(
          color: Colors.green.shade50,

          borderRadius: BorderRadius.circular(20),
        ),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            Icon(icon, color: Colors.green, size: 35),

            const SizedBox(height: 8),

            Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),

            Text(
              valor,

              style: const TextStyle(
                color: Colors.green,

                fontSize: 18,

                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardProdutoMaisVendido() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: Colors.green,

        borderRadius: BorderRadius.circular(20),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          const Text("Mais vendido", style: TextStyle(color: Colors.white70)),

          const SizedBox(height: 10),

          Text(
            produtoMaisVendido,

            style: const TextStyle(
              color: Colors.white,

              fontSize: 24,

              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
