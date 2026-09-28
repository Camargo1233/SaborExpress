import 'package:flutter/material.dart';

import '../utils/app_colors.dart';

class MesaTela extends StatefulWidget {
  const MesaTela({super.key});

  @override
  State<MesaTela> createState() => _MesaTelaState();
}

class _MesaTelaState extends State<MesaTela> {
  int? mesaSelecionada;

  final List<int> mesas = [1, 2, 6, 8, 9];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reservar mesa')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mesas disponíveis',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: mesas.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final mesa = mesas[index];
                  final selecionada = mesaSelecionada == mesa;

                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => setState(() => mesaSelecionada = mesa),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: selecionada ? AppColors.softGreen : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selecionada
                              ? AppColors.green
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.table_restaurant,
                            color: AppColors.green,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Mesa $mesa',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Icon(
                            selecionada
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color: selecionada
                                ? AppColors.green
                                : AppColors.mutedText,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: mesaSelecionada == null
                    ? null
                    : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Mesa ${mesaSelecionada!} reservada!',
                            ),
                          ),
                        );
                        Navigator.pop(context);
                      },
                icon: const Icon(Icons.check),
                label: const Text('Reservar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
