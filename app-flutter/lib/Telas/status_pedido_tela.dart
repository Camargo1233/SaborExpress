import 'dart:async';

import 'package:flutter/material.dart';

import '../Repositories/pedido_repository.dart';
import '../utils/app_colors.dart';
import '../utils/formatters.dart';

class StatusPedidoTela extends StatefulWidget {
  final String tipoPedido;
  final String pedidoId;

  const StatusPedidoTela({
    super.key,
    required this.tipoPedido,
    required this.pedidoId,
  });

  @override
  State<StatusPedidoTela> createState() => _StatusPedidoTelaState();
}

class _StatusPedidoTelaState extends State<StatusPedidoTela>
    with WidgetsBindingObserver {
  final PedidoRepository _repository = PedidoRepository();

  Timer? _timer;

  Map<String, dynamic>? _pedido;

  String? _erro;

  bool _carregando = true;
  bool _consultando = false;
  bool _appAtivo = true;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _buscarPedido();

    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_appAtivo) {
        _buscarPedido();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appAtivo = state == AppLifecycleState.resumed;

    if (_appAtivo) {
      _buscarPedido();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ============================================================
  // CONSULTAR PEDIDO
  // ============================================================

  Future<void> _buscarPedido() async {
    if (!mounted || _consultando) return;

    _consultando = true;

    try {
      final pedido = await _repository.detalharPedido(widget.pedidoId);

      if (!mounted) return;

      setState(() {
        _pedido = pedido;
        _erro = null;
        _carregando = false;
      });
    } catch (erro) {
      if (!mounted) return;

      setState(() {
        _erro = erro.toString();
        _carregando = false;
      });
    } finally {
      _consultando = false;
    }
  }

  // ============================================================
  // INFORMAÇÕES DO PEDIDO
  // ============================================================

  String get _statusAtual {
    return (_pedido?['status'] ?? 'aguardando_confirmacao')
        .toString()
        .toLowerCase();
  }

  String get _tipoAtual {
    return (_pedido?['tipo'] ?? widget.tipoPedido).toString().toLowerCase();
  }

  String get _numeroPedido {
    final codigo = _pedido?['codigo']?.toString();

    if (codigo != null && codigo.isNotEmpty) {
      return codigo;
    }

    final numeroDia = _pedido?['numero_dia']?.toString();

    if (numeroDia != null && numeroDia.isNotEmpty) {
      return numeroDia.padLeft(4, '0');
    }

    return '---';
  }

  String get _titulo {
    switch (_statusAtual) {
      case 'aguardando_confirmacao':
        return 'Pedido recebido!';

      case 'confirmado':
        return 'Pedido confirmado!';

      case 'em_preparo':
        return 'Preparando seu pedido';

      case 'pronto':
        return 'Pedido pronto!';

      case 'em_entrega':
        return 'Saiu para entrega!';

      case 'concluido':
        return 'Pedido concluído!';

      case 'cancelado':
        return 'Pedido cancelado';

      default:
        return 'Acompanhamento do pedido';
    }
  }

  String get _mensagem {
    switch (_statusAtual) {
      case 'aguardando_confirmacao':
        return 'O restaurante recebeu seu pedido e está aguardando confirmação.';

      case 'confirmado':
        return 'O restaurante confirmou seu pedido.';

      case 'em_preparo':
        return 'A cozinha está preparando seus produtos.';

      case 'pronto':
        if (_tipoAtual == 'retirada') {
          return 'Seu pedido está disponível para retirada!';
        }

        if (_tipoAtual == 'mesa') {
          return 'Seu pedido está pronto para ser servido!';
        }

        return 'Seu pedido está pronto para entrega.';

      case 'em_entrega':
        return 'Seu pedido está a caminho!';

      case 'concluido':
        return 'Obrigado por escolher o SaborExpress!';

      case 'cancelado':
        return 'Este pedido foi cancelado.';

      default:
        return 'Acompanhe as atualizações do pedido.';
    }
  }

  IconData get _icone {
    switch (_statusAtual) {
      case 'aguardando_confirmacao':
        return Icons.schedule_rounded;

      case 'confirmado':
        return Icons.check_circle_outline_rounded;

      case 'em_preparo':
        return Icons.restaurant_rounded;

      case 'pronto':
        return Icons.task_alt_rounded;

      case 'em_entrega':
        return Icons.delivery_dining_rounded;

      case 'concluido':
        return Icons.check_circle_rounded;

      case 'cancelado':
        return Icons.cancel_outlined;

      default:
        return Icons.receipt_long_rounded;
    }
  }

  double get _progresso {
    switch (_statusAtual) {
      case 'aguardando_confirmacao':
        return 0.15;

      case 'confirmado':
        return 0.35;

      case 'em_preparo':
        return 0.60;

      case 'pronto':
        return 0.85;

      case 'em_entrega':
        return 0.95;

      case 'concluido':
        return 1.0;

      default:
        return 0;
    }
  }

  String get _tipoDescricao {
    switch (_tipoAtual) {
      case 'delivery':
        return 'Entrega';

      case 'retirada':
        return 'Retirada';

      case 'mesa':
        return 'Mesa';

      default:
        return 'Pedido';
    }
  }

  String get _pagamentoDescricao {
    final status = _pedido?['status_pagamento']?.toString() ?? '';

    switch (status) {
      case 'pago':
        return 'Pago';

      case 'parcial':
        return 'Parcialmente pago';

      case 'pendente':
        return 'Pendente';

      default:
        return status.isEmpty ? 'Não informado' : status;
    }
  }

  void _voltarHome() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/cliente/home',
      (route) => false,
    );
  }

  // ============================================================
  // TELA PRINCIPAL
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.darkGreen,
        elevation: 0,
        title: const Text(
          'Acompanhar pedido',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _voltarHome,
        ),
      ),
      body: SafeArea(
        child: _carregando
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.green),
              )
            : _pedido == null
            ? _erroInicial()
            : RefreshIndicator(
                onRefresh: _buscarPedido,
                color: AppColors.green,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  children: [
                    _cabecalhoPedido(),

                    const SizedBox(height: 22),

                    _cardStatus(),

                    const SizedBox(height: 22),

                    _cardInformacoes(),

                    const SizedBox(height: 20),

                    if (_erro != null)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Não foi possível atualizar o status. Exibindo as últimas informações recebidas.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),

                    OutlinedButton.icon(
                      onPressed: _buscarPedido,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Atualizar pedido'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.green,
                        side: const BorderSide(color: AppColors.green),
                        padding: const EdgeInsets.all(15),
                      ),
                    ),

                    const SizedBox(height: 12),

                    ElevatedButton.icon(
                      onPressed: _voltarHome,
                      icon: const Icon(Icons.home_rounded),
                      label: const Text('Voltar para o cardápio'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(15),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  // ============================================================
  // CABEÇALHO DO PEDIDO
  // ============================================================

  Widget _cabecalhoPedido() {
    return Column(
      children: [
        Text(
          'Pedido #$_numeroPedido',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.darkGreen,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _tipoDescricao,
          style: const TextStyle(color: AppColors.mutedText, fontSize: 14),
        ),
      ],
    );
  }

  // ============================================================
  // CARD DE STATUS
  // ============================================================

  Widget _cardStatus() {
    final cancelado = _statusAtual == 'cancelado';

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: cancelado
              ? Colors.red.shade200
              : AppColors.green.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: cancelado ? Colors.red.shade50 : AppColors.softGreen,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _icone,
              size: 76,
              color: cancelado ? Colors.red : AppColors.green,
            ),
          ),

          const SizedBox(height: 24),

          Text(
            _titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              color: AppColors.darkGreen,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            _mensagem,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.mutedText,
              fontSize: 14,
              height: 1.5,
            ),
          ),

          if (!cancelado) ...[
            const SizedBox(height: 24),

            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: _progresso,
                minHeight: 9,
                backgroundColor: AppColors.softGreen,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.green,
                ),
              ),
            ),

            const SizedBox(height: 12),

            const Text(
              'Atualização automática a cada 5 segundos',
              style: TextStyle(color: AppColors.mutedText, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // INFORMAÇÕES DO PEDIDO
  // ============================================================

  Widget _cardInformacoes() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Informações do pedido',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.darkGreen,
            ),
          ),

          const SizedBox(height: 16),

          _linhaInformacao('Número', '#$_numeroPedido'),

          const Divider(height: 24),

          _linhaInformacao('Tipo', _tipoDescricao),

          const Divider(height: 24),

          _linhaInformacao('Pagamento', _pagamentoDescricao),

          const Divider(height: 24),

          _linhaInformacao(
            'Total',
            Formatters.money(
              double.tryParse(_pedido?['total']?.toString() ?? '') ?? 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _linhaInformacao(String titulo, String valor) {
    return Row(
      children: [
        Expanded(
          child: Text(
            titulo,
            style: const TextStyle(color: AppColors.mutedText),
          ),
        ),
        Text(
          valor,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.darkGreen,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ERRO INICIAL
  // ============================================================

  Widget _erroInicial() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 65,
              color: AppColors.mutedText,
            ),

            const SizedBox(height: 18),

            const Text(
              'Não foi possível carregar o pedido.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.darkGreen,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              _erro ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.mutedText),
            ),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: _buscarPedido,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tentar novamente'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 12),

            TextButton(
              onPressed: _voltarHome,
              child: const Text('Voltar para o cardápio'),
            ),
          ],
        ),
      ),
    );
  }
}
