import 'package:flutter/material.dart';

class PedidoMesaGarcomTela extends StatefulWidget {
  const PedidoMesaGarcomTela({super.key});

  @override
  State<PedidoMesaGarcomTela> createState() => _PedidoMesaGarcomTelaState();
}

class _PedidoMesaGarcomTelaState extends State<PedidoMesaGarcomTela> {
  final List<Map<String, dynamic>> itens = [
    {"nome": "Pizza de Brócolis com Bacon", "preco": 45.00, "quantidade": 1},
    {"nome": "Pizza de Bacon", "preco": 45.00, "quantidade": 1},
    {"nome": "Coca-Cola Lata", "preco": 6.00, "quantidade": 1},
    {"nome": "Sonho de Valsa", "preco": 2.50, "quantidade": 1},
  ];

  double get total {
    double soma = 0;

    for (var item in itens) {
      soma += item["preco"] * item["quantidade"];
    }

    return soma;
  }

  @override
  Widget build(BuildContext context) {
    final mesa =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    return Scaffold(
      backgroundColor: Colors.white,

      body: SafeArea(
        child: Column(
          children: [
            //---------------------------------------
            // CABEÇALHO
            //---------------------------------------
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

                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          "Pedido",
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        Text(
                          mesa?["numero"] ?? "Mesa",
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 17,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 45),
                ],
              ),
            ),

            //---------------------------------------
            // STATUS
            //---------------------------------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),

              child: Container(
                padding: const EdgeInsets.all(15),

                decoration: BoxDecoration(
                  color: Colors.orange.shade100,

                  borderRadius: BorderRadius.circular(18),
                ),

                child: Row(
                  children: const [
                    Icon(Icons.restaurant, color: Colors.orange),

                    SizedBox(width: 10),

                    Text(
                      "Pedido em preparo",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            //---------------------------------------
            // PRODUTOS
            //---------------------------------------
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),

                itemCount: itens.length,

                itemBuilder: (context, index) {
                  return _item(index);
                },
              ),
            ),

            //---------------------------------------
            // RODAPÉ
            //---------------------------------------
            Container(
              padding: const EdgeInsets.all(20),

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

              child: Column(
                children: [
                  Row(
                    children: [
                      const Text(
                        "Total",

                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),

                      const Spacer(),

                      Text(
                        "R\$ ${total.toStringAsFixed(2)}",

                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,

                            foregroundColor: Colors.white,

                            minimumSize: const Size(0, 52),
                          ),

                          onPressed: () {
                            Navigator.pushNamed(context, "/garcom/cardapio");
                          },

                          icon: const Icon(Icons.add),

                          label: const Text("Adicionar"),
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,

                            foregroundColor: Colors.white,

                            minimumSize: const Size(0, 52),
                          ),

                          onPressed: () {
                            Navigator.pushNamed(context, "/garcom/finalizacao");
                          },

                          icon: const Icon(Icons.receipt_long),

                          label: const Text("Fechar Conta"),
                        ),
                      ),
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

  Widget _item(int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 15),

      elevation: 3,

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),

      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.green,
          child: Icon(Icons.fastfood, color: Colors.white),
        ),

        title: Text(
          itens[index]["nome"],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),

        subtitle: Text("R\$ ${itens[index]["preco"].toStringAsFixed(2)}"),

        trailing: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            color: Colors.grey.shade100,
          ),

          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle, color: Colors.red),
                onPressed: () {
                  setState(() {
                    if (itens[index]["quantidade"] > 1) {
                      itens[index]["quantidade"]--;
                    }
                  });
                },
              ),

              Text(
                itens[index]["quantidade"].toString(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),

              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.green),
                onPressed: () {
                  setState(() {
                    itens[index]["quantidade"]++;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
