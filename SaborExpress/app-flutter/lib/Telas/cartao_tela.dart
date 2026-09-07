import 'package:flutter/material.dart';

import '../utils/app_colors.dart';

class CartaoTela extends StatelessWidget {
  const CartaoTela({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Adicionar cartão')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Escolha o tipo do cartão',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          _opcao(
            context,
            titulo: 'Cartão de crédito',
            subtitulo: 'Pagamento mockado no app',
            icon: Icons.credit_card,
          ),
          const SizedBox(height: 12),
          _opcao(
            context,
            titulo: 'Cartão de débito',
            subtitulo: 'Pagamento mockado no app',
            icon: Icons.account_balance_wallet_outlined,
          ),
        ],
      ),
    );
  }

  Widget _opcao(
    BuildContext context, {
    required String titulo,
    required String subtitulo,
    required IconData icon,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: AppColors.green),
        title: Text(
          titulo,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(subtitulo),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.pushNamed(context, '/cliente/cadastro-cartao'),
      ),
    );
  }
}
