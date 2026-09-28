import 'package:flutter/material.dart';

import '../utils/app_colors.dart';
import 'status_pedido_tela.dart';

class PagamentoSucessoTela extends StatelessWidget {
  final String tipoPedido;

  const PagamentoSucessoTela({super.key, required this.tipoPedido});

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
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/cliente/home',
                    (route) => false,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(Icons.check_circle, color: AppColors.green, size: 150),
              const SizedBox(height: 28),
              const Text(
                'Pedido confirmado!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              const Text(
                'O pagamento foi registrado no fluxo mockado.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.mutedText),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            StatusPedidoTela(tipoPedido: tipoPedido),
                      ),
                    );
                  },
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('Acompanhar pedido'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
