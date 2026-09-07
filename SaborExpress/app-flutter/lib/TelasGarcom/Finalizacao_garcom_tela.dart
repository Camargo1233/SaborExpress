import 'package:flutter/material.dart';

class FinalizacaoGarcomTela extends StatefulWidget {
  final Map<String, dynamic> mesa;

  const FinalizacaoGarcomTela({super.key, required this.mesa});

  @override
  State<FinalizacaoGarcomTela> createState() => _FinalizacaoGarcomTelaState();
}

class _FinalizacaoGarcomTelaState extends State<FinalizacaoGarcomTela> {
  String pagamento = "";

  final List<Map<String, dynamic>> pedidos = [
    {"nome": "Pizza de Bacon", "preco": 45.00},

    {"nome": "Pizza Brócolis com Bacon", "preco": 45.00},

    {"nome": "Coca-Cola 350ml", "preco": 6.00},

    {"nome": "Sonho de Valsa", "preco": 2.50},
  ];

  double get total {
    double valor = 0;

    for (var item in pedidos) {
      valor += item["preco"];
    }

    return valor;
  }

  void finalizarPagamento() {
    if (pagamento.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selecione uma forma de pagamento")),
      );

      return;
    }

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: Colors.green,

        centerTitle: true,

        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),

          onPressed: () {
            Navigator.pop(context);
          },
        ),

        title: const Text(
          "Finalização",

          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Text(
              widget.mesa["numero"],

              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

            const Text(
              "Resumo do pedido",

              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 15),

            Expanded(
              child: ListView.builder(
                itemCount: pedidos.length,

                itemBuilder: (context, index) {
                  final item = pedidos[index];

                  return Card(
                    elevation: 3,

                    margin: const EdgeInsets.only(bottom: 10),

                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.green,

                        child: Icon(Icons.fastfood, color: Colors.white),
                      ),

                      title: Text(
                        item["nome"],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),

                      trailing: Text(
                        "R\$ ${item["preco"].toStringAsFixed(2)}",

                        style: const TextStyle(
                          color: Colors.green,

                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              "Forma de pagamento",

              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                pagamentoBotao("Dinheiro", Icons.money),

                const SizedBox(width: 10),

                pagamentoBotao("Pix", Icons.pix),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                pagamentoBotao("Cartão", Icons.credit_card),

                const SizedBox(width: 10),

                pagamentoBotao("Nubank", Icons.account_balance),
              ],
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: Text(
                    "Total\nR\$ ${total.toStringAsFixed(2)}",

                    style: const TextStyle(
                      fontSize: 25,

                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                SizedBox(
                  height: 55,

                  width: 170,

                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,

                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),

                    onPressed: finalizarPagamento,

                    child: const Text(
                      "Finalizar",

                      style: TextStyle(
                        color: Colors.white,

                        fontSize: 18,

                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget pagamentoBotao(String texto, IconData icone) {
    bool selecionado = pagamento == texto;

    return Expanded(
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: selecionado ? Colors.green : Colors.green.shade200,

          padding: const EdgeInsets.symmetric(vertical: 15),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),

        icon: Icon(icone, color: Colors.white),

        label: Text(texto, style: const TextStyle(color: Colors.white)),

        onPressed: () {
          setState(() {
            pagamento = texto;
          });
        },
      ),
    );
  }
}
