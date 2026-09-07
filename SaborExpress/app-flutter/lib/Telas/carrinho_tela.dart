import 'package:flutter/material.dart';

import '../Dados/produtos_mock.dart';
import '../models/produto.dart';
import '../utils/app_colors.dart';
import '../utils/formatters.dart';

class CarrinhoTela extends StatefulWidget {
  const CarrinhoTela({super.key});

  @override
  State<CarrinhoTela> createState() => _CarrinhoTelaState();
}

class _CarrinhoTelaState extends State<CarrinhoTela> {
  final double entrega = 10.00;
  late List<_CarrinhoItem> itens;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;

    itens = [
      _CarrinhoItem(produto: produtosMock[0], quantidade: 1),
      _CarrinhoItem(produto: produtosMock[2], quantidade: 1),
    ];

    if (args is Map<String, dynamic> && args['produto'] is Produto) {
      final produto = args['produto'] as Produto;
      final quantidade = args['quantidade'] as int? ?? 1;
      final observacao = args['observacao']?.toString() ?? '';
      final index = itens.indexWhere((item) => item.produto.id == produto.id);

      if (index >= 0) {
        itens[index] = itens[index].copyWith(
          quantidade: itens[index].quantidade + quantidade,
          observacao: observacao,
        );
      } else {
        itens.insert(
          0,
          _CarrinhoItem(
            produto: produto,
            quantidade: quantidade,
            observacao: observacao,
          ),
        );
      }
    }
  }

  int get quantidadeTotal {
    return itens.fold(0, (total, item) => total + item.quantidade);
  }

  double get subtotal {
    return itens.fold(0, (total, item) => total + item.total);
  }

  double get total {
    return itens.isEmpty ? 0 : subtotal + entrega;
  }

  void _alterarQuantidade(int index, int delta) {
    final item = itens[index];
    final novaQuantidade = item.quantidade + delta;

    setState(() {
      if (novaQuantidade <= 0) {
        itens.removeAt(index);
      } else {
        itens[index] = item.copyWith(quantidade: novaQuantidade);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new),
                  ),
                  const Expanded(
                    child: Text(
                      'Carrinho',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        color: AppColors.green,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Limpar carrinho',
                    onPressed: itens.isEmpty
                        ? null
                        : () => setState(() => itens.clear()),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
            Expanded(
              child: itens.isEmpty
                  ? const _CarrinhoVazio()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemBuilder: (context, index) {
                        final item = itens[index];
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    item.produto.imagem,
                                    width: 70,
                                    height: 70,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 70,
                                      height: 70,
                                      color: AppColors.softGreen,
                                      child: const Icon(
                                        Icons.fastfood,
                                        color: AppColors.green,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.produto.nome,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item.observacao.isEmpty
                                            ? Formatters.money(
                                                item.produto.preco,
                                              )
                                            : item.observacao,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppColors.mutedText,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        Formatters.money(item.total),
                                        style: const TextStyle(
                                          color: AppColors.green,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _QuantidadeControle(
                                  quantidade: item.quantidade,
                                  onAdd: () => _alterarQuantidade(index, 1),
                                  onRemove: () => _alterarQuantidade(index, -1),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemCount: itens.length,
                    ),
            ),
            _ResumoCarrinho(
              subtotal: subtotal,
              entrega: itens.isEmpty ? 0 : entrega,
              total: total,
              quantidadeTotal: quantidadeTotal,
              onContinuar: itens.isEmpty
                  ? null
                  : () {
                      Navigator.pushNamed(
                        context,
                        '/cliente/sacola',
                        arguments: {
                          'subtotal': subtotal,
                          'entrega': entrega,
                          'total': total,
                          'quantidade': quantidadeTotal,
                        },
                      );
                    },
            ),
          ],
        ),
      ),
    );
  }
}

class _CarrinhoItem {
  final Produto produto;
  final int quantidade;
  final String observacao;

  const _CarrinhoItem({
    required this.produto,
    required this.quantidade,
    this.observacao = '',
  });

  double get total => produto.preco * quantidade;

  _CarrinhoItem copyWith({int? quantidade, String? observacao}) {
    return _CarrinhoItem(
      produto: produto,
      quantidade: quantidade ?? this.quantidade,
      observacao: observacao ?? this.observacao,
    );
  }
}

class _QuantidadeControle extends StatelessWidget {
  final int quantidade;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _QuantidadeControle({
    required this.quantidade,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Remover',
          icon: const Icon(Icons.remove_circle_outline, color: AppColors.red),
          onPressed: onRemove,
        ),
        SizedBox(
          width: 24,
          child: Text(
            quantidade.toString(),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        IconButton(
          tooltip: 'Adicionar',
          icon: const Icon(Icons.add_circle_outline, color: AppColors.green),
          onPressed: onAdd,
        ),
      ],
    );
  }
}

class _ResumoCarrinho extends StatelessWidget {
  final double subtotal;
  final double entrega;
  final double total;
  final int quantidadeTotal;
  final VoidCallback? onContinuar;

  const _ResumoCarrinho({
    required this.subtotal,
    required this.entrega,
    required this.total,
    required this.quantidadeTotal,
    required this.onContinuar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppColors.green,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          _LinhaResumo(label: 'Subtotal', value: Formatters.money(subtotal)),
          const SizedBox(height: 8),
          _LinhaResumo(label: 'Entrega', value: Formatters.money(entrega)),
          const Divider(color: Colors.white54, height: 24),
          _LinhaResumo(
            label: 'Total',
            value: Formatters.money(total),
            destaque: true,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onContinuar,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.green,
              ),
              icon: const Icon(Icons.shopping_bag_outlined),
              label: Text(
                quantidadeTotal == 1
                    ? 'Continuar com 1 item'
                    : 'Continuar com $quantidadeTotal itens',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinhaResumo extends StatelessWidget {
  final String label;
  final String value;
  final bool destaque;

  const _LinhaResumo({
    required this.label,
    required this.value,
    this.destaque = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: destaque ? 22 : 15,
            fontWeight: destaque ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: destaque ? 22 : 15,
            fontWeight: destaque ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _CarrinhoVazio extends StatelessWidget {
  const _CarrinhoVazio();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 72, color: AppColors.green),
          SizedBox(height: 12),
          Text(
            'Seu carrinho está vazio',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 4),
          Text(
            'Volte ao cardápio para escolher um produto.',
            style: TextStyle(color: AppColors.mutedText),
          ),
        ],
      ),
    );
  }
}
