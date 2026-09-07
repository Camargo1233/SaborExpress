import 'package:flutter/material.dart';

import '../utils/app_colors.dart';
import '../widgets/app_header.dart';

class EnderecoTela extends StatelessWidget {
  const EnderecoTela({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const AppHeader(
              title: 'Endereço',
              subtitle: 'Onde o pedido será entregue',
              trailingIcon: Icons.location_on,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 70,
                      color: AppColors.green,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Informe onde deseja receber seu pedido.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.mutedText),
                    ),
                    const SizedBox(height: 26),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            campo('Rua', Icons.streetview),
                            campo('Número', Icons.numbers),
                            campo('Complemento', Icons.home_work_outlined),
                            campo('CEP', Icons.markunread_mailbox_outlined),
                            campo('Bairro', Icons.location_city_outlined),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Endereço salvo com sucesso!'),
                            ),
                          );
                          Navigator.pop(context);
                        },
                        label: const Text('Salvar endereço'),
                      ),
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

  static Widget campo(String texto, IconData icone) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        decoration: InputDecoration(
          labelText: texto,
          prefixIcon: Icon(icone, color: AppColors.green),
        ),
      ),
    );
  }
}
