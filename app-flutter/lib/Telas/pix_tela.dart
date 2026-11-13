import 'package:flutter/material.dart';

import '../Repositories/carrinho_repository.dart';
import '../Repositories/pagamento_repository.dart';
import '../Repositories/pedido_repository.dart';
import '../utils/app_colors.dart';
import '../utils/formatters.dart';
import 'status_pedido_tela.dart';

/// Pagamento Pix exclusivamente demonstrativo.
/// Nenhum dinheiro real e transferido.
class PixTela extends StatefulWidget {
  const PixTela({super.key});

  @override
  State<PixTela> createState() => _PixTelaState();
}

class _PixTelaState extends State<PixTela> {
  final PedidoRepository _pedidoRepository = PedidoRepository();
  final PagamentoRepository _pagamentoRepository = PagamentoRepository();
  final CarrinhoRepository _carrinhoRepository = CarrinhoRepository.instance;

  bool _processando = false;
  bool _confirmando = false;
  bool _pagamentoCriado = false;
  bool _pagamentoConfirmado = false;
  bool _redirecionando = false;
  bool _argumentosCarregados = false;
  bool _itensAdicionados = false;

  String? _erro;
  String? _pedidoId;
  String? _pagamentoId;

  Map<String, dynamic> _dados = {};

  double get _total {
    final valor = _dados['total'];

    if (valor is num) {
      return valor.toDouble();
    }

    return _carrinhoRepository.subtotal;
  }

  String get _tipoPedido {
    final tipo = (_dados['tipoPedido'] ?? _dados['tipo'] ?? 'retirada')
        .toString()
        .toLowerCase();

    if (tipo.contains('delivery') || tipo.contains('entrega')) {
      return 'delivery';
    }

    if (tipo.contains('mesa')) {
      return 'mesa';
    }

    return 'retirada';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_argumentosCarregados) return;

    _argumentosCarregados = true;

    final argumentos = ModalRoute.of(context)?.settings.arguments;

    if (argumentos is Map) {
      _dados = Map<String, dynamic>.from(argumentos);
    }

