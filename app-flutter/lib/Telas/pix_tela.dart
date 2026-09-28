import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/app_colors.dart';
import '../utils/formatters.dart';

class PixTela extends StatelessWidget {
  const PixTela({super.key});

  @override
  Widget build(BuildContext context) {
    const codigoPix = '00020126580014BR.GOV.BCB.PIX123456789';
    final args = ModalRoute.of(context)?.settings.arguments;
    final dados = args is Map<String, dynamic> ? args : <String, dynamic>{};
    final total = (dados['total'] as num?)?.toDouble() ?? 61.00;

    return Scaffold(
      appBar: AppBar(title: const Text('Pagamento Pix')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Text(
                'Escaneie o QR Code',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 24),
              Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Icon(
                  Icons.qr_code_2,
                  size: 190,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                icon: const Icon(Icons.copy),
                label: const Text('Copiar código Pix'),
                onPressed: () {
                  Clipboard.setData(const ClipboardData(text: codigoPix));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Código Pix copiado')),
                  );
                },
              ),
              const SizedBox(height: 32),
              const Text(
                'Valor do pagamento',
                style: TextStyle(color: AppColors.mutedText),
              ),
              const SizedBox(height: 6),
              Text(
                Formatters.money(total),
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: AppColors.green,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Confirmar pagamento'),
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      '/cliente/pagamento-sucesso',
                      arguments: dados,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
