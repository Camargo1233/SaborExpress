import 'package:flutter/material.dart';

import '../Repositories/carrinho_repository.dart';
import '../utils/app_colors.dart';
import '../utils/formatters.dart';

class CarrinhoTela extends StatefulWidget {
  const CarrinhoTela({super.key});

  @override
  State<CarrinhoTela> createState() => _CarrinhoTelaState();
}

class _CarrinhoTelaState extends State<CarrinhoTela> {
  final carrinho = CarrinhoRepository.instance;

  // Por enquanto mantemos a taxa que já existia no projeto.
  // Na Sacola ela será aplicada somente se o pedido for Delivery.
  final double entrega = 10.00;

  List<CarrinhoItem> get itens => carrinho.itens;

  int get quantidadeTotal => carrinho.quantidadeTotal;

  double get subtotal => carrinho.subtotal;

  void _aumentarQuantidade(int index) {
    setState(() {
      carrinho.aumentarQuantidade(index);
    });
  }

  void _diminuirQuantidade(int index) {
    setState(() {
      carrinho.diminuirQuantidade(index);
    });
  }

  void _limparCarrinho() {
    setState(() {
      carrinho.limpar();
    });
  }

  void _continuarComprando() {
    // Volta para a Home/Cardápio sem apagar o carrinho.
    Navigator.popUntil(context, ModalRoute.withName('/cliente/home'));
  }

  void _irParaSacola() {
    if (carrinho.vazio) {
      return;
    }

    Navigator.pushNamed(
      context,
      '/cliente/sacola',
      arguments: {
        'subtotal': subtotal,
        'entrega': entrega,
        'quantidade': quantidadeTotal,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // =====================================================
            // CABEÇALHO
            // =====================================================
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
                    onPressed: carrinho.vazio ? null : _limparCarrinho,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),

            // =====================================================
            // PRODUTOS
            // =====================================================
            Expanded(
              child: carrinho.vazio
                  ? const _CarrinhoVazio()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: itens.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
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
                                    errorBuilder: (_, __, ___) {
                                      return Container(
                                        width: 70,
                                        height: 70,
                                        color: AppColors.softGreen,
                                        child: const Icon(
                                          Icons.fastfood,
                                          color: AppColors.green,
                                        ),
                                      );
                                    },
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
                                        Formatters.money(item.produto.preco),
                                        style: const TextStyle(
                                          color: AppColors.mutedText,
                                        ),
                                      ),

                                      if (item.observacao.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          item.observacao,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppColors.mutedText,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],

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
                                  onAdd: () => _aumentarQuantidade(index),
                                  onRemove: () => _diminuirQuantidade(index),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // =====================================================
            // RESUMO
            // =====================================================
            if (!carrinho.vazio)
              _ResumoCarrinho(
                subtotal: subtotal,
                quantidadeTotal: quantidadeTotal,
                onContinuarComprando: _continuarComprando,
                onContinuarPedido: _irParaSacola,
              ),
          ],
        ),
      ),
    );
  }
}

// =============================================================
// CONTROLE DE QUANTIDADE
// =============================================================

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

// =============================================================
// RESUMO DO CARRINHO
// =============================================================

class _ResumoCarrinho extends StatelessWidget {
  final double subtotal;
  final int quantidadeTotal;
  final VoidCallback onContinuarComprando;
  final VoidCallback onContinuarPedido;

  const _ResumoCarrinho({
    required this.subtotal,
    required this.quantidadeTotal,
    required this.onContinuarComprando,
    required this.onContinuarPedido,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: const BoxDecoration(
        color: AppColors.green,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          _LinhaResumo(
            label: quantidadeTotal == 1 ? '1 item' : '$quantidadeTotal itens',
            value: Formatters.money(subtotal),
            destaque: true,
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onContinuarComprando,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Continuar comprando'),
            ),
          ),

          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onContinuarPedido,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.green,
              ),
              icon: const Icon(Icons.shopping_bag_outlined),
              label: const Text('Continuar pedido'),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================
// LINHA DO RESUMO
// =============================================================

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

// =============================================================
// CARRINHO VAZIO
// =============================================================

class _CarrinhoVazio extends StatelessWidget {
  const _CarrinhoVazio();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.shopping_cart_outlined,
            size: 72,
            color: AppColors.green,
          ),
          const SizedBox(height: 12),
          const Text(
            'Seu carrinho está vazio',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Volte ao cardápio para escolher um produto.',
            style: TextStyle(color: AppColors.mutedText),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.popUntil(context, ModalRoute.withName('/cliente/home'));
            },
            icon: const Icon(Icons.restaurant_menu),
            label: const Text('Ver cardápio'),
          ),
        ],
      ),
    );
  }
}
