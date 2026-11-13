import 'package:flutter/material.dart';

import '../utils/app_colors.dart';

class PagamentoSucessoTela extends StatelessWidget {
  final String tipoPedido;
  final String pedidoId;
  final String? numeroMesa;

  const PagamentoSucessoTela({
    super.key,
    required this.tipoPedido,
    required this.pedidoId,
    this.numeroMesa,
  });

  bool get _ehMesa => tipoPedido.toLowerCase() == 'mesa';

  String get _mesaFormatada {
    final numero = numeroMesa?.trim();

    if (numero == null || numero.isEmpty) {
      return 'Mesa não informada';
    }

    return 'Mesa $numero';
  }

  void _voltarParaHome(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/cliente/home',
      (route) => false,
    );
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
                  icon: const Icon(Icons.close),
                  onPressed: () => _voltarParaHome(context),
                ),
              ),

              const Spacer(),

              const Icon(Icons.check_circle, color: AppColors.green, size: 130),

              const SizedBox(height: 28),

              Text(
                _ehMesa ? 'Pagamento confirmado!' : 'Pedido registrado!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 14),

              if (_ehMesa) ...[
                const Text(
                  'Seu pagamento foi realizado com sucesso!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 28),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 28,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.green.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.table_restaurant_rounded,
                        color: AppColors.green,
                        size: 42,
                      ),

                      const SizedBox(height: 12),

                      const Text(
                        'Pagamento referente à',
                        style: TextStyle(
                          color: AppColors.mutedText,
                          fontSize: 14,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        _mesaFormatada,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.green,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                const Text(
                  'O garçom será responsável pela '
                  'finalização do seu pedido na mesa.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              ] else ...[
                const Text(
                  'Seu pedido foi registrado com sucesso! '
                  'Você pode acompanhar todas as atualizações '
                  'diretamente na tela inicial.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              ],

              const Spacer(),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _voltarParaHome(context),
                  icon: const Icon(Icons.home_rounded),
                  label: Text(
                    _ehMesa
                        ? 'Voltar para o início'
                        : 'Ver pedidos em andamento',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
