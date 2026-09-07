import 'package:flutter/material.dart';

import '../models/produto.dart';
import '../utils/app_colors.dart';
import '../utils/formatters.dart';

class ProdutoTela extends StatefulWidget {
  final Produto produto;

  const ProdutoTela({super.key, required this.produto});

  @override
  State<ProdutoTela> createState() => _ProdutoTelaState();
}

class _ProdutoTelaState extends State<ProdutoTela> {
  int quantidade = 1;
  final observacaoController = TextEditingController();

  double get valorTotal => widget.produto.preco * quantidade;

  @override
  void dispose() {
    observacaoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SizedBox(
            height: 360,
            width: double.infinity,
            child: Image.network(
              widget.produto.imagem,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return Container(
                  color: AppColors.softGreen,
                  child: const Icon(
                    Icons.fastfood,
                    color: AppColors.green,
                    size: 100,
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: CircleAvatar(
                backgroundColor: Colors.black.withValues(alpha: .45),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height * .58,
                maxHeight: MediaQuery.of(context).size.height * .68,
              ),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.produto.nome,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkGreen,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.produto.descricao,
                    style: const TextStyle(
                      color: AppColors.mutedText,
                      fontSize: 16,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      _QuantidadeButton(
                        icon: Icons.remove,
                        onTap: quantidade == 1
                            ? null
                            : () => setState(() => quantidade--),
                      ),
                      SizedBox(
                        width: 48,
                        child: Text(
                          quantidade.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      _QuantidadeButton(
                        icon: Icons.add,
                        onTap: () => setState(() => quantidade++),
                      ),
                      const Spacer(),
                      Text(
                        Formatters.money(valorTotal),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppColors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Observações',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: observacaoController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Ex: sem cebola, molho à parte...',
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          '/cliente/carrinho',
                          arguments: {
                            'produto': widget.produto,
                            'quantidade': quantidade,
                            'observacao': observacaoController.text.trim(),
                          },
                        );
                      },
                      icon: const Icon(Icons.shopping_cart_outlined),
                      label: const Text('Adicionar ao carrinho'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuantidadeButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _QuantidadeButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(onPressed: onTap, icon: Icon(icon));
  }
}
