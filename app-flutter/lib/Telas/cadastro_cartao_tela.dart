import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../Repositories/carrinho_repository.dart';
import '../Repositories/pedido_repository.dart';
import 'status_pedido_tela.dart';

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

  static const Color _vinho = Color(0xFF79252F);
  static const Color _creme = Color(0xFFFFFAF5);
  static const Color _verde = Color(0xFF168B25);

  bool _processando = false;
  bool _argumentosCarregados = false;
  bool _itensAdicionados = false;
  bool _pedidoEnviado = false;

  String _tipoCartao = 'credito';
  String? _pedidoIdAtual;
  String? _pagamentoIdAtual;

  Map<String, dynamic> _dados = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_argumentosCarregados) return;
    _argumentosCarregados = true;

    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is Map) {
      _dados = Map<String, dynamic>.from(args);
      _pedidoIdAtual = _buscarPedidoExistente();

      if (_pedidoIdAtual != null) {
        _itensAdicionados = true;

        final status = (_dados['status'] ?? _dados['pedidoStatus'] ?? '')
            .toString()
            .toLowerCase();

        _pedidoEnviado =
            status == 'confirmado' ||
            status == 'em_preparo' ||
            status == 'pronto' ||
            status == 'entregue' ||
            status == 'concluido';
      }
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

    if (tipo.contains('delivery') || tipo.contains('entrega')) {
      return 'delivery';
    }

    if (tipo.contains('mesa')) return 'mesa';

    return 'retirada';
  }

  double get _total {
    final valor = _dados['total'];

    if (valor is num) return valor.toDouble();

    return _carrinhoRepository.subtotal;
  }

  String get _totalFormatado {
    return 'R\$ ${_total.toStringAsFixed(2).replaceAll('.', ',')}';
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
      _dados['sessao_id'],
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
          (mapa['sessaoMesaId'] ??
                  mapa['sessao_mesa_id'] ??
                  mapa['sessao_id'] ??
                  mapa['sessaoId'])
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
            'Selecione novamente o endereço de entrega na sacola.',
          );
        }

        return _pedidoRepository.criarPedidoDelivery(enderecoId: enderecoId);

      case 'mesa':
        final sessaoMesaId = _buscarSessaoMesaId();

        if (sessaoMesaId == null) {
          throw Exception('Selecione novamente a mesa na sacola.');
        }

        return _pedidoRepository.criarPedidoMesa(sessaoMesaId: sessaoMesaId);

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

  bool _validarCampos() {
    final numero = numeroController.text.replaceAll(RegExp(r'\D'), '');
    final cvv = cvvController.text.replaceAll(RegExp(r'\D'), '');
    final validade = validadeController.text.trim();

    String? erro;

    if (numeroController.text.trim().isEmpty ||
        nomeController.text.trim().isEmpty ||
        validade.isEmpty ||
        cvvController.text.trim().isEmpty) {
      erro = 'Preencha todos os campos do cartão de demonstração.';
    } else if (numero.length < 13 || numero.length > 19) {
      erro = 'Informe um número fictício com 13 a 19 dígitos.';
    } else if (!RegExp(r'^\d{2}/\d{2}$').hasMatch(validade)) {
      erro = 'Informe a validade no formato MM/AA.';
    } else if (int.parse(validade.substring(0, 2)) < 1 ||
        int.parse(validade.substring(0, 2)) > 12) {
      erro = 'Informe um mês de validade válido.';
    } else if (cvv.length < 3 || cvv.length > 4) {
      erro = 'Informe um CVV fictício com 3 ou 4 dígitos.';
    }

    if (erro != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(erro), backgroundColor: _vinho));

      return false;
    }

    return true;
  }

  Future<void> _finalizarPagamento() async {
    if (_processando || !_validarCampos()) return;

    setState(() => _processando = true);

    try {
      String? pedidoId = _pedidoIdAtual;

      if (pedidoId == null) {
        final pedido = await _criarPedido();

        pedidoId = (pedido['id'] ?? pedido['pedido_id'])?.toString();

        if (pedidoId == null || pedidoId.isEmpty) {
          throw Exception('O servidor não retornou o identificador do pedido.');
        }

        _pedidoIdAtual = pedidoId;
      }

      if (!_itensAdicionados) {
        await _adicionarItens(pedidoId);
        _itensAdicionados = true;
      }

      final metodo = _tipoCartao == 'debito'
          ? 'cartao_debito'
          : 'cartao_credito';

      String? pagamentoId = _pagamentoIdAtual;

      if (pagamentoId == null) {
        final resposta = await _pedidoRepository.criarPagamento(
          pedidoId: pedidoId,
          metodo: metodo,
          idempotencyKey: 'cartao-$metodo-$pedidoId',
        );

        final dynamic objeto = resposta['pagamento'] ?? resposta;

        if (objeto is! Map) {
          throw Exception('Resposta inválida ao criar o pagamento.');
        }

        final pagamento = Map<String, dynamic>.from(objeto);

        pagamentoId = (pagamento['id'] ?? pagamento['pagamento_id'])
            ?.toString();

        if (pagamentoId == null || pagamentoId.isEmpty) {
          throw Exception(
            'O servidor não retornou o identificador do pagamento.',
          );
        }

        _pagamentoIdAtual = pagamentoId;
      }

      String statusPagamento = '';

      try {
        final resultado = await _pedidoRepository.confirmarPagamento(
          pagamentoId,
        );

        statusPagamento =
            resultado['statusPagamentoPedido']
                ?.toString()
                .trim()
                .toLowerCase() ??
            '';
      } catch (erro) {
        final mensagem = erro.toString().toLowerCase();

        if (mensagem.contains('pagamento ja esta aprovado') ||
            mensagem.contains('pagamento já está aprovado')) {
          statusPagamento = 'pago';
        } else {
          rethrow;
        }
      }

      if (statusPagamento != 'pago') {
        throw Exception('O pagamento demonstrativo ainda não foi aprovado.');
      }

      if (!_pedidoEnviado) {
        try {
          await _pedidoRepository.enviarPedido(pedidoId);
          _pedidoEnviado = true;
        } catch (erro) {
          throw Exception(
            'Pagamento demonstrativo aprovado, mas o pedido não foi '
            'confirmado no servidor. Não faça outro pagamento. '
            'Pedido: $pedidoId. Detalhe: ${_limparErro(erro)}',
          );
        }
      }

      if (!mounted) return;

      _carrinhoRepository.limpar();

      // Abre a mesma tela de acompanhamento utilizada pelo Pix.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              StatusPedidoTela(tipoPedido: _tipoPedido, pedidoId: pedidoId!),
        ),
      );
    } catch (erro) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_limparErro(erro)),
          backgroundColor: _vinho,
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _processando = false);
      }
    }
  }

  String _numeroMascarado() {
    final numero = numeroController.text.replaceAll(RegExp(r'\D'), '');

    if (numero.isEmpty) return '••••  ••••  ••••  1234';

    final ultimos = numero.length <= 4
        ? numero
        : numero.substring(numero.length - 4);

    return '••••  ••••  ••••  $ultimos';
  }

  // ============================================================
  // INTERFACE PRINCIPAL
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _creme,
      appBar: AppBar(
        backgroundColor: _verde,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Pagamento com cartão',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: _processando ? null : () => Navigator.pop(context),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 18),
            child: Icon(Icons.credit_card_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // TÍTULO
                        Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE5F3E7),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.credit_card_rounded,
                                color: _verde,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Pague com cartão',
                                    style: TextStyle(
                                      fontSize: 23,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF292929),
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Pagamento antecipado pelo aplicativo',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF777777),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 26),

                        // CARTÃO VIRTUAL
                        _cartaoVirtual(),

                        const SizedBox(height: 28),

                        // SELEÇÃO DO TIPO
                        const Text(
                          'Tipo do cartão',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF292929),
                          ),
                        ),

                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: _botaoTipoCartao(
                                titulo: 'Crédito',
                                tipo: 'credito',
                                icone: Icons.credit_card_rounded,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _botaoTipoCartao(
                                titulo: 'Débito',
                                tipo: 'debito',
                                icone: Icons.payment_rounded,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 28),

                        // DADOS DO CARTÃO
                        const Text(
                          'Dados do cartão',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF292929),
                          ),
                        ),

                        const SizedBox(height: 6),

                        const Text(
                          'Utilize apenas informações fictícias para testar.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF777777),
                          ),
                        ),

                        const SizedBox(height: 20),

                        _campoCartao(
                          titulo: 'Número do cartão',
                          dica: '0000 0000 0000 0000',
                          controller: numeroController,
                          icone: Icons.credit_card_outlined,
                          tipoTeclado: TextInputType.number,
                          formatadores: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(16),
                            _FormatadorNumeroCartao(),
                          ],
                          aoAlterar: (_) => setState(() {}),
                        ),

                        const SizedBox(height: 18),

                        _campoCartao(
                          titulo: 'Nome no cartão',
                          dica: 'Nome do titular fictício',
                          controller: nomeController,
                          icone: Icons.person_outline_rounded,
                          tipoTeclado: TextInputType.name,
                          formatadores: [LengthLimitingTextInputFormatter(50)],
                          aoAlterar: (_) => setState(() {}),
                        ),

                        const SizedBox(height: 18),

                        Row(
                          children: [
                            Expanded(
                              child: _campoCartao(
                                titulo: 'Validade',
                                dica: 'MM/AA',
                                controller: validadeController,
                                icone: Icons.calendar_month_outlined,
                                tipoTeclado: TextInputType.number,
                                formatadores: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(4),
                                  _FormatadorValidade(),
                                ],
                                aoAlterar: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _campoCartao(
                                titulo: 'CVV',
                                dica: '123',
                                controller: cvvController,
                                icone: Icons.lock_outline_rounded,
                                tipoTeclado: TextInputType.number,
                                ocultar: true,
                                formatadores: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(4),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 26),

                        // AVISO DE SIMULAÇÃO
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF5EB),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFCBE5CE)),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.verified_user_outlined,
                                color: _verde,
                                size: 27,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Pagamento demonstrativo',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                        color: _verde,
                                      ),
                                    ),
                                    SizedBox(height: 5),
                                    Text(
                                      'Este pagamento é uma simulação '
                                      'para apresentação do SaborExpress. '
                                      'Nenhum valor será cobrado e os dados '
                                      'do cartão não serão enviados para pagamento.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        height: 1.5,
                                        color: Color(0xFF4D6852),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 22),

                        // RESUMO
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFEAE5DF)),
                          ),
                          child: Column(
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.receipt_long_outlined,
                                    color: _vinho,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Resumo do pagamento',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Divider(height: 1),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total do pedido',
                                    style: TextStyle(color: Color(0xFF666666)),
                                  ),
                                  Text(
                                    _totalFormatado,
                                    style: const TextStyle(
                                      color: _verde,
                                      fontSize: 21,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // BOTÃO FIXO
            _rodapePagamento(),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CARTÃO VIRTUAL VINHO
  // ============================================================

  Widget _cartaoVirtual() {
    final nome = nomeController.text.trim().isEmpty
        ? 'NOME DO TITULAR'
        : nomeController.text.trim().toUpperCase();

    final validade = validadeController.text.trim().isEmpty
        ? 'MM/AA'
        : validadeController.text.trim();

    return Container(
      width: double.infinity,
      height: 205,
      padding: const EdgeInsets.all(23),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF9A3945), Color(0xFF79252F), Color(0xFF511821)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _vinho.withValues(alpha: 0.23),
            blurRadius: 20,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -25,
            top: -40,
            child: Icon(
              Icons.restaurant_menu_rounded,
              size: 190,
              color: Colors.white.withValues(alpha: 0.07),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 42,
                    height: 31,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9C66A),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: const Color(0xFFF7E2A1)),
                    ),
                    child: const Icon(
                      Icons.grid_view_rounded,
                      size: 22,
                      color: Color(0xFFB58A35),
                    ),
                  ),
                  const Icon(
                    Icons.contactless_rounded,
                    color: Colors.white,
                    size: 29,
                  ),
                ],
              ),

              const Spacer(),

              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  _numeroMascarado(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
              ),

              const SizedBox(height: 19),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TITULAR',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 9,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          nome,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'VALIDADE',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 9,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        validade,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BOTÕES DE CRÉDITO E DÉBITO
  // ============================================================

  Widget _botaoTipoCartao({
    required String titulo,
    required String tipo,
    required IconData icone,
  }) {
    final selecionado = _tipoCartao == tipo;

    return InkWell(
      onTap: _processando
          ? null
          : () {
              setState(() {
                _tipoCartao = tipo;
              });
            },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selecionado ? const Color(0xFFE5F3E7) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selecionado ? _verde : const Color(0xFFE2DED8),
            width: selecionado ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selecionado ? Icons.check_circle_rounded : icone,
              color: selecionado ? _verde : const Color(0xFF777777),
              size: 21,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                titulo,
                style: TextStyle(
                  color: selecionado ? _verde : const Color(0xFF555555),
                  fontWeight: selecionado ? FontWeight.w800 : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CAMPOS DO CARTÃO
  // ============================================================

  Widget _campoCartao({
    required String titulo,
    required String dica,
    required TextEditingController controller,
    IconData? icone,
    TextInputType? tipoTeclado,
    bool ocultar = false,
    List<TextInputFormatter>? formatadores,
    ValueChanged<String>? aoAlterar,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            color: Color(0xFF333333),
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 9),
        TextField(
          controller: controller,
          enabled: !_processando,
          obscureText: ocultar,
          keyboardType: tipoTeclado,
          inputFormatters: formatadores,
          onChanged: aoAlterar,
          style: const TextStyle(fontSize: 15, color: Color(0xFF333333)),
          decoration: InputDecoration(
            hintText: dica,
            hintStyle: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 14),
            prefixIcon: icone == null
                ? null
                : Icon(icone, color: _vinho, size: 21),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 17,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE5E0DA)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _verde, width: 1.5),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE5E0DA)),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // RODAPÉ FIXO
  // ============================================================

  Widget _rodapePagamento() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFECE8E3))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _processando ? null : _finalizarPagamento,
              style: ElevatedButton.styleFrom(
                backgroundColor: _verde,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _verde.withValues(alpha: 0.6),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              icon: _processando
                  ? const SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.lock_outline_rounded),
              label: Text(
                _processando
                    ? 'Processando pagamento...'
                    : 'Finalizar pagamento • $_totalFormatado',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// FORMATADOR DO NÚMERO DO CARTÃO
// ============================================================

class _FormatadorNumeroCartao extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final numeros = newValue.text.replaceAll(RegExp(r'\D'), '');

    final limitado = numeros.length > 16 ? numeros.substring(0, 16) : numeros;

    final buffer = StringBuffer();

    for (int i = 0; i < limitado.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write(' ');
      }

      buffer.write(limitado[i]);
    }

    final texto = buffer.toString();

    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}

// ============================================================
// FORMATADOR DA VALIDADE
// ============================================================

class _FormatadorValidade extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final numeros = newValue.text.replaceAll(RegExp(r'\D'), '');

    final limitado = numeros.length > 4 ? numeros.substring(0, 4) : numeros;

    String texto = limitado;

    if (limitado.length > 2) {
      texto = '${limitado.substring(0, 2)}/${limitado.substring(2)}';
    }

    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}
