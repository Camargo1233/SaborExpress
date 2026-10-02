import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../Repositories/carrinho_repository.dart';
import '../Repositories/pedido_repository.dart';
import '../utils/app_colors.dart';
import '../utils/formatters.dart';

class PixTela extends StatefulWidget {
  const PixTela({super.key});

  @override
  State<PixTela> createState() => _PixTelaState();
}

class _PixTelaState extends State<PixTela> {
  final PedidoRepository _pedidoRepository = PedidoRepository();
  final CarrinhoRepository _carrinhoRepository = CarrinhoRepository.instance;

  bool _processando = false;
  bool _pagamentoCriado = false;

  String? _pedidoId;
  String? _pagamentoId;
  String? _codigoPix;

  Map<String, dynamic> _dados = {};
  bool _argumentosCarregados = false;

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

    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is Map) {
      _dados = Map<String, dynamic>.from(args);
    }
  }

  // ============================================================
  // UTILITÁRIOS
  // ============================================================

  String _limparErro(Object erro) {
    var mensagem = erro.toString();

    if (mensagem.startsWith('Exception: ')) {
      mensagem = mensagem.substring('Exception: '.length);
    }

    return mensagem;
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

  // ============================================================
  // CRIAR PEDIDO
  // ============================================================

  Future<Map<String, dynamic>> _criarPedido() async {
    switch (_tipoPedido) {
      case 'delivery':
        final enderecoId = _buscarEnderecoId();

        if (enderecoId == null) {
          throw Exception(
            'O endereço de entrega não possui um '
            'identificador válido. Volte para a sacola '
            'e selecione o endereço novamente.',
          );
        }

        return _pedidoRepository.criarPedidoDelivery(enderecoId: enderecoId);

      case 'mesa':
        final sessaoMesaId = _buscarSessaoMesaId();

        if (sessaoMesaId == null) {
          throw Exception(
            'A sessão da mesa não foi encontrada. '
            'Volte para a sacola e selecione a mesa novamente.',
          );
        }

        return _pedidoRepository.criarPedidoMesa(sessaoMesaId: sessaoMesaId);

      case 'retirada':
      default:
        return _pedidoRepository.criarPedidoRetirada();
    }
  }

  // ============================================================
  // ADICIONAR ITENS
  // ============================================================

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
  // PREPARAR PEDIDO + PIX
  // ============================================================

  Future<void> _prepararPagamentoPix() async {
    if (_processando || _pagamentoCriado) {
      return;
    }

    setState(() {
      _processando = true;
    });

    try {
      // --------------------------------------------------------
      // 1. Verifica se a Sacola já enviou um pedido real.
      // --------------------------------------------------------

      String? pedidoId = _buscarPedidoExistente();

      // --------------------------------------------------------
      // 2. Caso não exista, cria o pedido.
      // --------------------------------------------------------

      if (pedidoId == null) {
        final pedido = await _criarPedido();

        pedidoId = pedido['id']?.toString();

        if (pedidoId == null || pedidoId.isEmpty) {
          throw Exception('O servidor não retornou o identificador do pedido.');
        }

        // ------------------------------------------------------
        // 3. Adiciona os produtos.
        // ------------------------------------------------------

        await _adicionarItens(pedidoId);

        // ------------------------------------------------------
        // 4. Confirma o pedido.
        //
        // Retirada:
        // backend coloca em em_preparo.
        //
        // Delivery:
        // segue o fluxo definido no backend.
        //
        // Mesa:
        // segue o fluxo da comanda.
        // ------------------------------------------------------

        await _pedidoRepository.confirmarPedido(pedidoId);
      }

      // --------------------------------------------------------
      // 5. Cria pagamento Pix.
      //
      // Não enviamos "valor", então o backend cobra
      // automaticamente todo o saldo restante do pedido.
      // --------------------------------------------------------

      final pagamento = await _pedidoRepository.criarPagamentoPix(
        pedidoId: pedidoId,
        idempotencyKey: 'pix-$pedidoId',
      );

      final pagamentoId = pagamento['id']?.toString();

      if (pagamentoId == null || pagamentoId.isEmpty) {
        throw Exception(
          'O servidor não retornou o identificador do pagamento.',
        );
      }

      final codigoPix = pagamento['qr_code']?.toString();

      if (!mounted) return;

      setState(() {
        _pedidoId = pedidoId;
        _pagamentoId = pagamentoId;

        _codigoPix = codigoPix == null || codigoPix.isEmpty
            ? 'PIX-MOCK-$pedidoId'
            : codigoPix;

        _pagamentoCriado = true;
      });
    } catch (erro) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_limparErro(erro)), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _processando = false;
        });
      }
    }
  }

  // ============================================================
  // CONFIRMAR PAGAMENTO
  // ============================================================

  Future<void> _confirmarPagamento() async {
    if (_processando) return;

    if (!_pagamentoCriado || _pagamentoId == null || _pedidoId == null) {
      await _prepararPagamentoPix();

      if (!_pagamentoCriado || _pagamentoId == null || _pedidoId == null) {
        return;
      }
    }

    setState(() {
      _processando = true;
    });

    try {
      final resultado = await _pedidoRepository.confirmarPagamento(
        _pagamentoId!,
      );

      final statusPagamento =
          resultado['statusPagamentoPedido']?.toString() ?? 'pago';

      // --------------------------------------------------------
      // IMPORTANTE:
      //
      // NÃO chamamos:
      //
      // alterarStatus(
      //   status: 'concluido'
      // )
      //
      // Pagamento aprovado e pedido concluído são coisas
      // diferentes.
      // --------------------------------------------------------

      final dadosSucesso = <String, dynamic>{
        ..._dados,

        'pedidoId': _pedidoId,
        'pagamentoId': _pagamentoId,

        'tipoPedido': _tipoPedido,

        'formaPagamento': 'Pix',

        'pagamento': 'Pix',

        'statusPagamento': statusPagamento,

        'pagamentoAprovado': true,

        'total': _total,
      };

      // O pedido já foi criado, os itens enviados e o
      // pagamento aprovado. Agora podemos limpar o carrinho.
      _carrinhoRepository.limpar();

      if (!mounted) return;

      Navigator.pushReplacementNamed(
        context,
        '/cliente/pagamento-sucesso',
        arguments: dadosSucesso,
      );
    } catch (erro) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_limparErro(erro)), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _processando = false;
        });
      }
    }
  }

  // ============================================================
  // COPIAR PIX
  // ============================================================

  Future<void> _copiarPix() async {
    if (_codigoPix == null || _codigoPix!.isEmpty) {
      return;
    }

    await Clipboard.setData(ClipboardData(text: _codigoPix!));

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Código Pix copiado')));
  }

  // ============================================================
  // TELA
  // ============================================================

  @override
  Widget build(BuildContext context) {
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

              const SizedBox(height: 12),

              Text(
                _tipoPedido == 'delivery'
                    ? 'Pagamento do pedido para entrega'
                    : _tipoPedido == 'mesa'
                    ? 'Pagamento da mesa'
                    : 'Pagamento do pedido para retirada',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.mutedText),
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
                child: _processando && !_pagamentoCriado
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.green,
                        ),
                      )
                    : const Icon(
                        Icons.qr_code_2,
                        size: 190,
                        color: AppColors.text,
                      ),
              ),

              const SizedBox(height: 20),

              if (!_pagamentoCriado)
                OutlinedButton.icon(
                  icon: const Icon(Icons.pix),
                  label: Text(_processando ? 'Gerando Pix...' : 'Gerar Pix'),
                  onPressed: _processando ? null : _prepararPagamentoPix,
                )
              else
                OutlinedButton.icon(
                  icon: const Icon(Icons.copy),
                  label: const Text('Copiar código Pix'),
                  onPressed: _copiarPix,
                ),

              const SizedBox(height: 32),

              const Text(
                'Valor do pagamento',
                style: TextStyle(color: AppColors.mutedText),
              ),

              const SizedBox(height: 6),

              Text(
                Formatters.money(_total),
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
                  icon: _processando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(
                    _processando
                        ? 'Processando...'
                        : _pagamentoCriado
                        ? 'Confirmar pagamento'
                        : 'Gerar e confirmar pagamento',
                  ),
                  onPressed: _processando ? null : _confirmarPagamento,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
