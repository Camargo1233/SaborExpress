import 'package:flutter/material.dart';

import 'finalizacao_garcom_tela.dart';

class MesasGarcomTela extends StatefulWidget {
  const MesasGarcomTela({super.key});

  @override
  State<MesasGarcomTela> createState() => _MesasGarcomTelaState();
}

class _MesasGarcomTelaState extends State<MesasGarcomTela> {
  final List<Map<String, dynamic>> mesas = [
    {
      "numero": "Mesa 01",
      "status": "Pedido em andamento",
      "cor": Colors.red,
      "pedido": true,
    },

    {
      "numero": "Mesa 02",
      "status": "Livre",
      "cor": Colors.green,
      "pedido": false,
    },

    {
      "numero": "Mesa 03",
      "status": "Ocupada",
      "cor": Colors.orange,
      "pedido": false,
    },

    {
      "numero": "Mesa 04",
      "status": "Pedido em andamento",
      "cor": Colors.red,
      "pedido": true,
    },

    {
      "numero": "Mesa 05",
      "status": "Livre",
      "cor": Colors.green,
      "pedido": false,
    },

    {
      "numero": "Mesa 06",
      "status": "Ocupada",
      "cor": Colors.orange,
      "pedido": false,
    },

    {
      "numero": "Mesa 07",
      "status": "Livre",
      "cor": Colors.green,
      "pedido": false,
    },
  ];

  void ocuparMesa(Map<String, dynamic> mesa) {
    setState(() {
      mesa["status"] = "Ocupada";

      mesa["cor"] = Colors.orange;

      mesa["pedido"] = false;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Mesa ocupada")));
  }

  void iniciarPedido(Map<String, dynamic> mesa) {
    setState(() {
      mesa["status"] = "Pedido em andamento";

      mesa["cor"] = Colors.red;

      mesa["pedido"] = true;
    });

    abrirPedido(mesa);
  }

  void abrirPedido(Map<String, dynamic> mesa) {
    Navigator.pushNamed(context, "/garcom/pedido", arguments: mesa);
  }

  void finalizarMesa(Map<String, dynamic> mesa) async {
    final resultado = await Navigator.push(
      context,

      MaterialPageRoute(builder: (_) => FinalizacaoGarcomTela(mesa: mesa)),
    );

    if (resultado == true) {
      setState(() {
        mesa["status"] = "Livre";

        mesa["cor"] = Colors.green;

        mesa["pedido"] = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Mesa liberada novamente")));
    }
  }

  void abrirOpcoesMesa(Map<String, dynamic> mesa) {
    if (mesa["status"] == "Livre") {
      showDialog(
        context: context,

        builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),

            title: Text(
              mesa["numero"],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),

            content: const Text("Cliente entrou nesta mesa?"),

            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },

                child: const Text("Cancelar"),
              ),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,

                  foregroundColor: Colors.white,
                ),

                onPressed: () {
                  Navigator.pop(context);

                  ocuparMesa(mesa);
                },

                child: const Text("Ocupar mesa"),
              ),
            ],
          );
        },
      );
    } else if (mesa["status"] == "Ocupada") {
      iniciarPedido(mesa);
    } else if (mesa["status"] == "Pedido em andamento") {
      abrirPedido(mesa);
    }
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
          "Mesas",

          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),

      body: ListView.builder(
        padding: const EdgeInsets.all(15),

        itemCount: mesas.length,

        itemBuilder: (context, index) {
          final mesa = mesas[index];

          return InkWell(
            borderRadius: BorderRadius.circular(20),

            onTap: () {
              abrirOpcoesMesa(mesa);
            },

            child: Container(
              margin: const EdgeInsets.only(bottom: 15),

              padding: const EdgeInsets.all(18),

              decoration: BoxDecoration(
                color: Colors.grey.shade100,

                borderRadius: BorderRadius.circular(20),

                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .08),

                    blurRadius: 8,

                    offset: const Offset(0, 3),
                  ),
                ],
              ),

              child: Row(
                children: [
                  Container(
                    height: 60,

                    width: 60,

                    decoration: BoxDecoration(
                      color: mesa["cor"],

                      borderRadius: BorderRadius.circular(18),
                    ),

                    child: Center(
                      child: Text(
                        "${index + 1}",

                        style: const TextStyle(
                          color: Colors.white,

                          fontSize: 22,

                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 18),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        Text(
                          mesa["numero"],

                          style: const TextStyle(
                            fontSize: 20,

                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Row(
                          children: [
                            CircleAvatar(
                              radius: 6,

                              backgroundColor: mesa["cor"],
                            ),

                            const SizedBox(width: 8),

                            Text(
                              mesa["status"],

                              style: TextStyle(
                                color: mesa["cor"],

                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const Icon(Icons.arrow_forward_ios, size: 18),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