    _pedidoId = _buscarPedidoExistente();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _prepararPagamentoPix();
      }
    });
  }

  String _limparErro(Object erro) {
    var mensagem = erro.toString();

    if (mensagem.startsWith('Exception: ')) {
      mensagem = mensagem.substring('Exception: '.length);
    }

    return mensagem;
  }

  String? _buscarPedidoExistente() {
    final possibilidades = [_dados['pedidoId'], _dados['pedido_id']];

    for (final valor in possibilidades) {
      final id = valor?.toString().trim();

      if (id != null && id.isNotEmpty) {
        return id;
      }
    }

    return null;
  }

  String? _buscarEnderecoId() {
    final direto = _dados['enderecoId']?.toString().trim();

    if (direto != null && direto.isNotEmpty) {
      return direto;
    }

    final endereco = _dados['endereco'];

    if (endereco is Map) {
      final mapa = Map<String, dynamic>.from(endereco);

      final id = (mapa['enderecoId'] ?? mapa['id'])?.toString().trim();

      if (id != null && id.isNotEmpty) {
        return id;
      }
    }

    return null;
  }

  String? _buscarSessaoMesaId() {
    final possibilidades = [
      _dados['sessaoMesaId'],
      _dados['sessao_mesa_id'],
      _dados['sessaoId'],
    ];

    for (final valor in possibilidades) {
      final id = valor?.toString().trim();

      if (id != null && id.isNotEmpty) {
        return id;
      }
    }

    final mesa = _dados['mesa'];

    if (mesa is Map) {
      final mapa = Map<String, dynamic>.from(mesa);

      final id =
          (mapa['sessaoMesaId'] ?? mapa['sessao_mesa_id'] ?? mapa['sessaoId'])
              ?.toString()
              .trim();

      if (id != null && id.isNotEmpty) {
        return id;
      }
    }

    return null;
  }

  Future<Map<String, dynamic>> _criarPedido() async {
    switch (_tipoPedido) {
      case 'delivery':
        final enderecoId = _buscarEnderecoId();

        if (enderecoId == null) {
          throw Exception(
            'Endereço inválido. Volte para a sacola '
            'e selecione o endereço novamente.',
          );
        }

        return _pedidoRepository.criarPedidoDelivery(enderecoId: enderecoId);

      case 'mesa':
        final sessaoMesaId = _buscarSessaoMesaId();

        if (sessaoMesaId == null) {
          throw Exception('Sessão da mesa não encontrada.');
        }

        return _pedidoRepository.criarPedidoMesa(sessaoMesaId: sessaoMesaId);

      case 'retirada':
      default:
        return _pedidoRepository.criarPedidoRetirada();
    }
  }

  Future<void> _adicionarItens(String pedidoId) async {
    final itens = _carrinhoRepository.itens;

    if (itens.isEmpty) {
      throw Exception('Seu carrinho está vazio.');
    }

    for (final item in itens) {
      await _pedidoRepository.adicionarItem(
        pedidoId: pedidoId,
        produtoId: item.produto.id.toString(),
        quantidade: item.quantidade,
        observacao: item.observacao.trim().isEmpty
            ? null
            : item.observacao.trim(),
      );
    }
  }

  // ============================================================
  // PREPARAR PAGAMENTO PIX
  // ============================================================

  Future<void> _prepararPagamentoPix() async {
    if (_processando || _pagamentoCriado || _pagamentoConfirmado) {
      return;
    }

    setState(() {
      _processando = true;
      _erro = null;
    });

    try {
      String? pedidoId = _pedidoId;

      // Cria o pedido somente se ainda nao existir.
      if (pedidoId == null) {
        final pedido = await _criarPedido();

        pedidoId = pedido['id']?.toString();

        if (pedidoId == null || pedidoId.isEmpty) {
          throw Exception('O servidor não retornou o ID do pedido.');
        }

        _pedidoId = pedidoId;
      }

      // Adiciona os itens somente uma vez nesta tela.
      // Se o pedido veio de outra tela, considera
      // que seus itens ja foram preparados.
      if (!_itensAdicionados) {
        if (_buscarPedidoExistente() == null) {
          await _adicionarItens(pedidoId);
        }

        _itensAdicionados = true;
      }

      // IMPORTANTE:
      // Nao chama enviarPedido() aqui.
      // O pedido so sera confirmado apos o pagamento.

      final resposta = await _pagamentoRepository.criarPagamentoPix(
        pedidoId: pedidoId,
        idempotencyKey: 'pix-$pedidoId',
      );

      final dynamic objeto = resposta['pagamento'] ?? resposta;

      if (objeto is! Map) {
        throw Exception('Resposta inválida ao preparar o Pix.');
      }

      final pagamento = Map<String, dynamic>.from(objeto);

      final pagamentoId = pagamento['id']?.toString();

      if (pagamentoId == null || pagamentoId.isEmpty) {
        throw Exception('O servidor não retornou o ID do pagamento.');
      }

      if (!mounted) return;

      setState(() {
        _pedidoId = pedidoId;
        _pagamentoId = pagamentoId;
        _pagamentoCriado = true;
        _erro = null;
      });
    } catch (erro) {
      if (!mounted) return;

      setState(() {
        _erro = _limparErro(erro);
      });
    } finally {
      if (mounted) {
        setState(() {
          _processando = false;
        });
      }
    }
  }

  // ============================================================
  // CONFIRMAR PAGAMENTO DEMONSTRATIVO
  // ============================================================

  Future<void> _confirmarPagamentoDemonstrativo() async {
    if (_confirmando ||
        _pagamentoConfirmado ||
        _pagamentoId == null ||
        _pedidoId == null) {
      return;
    }

    setState(() {
      _confirmando = true;
      _erro = null;
    });

    try {
      var resultado = await _pagamentoRepository.consultarStatusPix(
        _pagamentoId!,
      );

      var status = resultado['statusPagamentoPedido']
          ?.toString()
          .trim()
          .toLowerCase();

      // Simula a confirmacao apenas se ainda nao estiver pago.
      if (status != 'pago') {
        try {
          await _pagamentoRepository.confirmarPagamento(_pagamentoId!);
        } catch (erro) {
          debugPrint('Erro na confirmação do Pix: $erro');
        }

        resultado = await _pagamentoRepository.consultarStatusPix(
          _pagamentoId!,
        );

        status = resultado['statusPagamentoPedido']
            ?.toString()
            .trim()
            .toLowerCase();
      }

      if (status != 'pago') {
        throw Exception(
          'O pagamento ainda não foi confirmado. '
          'Verifique o status antes de continuar.',
        );
      }

      // O pagamento demonstrativo foi aprovado.
      // Agora o pedido pode ser confirmado.
      await _pedidoRepository.confirmarPedido(_pedidoId!);

      if (!mounted) return;

      setState(() {
        _pagamentoConfirmado = true;
        _erro = null;
      });

      _abrirStatusPedido();
    } catch (erro) {
      if (!mounted) return;

      setState(() {
        _erro = _limparErro(erro);
      });
    } finally {
      if (mounted) {
        setState(() {
          _confirmando = false;
        });
      }
    }
  }

  // ============================================================
  // ABRIR STATUS DO PEDIDO
  // ============================================================

  void _abrirStatusPedido() {
    if (!mounted || _redirecionando || _pedidoId == null) {
      return;
    }

    _redirecionando = true;

    _carrinhoRepository.limpar();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            StatusPedidoTela(tipoPedido: _tipoPedido, pedidoId: _pedidoId!),
      ),
    );
  }

  // ============================================================
  // INTERFACE
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pix demonstrativo')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 76,
                  color: AppColors.green,
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Pagamento Pix de demonstração',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),

              const SizedBox(height: 12),

              const Text(
                'Este é um pagamento fictício para '
                'apresentação do SaborExpress. '
                'Nenhum dinheiro será transferido.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.mutedText),
              ),

              const SizedBox(height: 28),

              Text(
                _tipoPedido == 'delivery'
                    ? 'Pedido para entrega'
                    : _tipoPedido == 'mesa'
                    ? 'Pagamento da mesa'
                    : 'Pedido para retirada',
                style: const TextStyle(color: AppColors.mutedText),
              ),

              const SizedBox(height: 12),

              const Text(
                'Valor do pedido',
                style: TextStyle(color: AppColors.mutedText),
              ),

              const SizedBox(height: 6),

              Text(
                Formatters.money(_total),
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: AppColors.green,
                ),
              ),

              const SizedBox(height: 28),

              if (_processando) ...[
                const CircularProgressIndicator(color: AppColors.green),
                const SizedBox(height: 14),
                const Text(
                  'Preparando pagamento demonstrativo...',
                  textAlign: TextAlign.center,
                ),
              ],

              if (_pagamentoCriado && !_pagamentoConfirmado) ...[
                const Icon(
                  Icons.check_circle_outline,
                  color: AppColors.green,
                  size: 40,
                ),

                const SizedBox(height: 12),

                const Text(
                  'Pagamento demonstrativo preparado',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _confirmando
                        ? null
                        : _confirmarPagamentoDemonstrativo,
                    icon: _confirmando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(
                      _confirmando
                          ? 'Confirmando...'
                          : 'Confirmar pagamento demonstrativo',
                    ),
                  ),
                ),
              ],

              if (_pagamentoConfirmado) ...[
                const Icon(
                  Icons.check_circle,
                  color: AppColors.green,
                  size: 64,
                ),
                const SizedBox(height: 12),
                const Text('Pagamento confirmado!'),
              ],

              if (_erro != null) ...[
                const SizedBox(height: 18),

                Text(
                  _erro!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),

                const SizedBox(height: 12),

                if (!_pagamentoCriado)
                  OutlinedButton.icon(
                    onPressed: _processando ? null : _prepararPagamentoPix,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Tentar novamente'),
                  ),
              ],

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
