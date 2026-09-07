import 'package:flutter/material.dart';

import '../utils/app_colors.dart';
import '../widgets/app_header.dart';

class CadastroCartaoTela extends StatefulWidget {
  const CadastroCartaoTela({super.key});

  @override
  State<CadastroCartaoTela> createState() => _CadastroCartaoTelaState();
}

class _CadastroCartaoTelaState extends State<CadastroCartaoTela> {
  final numeroController = TextEditingController();
  final nomeController = TextEditingController();
  final validadeController = TextEditingController();
  final cvvController = TextEditingController();

  @override
  void dispose() {
    numeroController.dispose();
    nomeController.dispose();
    validadeController.dispose();
    cvvController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final dados = args is Map<String, dynamic> ? args : <String, dynamic>{};

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const AppHeader(title: 'Cartão', trailingIcon: Icons.credit_card),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 180,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.green,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.green.withValues(alpha: 0.22),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.credit_card,
                            color: Colors.white,
                            size: 40,
                          ),
                          Spacer(),
                          Text(
                            '**** **** **** 1234',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'NOME DO TITULAR',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
                    _campo(
                      label: 'Número do cartão',
                      hint: '0000 0000 0000 0000',
                      controller: numeroController,
                      icon: Icons.credit_card,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    _campo(
                      label: 'Nome no cartão',
                      hint: 'Digite o nome do titular',
                      controller: nomeController,
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _campo(
                            label: 'Validade',
                            hint: 'MM/AA',
                            controller: validadeController,
                            keyboardType: TextInputType.datetime,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _campo(
                            label: 'CVV',
                            hint: '123',
                            controller: cvvController,
                            keyboardType: TextInputType.number,
                            obscure: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('Finalizar pagamento'),
                  onPressed: () {
                    if (numeroController.text.trim().isEmpty ||
                        nomeController.text.trim().isEmpty ||
                        validadeController.text.trim().isEmpty ||
                        cvvController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Preencha os dados do cartão'),
                        ),
                      );
                      return;
                    }

                    Navigator.pushNamed(
                      context,
                      '/cliente/pagamento-sucesso',
                      arguments: dados,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _campo({
    required String label,
    required String hint,
    required TextEditingController controller,
    IconData? icon,
    TextInputType? keyboardType,
    bool obscure = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon == null ? null : Icon(icon),
          ),
        ),
      ],
    );
  }
}
