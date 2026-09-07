import 'package:flutter/material.dart';

import '../utils/app_colors.dart';
import '../utils/formatters.dart';

class SacolaTela extends StatefulWidget {
  const SacolaTela({super.key});

  @override
  State<SacolaTela> createState() => _SacolaTelaState();
}

class _SacolaTelaState extends State<SacolaTela> {
  TipoPedido tipoPedido = TipoPedido.delivery;
  String pagamento = 'Pix';

  double subtotal = 51;
  double entrega = 10;
  double total = 61;
  int quantidade = 2;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is Map<String, dynamic>) {
      subtotal = (args['subtotal'] as num?)?.toDouble() ?? subtotal;
      entrega = (args['entrega'] as num?)?.toDouble() ?? entrega;
      total = (args['total'] as num?)?.toDouble() ?? total;
      quantidade = args['quantidade'] as int? ?? quantidade;
    }
  }

  String get tipoPedidoValor => tipoPedido.name;

  @override
  Widget build(BuildContext context) {
    final totalAtual = tipoPedido == TipoPedido.delivery
        ? subtotal + entrega
        : subtotal;

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
                    icon: const Icon(Icons.arrow_back_ios_new),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      'Sacola',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.green,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle('Tipo do pedido'),
                    const SizedBox(height: 12),
                    SegmentedButton<TipoPedido>(
                      segments: const [
                        ButtonSegment(
                          value: TipoPedido.delivery,
                          label: Text('Delivery'),
                          icon: Icon(Icons.delivery_dining),
                        ),
                        ButtonSegment(
                          value: TipoPedido.retirada,
                          label: Text('Retirada'),
                          icon: Icon(Icons.storefront),
                        ),
                        ButtonSegment(
                          value: TipoPedido.mesa,
                          label: Text('Mesa'),
                          icon: Icon(Icons.table_restaurant),
                        ),
                      ],
                      selected: {tipoPedido},
                      onSelectionChanged: (value) {
                        setState(() {
                          tipoPedido = value.first;
                          pagamento = 'Pix';
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    _buildInformacaoPedido(),
                    const SizedBox(height: 24),
                    const _SectionTitle('Forma de pagamento'),
                    const SizedBox(height: 12),
                    _pagamento('Pix', Icons.pix),
                    _pagamento('Cartão', Icons.credit_card),
                    if (tipoPedido == TipoPedido.delivery)
                      _pagamento('Pagar na entrega', Icons.delivery_dining),
                    if (tipoPedido == TipoPedido.retirada ||
                        tipoPedido == TipoPedido.mesa)
                      _pagamento('Pagar no local', Icons.store),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
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
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total',
                          style: TextStyle(
                            color: AppColors.mutedText,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          Formatters.money(totalAtual),
                          style: const TextStyle(
                            color: AppColors.green,
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          quantidade == 1 ? '1 item' : '$quantidade itens',
                          style: const TextStyle(color: AppColors.mutedText),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 150,
                    child: ElevatedButton(
                      onPressed: () => _continuar(totalAtual),
                      child: const Text('Continuar'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _continuar(double totalAtual) {
    final args = {
      'tipoPedido': tipoPedidoValor,
      'total': totalAtual,
      'quantidade': quantidade,
    };

    if (pagamento == 'Pix') {
      Navigator.pushNamed(context, '/cliente/pix', arguments: args);
      return;
    }

    if (pagamento == 'Cartão') {
      Navigator.pushNamed(context, '/cliente/cadastro-cartao', arguments: args);
      return;
    }

    Navigator.pushNamed(context, '/cliente/pagamento-sucesso', arguments: args);
  }

  Widget _buildInformacaoPedido() {
    switch (tipoPedido) {
      case TipoPedido.delivery:
        return _InfoCard(
          icon: Icons.location_on_outlined,
          title: 'Endereço de entrega',
          subtitle: 'Rua Exemplo, 123 - Centro',
          action: 'Trocar',
          onTap: () => Navigator.pushNamed(context, '/cliente/endereco'),
        );
      case TipoPedido.retirada:
        return const _InfoCard(
          icon: Icons.storefront,
          title: 'Retirada no local',
          subtitle: 'Seu pedido ficará disponível no balcão.',
        );
      case TipoPedido.mesa:
        return _InfoCard(
          icon: Icons.table_restaurant,
          title: 'Mesa selecionada',
          subtitle: 'Mesa 01',
          action: 'Trocar',
          onTap: () => Navigator.pushNamed(context, '/cliente/mesa'),
        );
    }
  }

  Widget _pagamento(String nome, IconData icon) {
    final selecionado = pagamento == nome;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => pagamento = nome),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selecionado ? AppColors.softGreen : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selecionado ? AppColors.green : Colors.grey.shade300,
              width: selecionado ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.green),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  nome,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Icon(
                selecionado
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: selecionado ? AppColors.green : AppColors.mutedText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? action;
  final VoidCallback? onTap;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: AppColors.green, size: 30),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: action == null
            ? null
            : TextButton(onPressed: onTap, child: Text(action!)),
      ),
    );
  }
}

enum TipoPedido { delivery, retirada, mesa }
