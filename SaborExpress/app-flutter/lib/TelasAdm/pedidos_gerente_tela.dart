import 'package:flutter/material.dart';

class PedidosGerenteTela extends StatelessWidget {
  const PedidosGerenteTela({super.key});

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
                      "Pedidos",

                      textAlign: TextAlign.center,

                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const Icon(Icons.receipt_long, color: Colors.white, size: 30),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),

                children: [
                  const Align(
                    alignment: Alignment.centerLeft,

                    child: Text(
                      "Pedidos em andamento",

                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  _pedidoCard(
                    context,

                    mesa: "Mesa 01",
                    itens: "4 itens",
                    total: "R\$ 98,50",
                    status: "Em preparo",
                    cor: Colors.orange,

                    finalizado: false,

                    produtos: [
                      "Pizza de Bacon - R\$45,00",
                      "Pizza de Brócolis com Bacon - R\$45,00",
                      "Coca-Cola - R\$6,00",
                      "Sonho de Valsa - R\$2,50",
                    ],
                  ),

                  const SizedBox(height: 15),

                  _pedidoCard(
                    context,

                    mesa: "Mesa 03",
                    itens: "2 itens",
                    total: "R\$ 64,00",
                    status: "Aguardando",
                    cor: Colors.red,

                    finalizado: false,

                    produtos: [
                      "Pizza Calabresa - R\$58,00",
                      "Refrigerante - R\$6,00",
                    ],
                  ),

                  const SizedBox(height: 30),

                  const Align(
                    alignment: Alignment.centerLeft,

                    child: Text(
                      "Pedidos finalizados",

                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  _pedidoCard(
                    context,

                    mesa: "Mesa 02",
                    itens: "3 itens",
                    total: "R\$ 80,00",
                    status: "Finalizado",
                    cor: Colors.grey,

                    finalizado: true,

                    produtos: [
                      "Pizza Bacon - R\$45,00",
                      "Coca-Cola - R\$6,00",
                      "Sobremesa - R\$29,00",
                    ],
                  ),

                  const SizedBox(height: 15),

                  _pedidoCard(
                    context,

                    mesa: "Mesa 06",
                    itens: "5 itens",
                    total: "R\$ 150,50",
                    status: "Finalizado",
                    cor: Colors.grey,

                    finalizado: true,

                    produtos: [
                      "Pizza Especial - R\$90,00",
                      "Refrigerantes - R\$20,00",
                      "Sobremesas - R\$40,50",
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pedidoCard(
    BuildContext context, {
    required String mesa,
    required String itens,
    required String total,
    required String status,
    required Color cor,
    required bool finalizado,
    required List<String> produtos,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        // FINALIZADO FICA CINZA
        color: finalizado ? Colors.grey.shade200 : Colors.grey.shade100,

        borderRadius: BorderRadius.circular(20),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .08),

            blurRadius: 8,

            offset: const Offset(0, 3),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),

                decoration: BoxDecoration(
                  color: finalizado
                      ? Colors.grey.shade300
                      : Colors.green.shade100,

                  borderRadius: BorderRadius.circular(15),
                ),

                child: Icon(
                  Icons.table_restaurant,

                  color: finalizado ? Colors.grey : Colors.green,
                ),
              ),

              const SizedBox(width: 15),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      mesa,

                      style: const TextStyle(
                        fontSize: 20,

                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    Text(itens, style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),

                decoration: BoxDecoration(
                  color: cor.withValues(alpha: .15),

                  borderRadius: BorderRadius.circular(20),
                ),

                child: Text(
                  status,

                  style: TextStyle(color: cor, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),

          const Divider(height: 30),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,

            children: [
              const Text(
                "Total do pedido",

                style: TextStyle(color: Colors.grey),
              ),

              Text(
                total,

                style: TextStyle(
                  color: finalizado ? Colors.grey : Colors.green,

                  fontSize: 22,

                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          SizedBox(
            width: double.infinity,

            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: finalizado ? Colors.grey : Colors.green,

                side: BorderSide(
                  color: finalizado ? Colors.grey : Colors.green,
                ),

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),

              icon: const Icon(Icons.visibility),

              label: const Text("Ver detalhes"),

              onPressed: () {
                showModalBottomSheet(
                  context: context,

                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(30),
                    ),
                  ),

                  builder: (context) {
                    return Padding(
                      padding: const EdgeInsets.all(25),

                      child: Column(
                        mainAxisSize: MainAxisSize.min,

                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          Text(
                            mesa,

                            style: const TextStyle(
                              fontSize: 24,

                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 15),

                          const Text(
                            "Produtos",

                            style: TextStyle(
                              fontSize: 18,

                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 10),

                          ...produtos.map(
                            (produto) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),

                              child: Text(
                                produto,

                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ),

                          const Divider(),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,

                            children: [
                              const Text(
                                "Total",

                                style: TextStyle(
                                  fontWeight: FontWeight.bold,

                                  fontSize: 20,
                                ),
                              ),

                              Text(
                                total,

                                style: const TextStyle(
                                  color: Colors.green,

                                  fontSize: 22,

                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
