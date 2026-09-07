import 'package:flutter/material.dart';

class HomeGerenteTela extends StatelessWidget {
  const HomeGerenteTela({super.key});

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
                  const CircleAvatar(
                    radius: 28,

                    backgroundColor: Colors.white,

                    child: Icon(
                      Icons.admin_panel_settings,
                      color: Colors.green,
                      size: 35,
                    ),
                  ),

                  const SizedBox(width: 15),

                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        Text(
                          "Olá, Gerente",

                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        Text(
                          "Painel Administrativo",

                          style: TextStyle(color: Colors.white70, fontSize: 15),
                        ),
                      ],
                    ),
                  ),

                  IconButton(
                    icon: const Icon(
                      Icons.logout,
                      color: Colors.white,
                      size: 30,
                    ),

                    tooltip: "Sair",

                    onPressed: () {
                      showDialog(
                        context: context,

                        builder: (context) {
                          return AlertDialog(
                            title: const Text("Sair"),

                            content: const Text(
                              "Deseja realmente sair da conta?",
                            ),

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
                                ),

                                onPressed: () {
                                  Navigator.pop(context);

                                  Navigator.pushNamedAndRemoveUntil(
                                    context,

                                    "/login",

                                    (route) => false,
                                  );
                                },

                                child: const Text(
                                  "Sair",
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),

                child: Column(
                  children: [
                    // INDICADORES
                    Row(
                      children: [
                        _cardInfo(Icons.receipt_long, "Pedidos", "18"),

                        const SizedBox(width: 15),

                        _cardInfo(
                          Icons.attach_money,
                          "Faturamento",
                          "R\$ 540,00",
                        ),
                      ],
                    ),

                    const SizedBox(height: 15),

                    Row(
                      children: [
                        _cardInfo(
                          Icons.local_pizza,
                          "Mais vendido",
                          "Pizza Bacon",
                        ),

                        const SizedBox(width: 15),

                        _cardInfo(
                          Icons.table_restaurant,
                          "Mesas",
                          "5 ocupadas",
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    // MENU
                    _botaoMenu(
                      context,
                      "Gerenciar Pedidos",
                      Icons.receipt,
                      "/adm/pedidos",
                    ),

                    const SizedBox(height: 15),

                    _botaoMenu(
                      context,
                      "Gerenciar Cardápio",
                      Icons.restaurant_menu,
                      "/adm/cardapio",
                    ),

                    const SizedBox(height: 15),

                    _botaoMenu(
                      context,
                      "Relatórios",
                      Icons.bar_chart,
                      "/adm/relatorios",
                    ),

                    const SizedBox(height: 35),

                    Align(
                      alignment: Alignment.centerLeft,

                      child: Text(
                        "Pedidos recentes",

                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const SizedBox(height: 15),

                    _pedido(
                      "Mesa 01",
                      "R\$ 98,50",
                      "Em preparo",
                      Colors.orange,
                    ),

                    _pedido(
                      "Mesa 04",
                      "R\$ 64,00",
                      "Em preparo",
                      Colors.orange,
                    ),

                    _pedido("Mesa 02", "R\$ 80,00", "Finalizado", Colors.green),

                    _pedido(
                      "Mesa 06",
                      "R\$ 150,50",
                      "Finalizado",
                      Colors.green,
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

  Widget _cardInfo(IconData icon, String titulo, String valor) {
    return Expanded(
      child: Container(
        height: 110,

        decoration: BoxDecoration(
          color: Colors.green.shade50,

          borderRadius: BorderRadius.circular(20),
        ),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            Icon(icon, color: Colors.green, size: 30),

            const SizedBox(height: 8),

            Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),

            Text(
              valor,

              style: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _botaoMenu(
    BuildContext context,
    String texto,
    IconData icon,
    String rota,
  ) {
    return SizedBox(
      width: double.infinity,

      height: 60,

      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),

        icon: Icon(icon, color: Colors.white),

        label: Text(
          texto,

          style: const TextStyle(
            color: Colors.white,

            fontSize: 18,

            fontWeight: FontWeight.bold,
          ),
        ),

        onPressed: () {
          Navigator.pushNamed(context, rota);
        },
      ),
    );
  }

  Widget _pedido(String mesa, String valor, String status, Color cor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),

      padding: const EdgeInsets.all(15),

      decoration: BoxDecoration(
        color: Colors.grey.shade100,

        borderRadius: BorderRadius.circular(15),
      ),

      child: Row(
        children: [
          const Icon(Icons.table_restaurant, color: Colors.green),

          const SizedBox(width: 15),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(mesa, style: const TextStyle(fontWeight: FontWeight.bold)),

                Text(valor),
              ],
            ),
          ),

          Text(
            status,

            style: TextStyle(color: cor, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
