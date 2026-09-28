import 'package:flutter/material.dart';

import '../utils/app_colors.dart';

class StatusPedidoTela extends StatelessWidget {
  final String tipoPedido;

  const StatusPedidoTela({super.key, required this.tipoPedido});

  String get titulo {
    switch (tipoPedido) {
      case 'delivery':
        return 'Seu pedido está em preparo';
      case 'retirada':
        return 'Pedido recebido';
      case 'mesa':
        return 'Pedido enviado à cozinha';
      default:
        return 'Pedido confirmado';
    }
  }

  String get status {
    switch (tipoPedido) {
      case 'delivery':
        return 'Entrega em breve';
      case 'retirada':
        return 'Retire no balcão';
      case 'mesa':
        return 'Serviremos na mesa';
      default:
        return 'Em andamento';
    }
  }

  IconData get icone {
    switch (tipoPedido) {
      case 'delivery':
        return Icons.delivery_dining;
      case 'retirada':
        return Icons.shopping_bag_outlined;
      case 'mesa':
        return Icons.table_restaurant;
      default:
        return Icons.fastfood;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/cliente/home',
                    (route) => false,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 48),
              Container(
                width: 190,
                height: 190,
                decoration: const BoxDecoration(
                  color: AppColors.softGreen,
                  shape: BoxShape.circle,
                ),
                child: Icon(icone, size: 110, color: AppColors.green),
              ),
              const SizedBox(height: 48),
              Text(
                status,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: AppColors.green,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Este status é mockado e pode ser ligado ao backend depois.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.mutedText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
