import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../Repositories/carrinho_repository.dart';
import '../Repositories/pedido_repository.dart';
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

  final PedidoRepository _pedidoRepository = PedidoRepository();
  final CarrinhoRepository _carrinhoRepository = CarrinhoRepository.instance;

  bool _processando = false;
  String _tipoCartao = 'credito';
  Map<String, dynamic> _dados = {};
  bool _argumentosCarregados = false;

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

  @override
  void dispose() {
    numeroController.dispose();
    nomeController.dispose();
    validadeController.dispose();
    cvvController.dispose();
    super.dispose();
  }

  String get _tipoPedido {
    final tipo = (_dados['tipoPedido'] ?? _dados['tipo'] ?? 'retirada')
        .toString()
        .toLowerCase();
    if (tipo.contains('delivery') || tipo.contains('entrega'))
      return 'delivery';
    if (tipo.contains('mesa')) return 'mesa';
    return 'retirada';
  }

  double get _total {
    final valor = _dados['total'];
    if (valor is num) return valor.toDouble();
    return _carrinhoRepository.subtotal;
  }

  String _limparErro(Object erro) {
    var mensagem = erro.toString();
    if (mensagem.startsWith('Exception: ')) {
      mensagem = mensagem.substring('Exception: '.length);
    }
    return mensagem;
  }

  String? _buscarEnderecoId() {
    final direto = _dados['enderecoId']?.toString().trim();
    if (direto != null && direto.isNotEmpty) return direto;
    final endereco = _dados['endereco'];
    if (endereco is Map) {
      final mapa = Map<String, dynamic>.from(endereco);
      final id = (mapa['enderecoId'] ?? mapa['id'])?.toString().trim();
      if (id != null && id.isNotEmpty) return id;
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
      if (id != null && id.isNotEmpty) return id;
    }
    final mesa = _dados['mesa'];
    if (mesa is Map) {
      final mapa = Map<String, dynamic>.from(mesa);
      final id =
          (mapa['sessaoMesaId'] ?? mapa['sessao_mesa_id'] ?? mapa['sessaoId'])
              ?.toString()
              .trim();
      if (id != null && id.isNotEmpty) return id;
    }
    return null;
  }

  String? _buscarPedidoExistente() {
    for (final valor in [_dados['pedidoId'], _dados['pedido_id']]) {
      final id = valor?.toString().trim();
      if (id != null && id.isNotEmpty) return id;
    }
    return null;
  }

  Future<Map<String, dynamic>> _criarPedido() async {
    switch (_tipoPedido) {
      case 'delivery':
        final enderecoId = _buscarEnderecoId();
        if (enderecoId == null) {
          throw Exception(
            'O endereço de entrega não possui um identificador válido. Volte para a sacola e selecione o endereço novamente.',
          );
        }
        return _pedidoRepository.criarPedidoDelivery(enderecoId: enderecoId);
      case 'mesa':
        final sessaoMesaId = _buscarSessaoMesaId();
        if (sessaoMesaId == null) {
          throw Exception(
            'A sessão da mesa não foi encontrada. Volte para a sacola e selecione a mesa novamente.',
          );
        }
        return _pedidoRepository.criarPedidoMesa(sessaoMesaId: sessaoMesaId);
      default:
        return _pedidoRepository.criarPedidoRetirada();
    }
  }

  Future<void> _adicionarItens(String pedidoId) async {
    final itens = _carrinhoRepository.itens;
    if (itens.isEmpty) throw Exception('Seu carrinho está vazio.');
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

  bool _validarCampos() {
    if (numeroController.text.trim().isEmpty ||
        nomeController.text.trim().isEmpty ||
        validadeController.text.trim().isEmpty ||
        cvvController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha os dados do cartão')),
      );
      return false;
    }
    final numero = numeroController.text.replaceAll(RegExp(r'\D'), '');
    final cvv = cvvController.text.replaceAll(RegExp(r'\D'), '');
    if (numero.length < 13 || numero.length > 19) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um número de cartão válido')),
      );
      return false;
    }
    if (cvv.length < 3 || cvv.length > 4) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Informe um CVV válido')));
      return false;
    }
    return true;
  }

  Future<void> _finalizarPagamento() async {
    if (_processando || !_validarCampos()) return;
    setState(() => _processando = true);
    try {
      String? pedidoId = _buscarPedidoExistente();
      if (pedidoId == null) {
        final pedido = await _criarPedido();
        pedidoId = pedido['id']?.toString();
        if (pedidoId == null || pedidoId.isEmpty) {
          throw Exception('O servidor não retornou o identificador do pedido.');
        }
        await _adicionarItens(pedidoId);
        await _pedidoRepository.confirmarPedido(pedidoId);
      }

      final metodo = _tipoCartao == 'debito'
          ? 'cartao_debito'
          : 'cartao_credito';
      final pagamento = await _pedidoRepository.criarPagamento(
        pedidoId: pedidoId,
        metodo: metodo,
        idempotencyKey: 'cartao-$metodo-$pedidoId',
      );
      final pagamentoId = pagamento['id']?.toString();
      if (pagamentoId == null || pagamentoId.isEmpty) {
        throw Exception(
          'O servidor não retornou o identificador do pagamento.',
        );
      }

      final resultado = await _pedidoRepository.confirmarPagamento(pagamentoId);
      final statusPagamento =
          resultado['statusPagamentoPedido']?.toString() ?? 'pago';

      final dadosSucesso = <String, dynamic>{
        ..._dados,
        'pedidoId': pedidoId,
        'pagamentoId': pagamentoId,
        'tipoPedido': _tipoPedido,
        'formaPagamento': _tipoCartao == 'debito'
            ? 'Cartão de débito'
            : 'Cartão de crédito',
        'pagamento': _tipoCartao == 'debito'
            ? 'Cartão de débito'
            : 'Cartão de crédito',
        'statusPagamento': statusPagamento,
        'pagamentoAprovado': true,
        'total': _total,
      };

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
      if (mounted) setState(() => _processando = false);
    }
  }

  String _numeroMascarado() {
    final numero = numeroController.text.replaceAll(RegExp(r'\D'), '');
    if (numero.isEmpty) return '**** **** **** 1234';
    final ultimos = numero.length <= 4
        ? numero
        : numero.substring(numero.length - 4);
    return '**** **** **** $ultimos';
  }

  @override
  Widget build(BuildContext context) {
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.credit_card,
                            color: Colors.white,
                            size: 40,
                          ),
                          const Spacer(),
                          Text(
                            _numeroMascarado(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            nomeController.text.trim().isEmpty
                                ? 'NOME DO TITULAR'
                                : nomeController.text.trim().toUpperCase(),
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
                    const Text(
                      'Tipo do cartão',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Crédito'),
                            selected: _tipoCartao == 'credito',
                            onSelected: _processando
                                ? null
                                : (_) =>
                                      setState(() => _tipoCartao = 'credito'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Débito'),
                            selected: _tipoCartao == 'debito',
                            onSelected: _processando
                                ? null
                                : (_) => setState(() => _tipoCartao = 'debito'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _campo(
                      label: 'Número do cartão',
                      hint: '0000 0000 0000 0000',
                      controller: numeroController,
                      icon: Icons.credit_card,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    _campo(
                      label: 'Nome no cartão',
                      hint: 'Digite o nome do titular',
                      controller: nomeController,
                      icon: Icons.person_outline,
                      onChanged: (_) => setState(() {}),
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
                  icon: _processando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.lock_outline),
                  label: Text(
                    _processando
                        ? 'Processando pagamento...'
                        : 'Finalizar pagamento',
                  ),
                  onPressed: _processando ? null : _finalizarPagamento,
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
    ValueChanged<String>? onChanged,
    List<TextInputFormatter>? inputFormatters,
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
          enabled: !_processando,
          onChanged: onChanged,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon == null ? null : Icon(icon),
          ),
        ),
      ],
    );
  }
}

class _CartaoInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final numeros = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < numeros.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(numeros[i]);
    }
    final texto = buffer.toString();
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}
