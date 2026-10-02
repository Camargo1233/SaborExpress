import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../Repositories/carrinho_repository.dart';

import '../Repositories/pedido_repository.dart';

import '../utils/app_colors.dart';

import '../utils/formatters.dart';

class SacolaTela extends StatefulWidget {
  const SacolaTela({super.key});

  @override
  State<SacolaTela> createState() => _SacolaTelaState();
}

class _SacolaTelaState extends State<SacolaTela> {
  final PedidoRepository pedidoRepository = PedidoRepository();

  final CarrinhoRepository carrinho = CarrinhoRepository.instance;

  bool finalizandoPedido = false;

  TipoPedido tipoPedido = TipoPedido.delivery;

  String pagamento = 'Pix';

  // Forma escolhida quando o pagamento será feito no local.

  // Valores possíveis: Dinheiro, Cartão ou Pix.

  String? formaPagamentoLocal;

  String? formaPagamentoEntrega;
  double? trocoParaEntrega;

  double subtotal = 51;

  double entrega = 10;

  double total = 61;

  int quantidade = 2;

  // ============================================================

  // ENDEREÇO

  // ============================================================

  Map<String, dynamic>? enderecoSelecionado;

  bool carregandoEndereco = true;

  static const String _chaveEndereco = 'cliente_endereco_selecionado';

  // ============================================================

  // MESA

  // ============================================================

  Map<String, dynamic>? mesaSelecionada;

  String? get mesaId {
    return mesaSelecionada?['mesa_id']?.toString() ??
        mesaSelecionada?['id']?.toString();
  }

  String? get sessaoMesaId {
    return mesaSelecionada?['sessao_id']?.toString();
  }

  String? get numeroMesa {
    return mesaSelecionada?['numero']?.toString();
  }

  // ============================================================

  // INIT

  // ============================================================

  @override
  void initState() {
    super.initState();

    _carregarEnderecoSalvo();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is Map<String, dynamic>) {
      subtotal = (args['subtotal'] as num?)?.toDouble() ?? subtotal;

      entrega = (args['entrega'] as num?)?.toDouble() ?? entrega;

      total = (args['total'] as num?)?.toDouble() ?? total;

      quantidade = (args['quantidade'] as num?)?.toInt() ?? quantidade;
    }
  }

  String get tipoPedidoValor => tipoPedido.name;

  // ============================================================

  // CARREGAR ENDEREÇO SALVO

  // ============================================================

  Future<void> _carregarEnderecoSalvo() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final enderecoJson = prefs.getString(_chaveEndereco);

      if (enderecoJson != null && enderecoJson.isNotEmpty) {
        final dados = jsonDecode(enderecoJson);

        if (dados is Map) {
          enderecoSelecionado = Map<String, dynamic>.from(dados);
        }
      }
    } catch (_) {
      // Se houver algum problema com o endereço salvo,

      // a Sacola continua funcionando normalmente.
    }

    if (!mounted) {
      return;
    }

    setState(() {
      carregandoEndereco = false;
    });
  }

  // ============================================================

  // SALVAR ENDEREÇO NO CELULAR

  // ============================================================

  Future<void> _salvarEnderecoLocal(Map<String, dynamic> endereco) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_chaveEndereco, jsonEncode(endereco));
  }

  // ============================================================

  // ADICIONAR / MUDAR ENDEREÇO

  // ============================================================

  Future<void> _selecionarEndereco() async {
    final resultado = await Navigator.pushNamed(
      context,

      '/cliente/endereco',

      arguments: enderecoSelecionado,
    );

    if (!mounted) {
      return;
    }

    if (resultado is Map) {
      final novoEndereco = Map<String, dynamic>.from(resultado);

      await _salvarEnderecoLocal(novoEndereco);

      if (!mounted) {
        return;
      }

      setState(() {
        enderecoSelecionado = novoEndereco;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Endereço salvo com sucesso!')),
      );
    }
  }

  // ============================================================

  // SELECIONAR / RESERVAR MESA

  // ============================================================

  Future<void> _selecionarMesa() async {
    final resultado = await Navigator.pushNamed(context, '/cliente/mesa');

    if (!mounted) {
      return;
    }

    if (resultado is Map) {
      final mesa = Map<String, dynamic>.from(resultado);

      final id = mesa['mesa_id']?.toString() ?? mesa['id']?.toString();

      final sessaoId = mesa['sessao_id']?.toString();

      final numero = mesa['numero']?.toString();

      if (id == null || id.isEmpty || sessaoId == null || sessaoId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível identificar a reserva da mesa.'),
          ),
        );

        return;
      }

      setState(() {
        mesaSelecionada = {
          ...mesa,

          'mesa_id': id,

          'sessao_id': sessaoId,

          'status': 'ocupada',
        };
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            numero != null && numero.isNotEmpty
                ? 'Mesa $numero reservada com sucesso!'
                : 'Mesa reservada com sucesso!',
          ),

          backgroundColor: AppColors.green,
        ),
      );
    }
  }

  // ============================================================

  // PAGAR NO LOCAL

  // ============================================================

  Future<void> _selecionarPagamentoLocal() async {
    String? opcaoTemporaria = formaPagamentoLocal;

    final resultado = await showModalBottomSheet<String>(
      context: context,

      isScrollControlled: true,

      backgroundColor: Colors.transparent,

      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),

                decoration: const BoxDecoration(
                  color: Colors.white,

                  borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                ),

                child: Column(
                  mainAxisSize: MainAxisSize.min,

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Center(
                      child: Container(
                        width: 45,

                        height: 5,

                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,

                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    const Text(
                      'Pagamento no local',

                      style: TextStyle(
                        fontSize: 22,

                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 6),

                    const Text(
                      'Como você deseja pagar quando chegar ao estabelecimento?',

                      style: TextStyle(
                        color: AppColors.mutedText,

                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(height: 22),

                    _opcaoPagamentoLocal(
                      titulo: 'Dinheiro',

                      subtitulo: 'Pagamento em dinheiro no estabelecimento',

                      icone: Icons.payments_outlined,

                      selecionado: opcaoTemporaria == 'Dinheiro',

                      onTap: () {
                        setModalState(() {
                          opcaoTemporaria = 'Dinheiro';
                        });
                      },
                    ),

                    const SizedBox(height: 10),

                    _opcaoPagamentoLocal(
                      titulo: 'Cartão',

                      subtitulo: 'Crédito ou débito no estabelecimento',

                      icone: Icons.credit_card,

                      selecionado: opcaoTemporaria == 'Cartão',

                      onTap: () {
                        setModalState(() {
                          opcaoTemporaria = 'Cartão';
                        });
                      },
                    ),

                    const SizedBox(height: 10),

                    _opcaoPagamentoLocal(
                      titulo: 'Pix',

                      subtitulo: 'Pix realizado no momento da retirada',

                      icone: Icons.pix,

                      selecionado: opcaoTemporaria == 'Pix',

                      onTap: () {
                        setModalState(() {
                          opcaoTemporaria = 'Pix';
                        });
                      },
                    ),

                    const SizedBox(height: 22),

                    SizedBox(
                      width: double.infinity,

                      height: 52,

                      child: ElevatedButton(
                        onPressed: opcaoTemporaria == null
                            ? null
                            : () {
                                Navigator.pop(context, opcaoTemporaria);
                              },

                        child: const Text(
                          'Confirmar forma de pagamento',

                          style: TextStyle(
                            fontSize: 16,

                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted) {
      return;
    }

    if (resultado != null) {
      setState(() {
        pagamento = 'Pagar no local';

        formaPagamentoLocal = resultado;
      });
    }
  }

  // ============================================================

  // CARD DO MENU DE PAGAMENTO LOCAL

  // ============================================================

  Future<void> _selecionarPagamentoEntrega() async {
    String? opcao = formaPagamentoEntrega;
    final trocoController = TextEditingController();

    final resultado = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 45,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Pagamento na entrega',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Como você deseja pagar quando o pedido chegar?',
                      style: TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 22),
                    _opcaoPagamentoLocal(
                      titulo: 'Dinheiro',
                      subtitulo: 'Pagamento em dinheiro na entrega',
                      icone: Icons.payments_outlined,
                      selecionado: opcao == 'Dinheiro',
                      onTap: () => setModalState(() => opcao = 'Dinheiro'),
                    ),
                    if (opcao == 'Dinheiro') ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: trocoController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Troco para quanto? (opcional)',
                          hintText: 'Ex.: 100,00',
                          prefixText: 'R\$ ',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    _opcaoPagamentoLocal(
                      titulo: 'Cartão de crédito',
                      subtitulo: 'Crédito na maquininha na entrega',
                      icone: Icons.credit_card,
                      selecionado: opcao == 'Crédito',
                      onTap: () => setModalState(() => opcao = 'Crédito'),
                    ),
                    const SizedBox(height: 10),
                    _opcaoPagamentoLocal(
                      titulo: 'Cartão de débito',
                      subtitulo: 'Débito na maquininha na entrega',
                      icone: Icons.credit_card,
                      selecionado: opcao == 'Débito',
                      onTap: () => setModalState(() => opcao = 'Débito'),
                    ),
                    const SizedBox(height: 10),
                    _opcaoPagamentoLocal(
                      titulo: 'Pix',
                      subtitulo: 'Pix realizado no momento da entrega',
                      icone: Icons.pix,
                      selecionado: opcao == 'Pix',
                      onTap: () => setModalState(() => opcao = 'Pix'),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: opcao == null
                            ? null
                            : () {
                                double? troco;
                                if (opcao == 'Dinheiro' &&
                                    trocoController.text.trim().isNotEmpty) {
                                  troco = double.tryParse(
                                    trocoController.text.trim().replaceAll(
                                      ',',
                                      '.',
                                    ),
                                  );
                                  if (troco == null) return;
                                }
                                Navigator.pop(context, {
                                  'forma': opcao,
                                  'trocoPara': troco,
                                });
                              },
                        child: const Text('Confirmar forma de pagamento'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    trocoController.dispose();
    if (!mounted || resultado == null) return;

    setState(() {
      pagamento = 'Pagar na entrega';
      formaPagamentoEntrega = resultado['forma']?.toString();
      trocoParaEntrega = (resultado['trocoPara'] as num?)?.toDouble();
      formaPagamentoLocal = null;
      formaPagamentoEntrega = null;
      trocoParaEntrega = null;
    });
  }

  Widget _pagamentoEntrega() {
    final selecionado = pagamento == 'Pagar na entrega';
    String subtitulo = formaPagamentoEntrega ?? 'Escolha como deseja pagar';
    if (formaPagamentoEntrega == 'Dinheiro' && trocoParaEntrega != null) {
      subtitulo += ' • Troco para ${Formatters.money(trocoParaEntrega!)}';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: finalizandoPedido ? null : _selecionarPagamentoEntrega,
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
              const Icon(Icons.delivery_dining, color: AppColors.green),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pagar na entrega',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitulo,
                      style: const TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selecionado ? Icons.radio_button_checked : Icons.chevron_right,
                color: selecionado ? AppColors.green : AppColors.mutedText,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _opcaoPagamentoLocal({
    required String titulo,

    required String subtitulo,

    required IconData icone,

    required bool selecionado,

    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,

      borderRadius: BorderRadius.circular(14),

      child: Container(
        padding: const EdgeInsets.all(15),

        decoration: BoxDecoration(
          color: selecionado ? AppColors.softGreen : Colors.white,

          borderRadius: BorderRadius.circular(14),

          border: Border.all(
            color: selecionado ? AppColors.green : Colors.grey.shade300,

            width: selecionado ? 1.5 : 1,
          ),
        ),

        child: Row(
          children: [
            Container(
              width: 46,

              height: 46,

              decoration: BoxDecoration(
                color: AppColors.softGreen,

                borderRadius: BorderRadius.circular(12),
              ),

              child: Icon(icone, color: AppColors.green),
            ),

            const SizedBox(width: 13),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    titulo,

                    style: const TextStyle(
                      fontSize: 16,

                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    subtitulo,

                    style: const TextStyle(
                      color: AppColors.mutedText,

                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            Icon(
              selecionado ? Icons.radio_button_checked : Icons.radio_button_off,

              color: selecionado ? AppColors.green : AppColors.mutedText,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================

  // TEXTO DO ENDEREÇO

  // ============================================================

  String get _textoEndereco {
    if (enderecoSelecionado == null) {
      return 'Informe o endereço de entrega';
    }

    final rua = enderecoSelecionado!['rua']?.toString().trim() ?? '';

    final numero = enderecoSelecionado!['numero']?.toString().trim() ?? '';

    final complemento =
        enderecoSelecionado!['complemento']?.toString().trim() ?? '';

    final bairro = enderecoSelecionado!['bairro']?.toString().trim() ?? '';

    final cidade = enderecoSelecionado!['cidade']?.toString().trim() ?? '';

    final estado = enderecoSelecionado!['estado']?.toString().trim() ?? '';

    final primeiraLinha = numero.isNotEmpty ? '$rua, $numero' : rua;

    final segundaLinha = <String>[];

    if (bairro.isNotEmpty) {
      segundaLinha.add(bairro);
    }

    if (cidade.isNotEmpty) {
      segundaLinha.add(cidade);
    }

    if (estado.isNotEmpty) {
      segundaLinha.add(estado);
    }

    String texto = primeiraLinha;

    if (complemento.isNotEmpty) {
      texto += ' - $complemento';
    }

    if (segundaLinha.isNotEmpty) {
      texto += '\n${segundaLinha.join(' - ')}';
    }

    return texto;
  }

  // ============================================================

  // FINALIZAR PEDIDO DE RETIRADA

  // ============================================================

  Future<void> _finalizarPedidoRetirada(double totalAtual) async {
    if (finalizandoPedido) {
      return;
    }

    if (carrinho.vazio) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Seu carrinho está vazio. Adicione produtos antes de continuar.',
          ),
        ),
      );

      return;
    }

    setState(() {
      finalizandoPedido = true;
    });

    try {
      // ========================================================

      // 1. CRIAR PEDIDO DE RETIRADA

      // ========================================================

      final pedidoCriado = await pedidoRepository.criarPedidoRetirada();

      final pedidoId =
          pedidoCriado['id']?.toString() ??
          pedidoCriado['pedido_id']?.toString();

      if (pedidoId == null || pedidoId.isEmpty) {
        throw Exception(
          'O pedido foi criado, mas o identificador não foi retornado.',
        );
      }

      // ========================================================

      // 2. ADICIONAR TODOS OS PRODUTOS

      // ========================================================

      for (final item in carrinho.itens) {
        await pedidoRepository.adicionarItem(
          pedidoId: pedidoId,

          produtoId: item.produto.id.toString(),

          quantidade: item.quantidade,

          observacao: item.observacao,
        );
      }

      // ========================================================

      // 3. CONFIRMAR PEDIDO

      // ========================================================

      //

      // IMPORTANTE:

      //

      // Para pedidos de retirada feitos pelo cliente,

      // o backend agora faz automaticamente:

      //

      // rascunho -> em_preparo

      //

      // Portanto o aplicativo NÃO chama alterarStatus().

      // O cliente não possui permissão para alterar

      // manualmente o status do pedido.

      //

      // Depois disso, o GERENTE será responsável por:

      //

      // em_preparo -> pronto

      // pronto -> concluido

      // ========================================================

      final pedidoConfirmado = await pedidoRepository.confirmarPedido(pedidoId);

      if (!mounted) {
        return;
      }

      // ========================================================

      // 4. DADOS DA PRÓXIMA TELA

      // ========================================================

      final args = <String, dynamic>{
        'pedidoId': pedidoId,

        'pedido_id': pedidoId,

        'tipoPedido': 'retirada',

        'total': totalAtual,

        'quantidade': quantidade,

        'pagamento': pagamento,

        'status': pedidoConfirmado['status']?.toString() ?? 'em_preparo',
      };

      // ========================================================

      // PAGAMENTO NO LOCAL

      // ========================================================

      if (pagamento == 'Pagar no local' && formaPagamentoLocal != null) {
        args['formaPagamentoLocal'] = formaPagamentoLocal;

        args['forma_pagamento_local'] = formaPagamentoLocal!.toLowerCase();

        args['pagamentoLocal'] = true;
      }

      // ========================================================

      // 5. LIMPAR O CARRINHO

      // ========================================================

      //

      // O carrinho só será apagado quando:

      //

      // - o pedido tiver sido criado;

      // - todos os itens tiverem sido adicionados;

      // - o backend tiver confirmado o pedido.

      //

      // Se qualquer etapa acima falhar, o carrinho permanece.

      // ========================================================

      carrinho.limpar();

      // ========================================================

      // 6. ABRIR TELA DE SUCESSO

      // ========================================================

      Navigator.pushNamed(
        context,

        '/cliente/pagamento-sucesso',

        arguments: args,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      String mensagem = e.toString();

      if (mensagem.startsWith('Exception: ')) {
        mensagem = mensagem.substring(11);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensagem), backgroundColor: AppColors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          finalizandoPedido = false;
        });
      }
    }
  }

  // ============================================================

  // CONTINUAR

  // ============================================================

  // ============================================================

  // FINALIZAR PEDIDO DE MESA + PAGAMENTO NO LOCAL

  // ============================================================

  Future<void> _finalizarPedidoMesaLocal(double totalAtual) async {
    if (finalizandoPedido) return;

    if (carrinho.vazio) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Seu carrinho está vazio. Adicione produtos antes de continuar.',
          ),
        ),
      );

      return;
    }

    final sessao = sessaoMesaId;

    if (sessao == null || sessao.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A reserva da mesa está incompleta. Selecione a mesa novamente.',
          ),
        ),
      );

      return;
    }

    if (formaPagamentoLocal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escolha como deseja pagar no local.')),
      );

      return;
    }

    setState(() {
      finalizandoPedido = true;
    });

    try {
      final pedidoCriado = await pedidoRepository.criarPedidoMesa(
        sessaoMesaId: sessao,
      );

      final pedidoId =
          pedidoCriado['id']?.toString() ??
          pedidoCriado['pedido_id']?.toString();

      if (pedidoId == null || pedidoId.isEmpty) {
        throw Exception(
          'O pedido foi criado, mas o identificador não foi retornado.',
        );
      }

      for (final item in carrinho.itens) {
        await pedidoRepository.adicionarItem(
          pedidoId: pedidoId,

          produtoId: item.produto.id.toString(),

          quantidade: item.quantidade,

          observacao: item.observacao,
        );
      }

      final pedidoConfirmado = await pedidoRepository.confirmarPedido(pedidoId);

      if (!mounted) return;

      final args = <String, dynamic>{
        'pedidoId': pedidoId,

        'pedido_id': pedidoId,

        'tipoPedido': 'mesa',

        'total': totalAtual,

        'quantidade': quantidade,

        'pagamento': 'Pagar no local',

        'pagamentoLocal': true,

        'formaPagamentoLocal': formaPagamentoLocal,

        'forma_pagamento_local': formaPagamentoLocal!.toLowerCase(),

        'mesa': mesaSelecionada,

        'mesa_id': mesaId,

        'sessao_id': sessao,

        'sessaoMesaId': sessao,

        'numero_mesa': numeroMesa,

        'status': pedidoConfirmado['status']?.toString() ?? 'confirmado',
      };

      carrinho.limpar();

      Navigator.pushNamed(
        context,

        '/cliente/pagamento-sucesso',

        arguments: args,
      );
    } catch (e) {
      if (!mounted) return;

      String mensagem = e.toString();

      if (mensagem.startsWith('Exception: ')) {
        mensagem = mensagem.substring(11);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensagem), backgroundColor: AppColors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          finalizandoPedido = false;
        });
      }
    }
  }

  Future<void> _finalizarPedidoDeliveryNaEntrega(double totalAtual) async {
    if (finalizandoPedido) return;

    if (formaPagamentoEntrega == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escolha como deseja pagar na entrega.')),
      );
      return;
    }

    if (carrinho.vazio) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Seu carrinho está vazio.')));

      return;
    }

    if (carrinho.subtotal < 25) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('O pedido mínimo é de R25,00.')),
      );

      return;
    }

    if (enderecoSelecionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o endereço de entrega.')),
      );

      return;
    }

    final enderecoId =
        enderecoSelecionado!['enderecoId']?.toString() ??
        enderecoSelecionado!['id']?.toString();

    if (enderecoId == null || enderecoId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Este endereço ainda não está vinculado ao sistema. '
            'Selecione ou cadastre o endereço novamente.',
          ),
        ),
      );

      return;
    }

    setState(() {
      finalizandoPedido = true;
    });

    try {
      final pedidoCriado = await pedidoRepository.criarPedidoDelivery(
        enderecoId: enderecoId,
      );

      final pedidoId =
          pedidoCriado['id']?.toString() ??
          pedidoCriado['pedido_id']?.toString();

      if (pedidoId == null || pedidoId.isEmpty) {
        throw Exception(
          'O pedido foi criado, mas o identificador não foi retornado.',
        );
      }

      for (final item in carrinho.itens) {
        await pedidoRepository.adicionarItem(
          pedidoId: pedidoId,

          produtoId: item.produto.id.toString(),

          quantidade: item.quantidade,

          observacao: item.observacao.trim().isEmpty
              ? null
              : item.observacao.trim(),
        );
      }

      final pedidoConfirmado = await pedidoRepository.confirmarPedido(pedidoId);

      final metodoPagamento = switch (formaPagamentoEntrega) {
        'Dinheiro' => 'dinheiro',
        'Crédito' => 'cartao_credito',
        'Débito' => 'cartao_debito',
        'Pix' => 'pix',
        _ => throw Exception('Forma de pagamento na entrega inválida.'),
      };

      final pagamentoCriado = await pedidoRepository.criarPagamento(
        pedidoId: pedidoId,
        metodo: metodoPagamento,
        trocoPara: metodoPagamento == 'dinheiro' ? trocoParaEntrega : null,
        idempotencyKey: 'entrega-$metodoPagamento-$pedidoId',
      );

      if (!mounted) return;

      final args = <String, dynamic>{
        'pedidoId': pedidoId,

        'pedido_id': pedidoId,

        'tipoPedido': 'delivery',

        'total': totalAtual,

        'quantidade': quantidade,

        'pagamento': 'Pagar na entrega',

        'formaPagamento': 'Pagar na entrega',

        'pagamentoNaEntrega': true,
        'formaPagamentoEntrega': formaPagamentoEntrega,
        'forma_pagamento_entrega': metodoPagamento,
        'trocoPara': trocoParaEntrega,

        'pagamentoAprovado': false,

        'statusPagamento': 'pendente',

        'pagamentoId': pagamentoCriado['id']?.toString(),

        'status': pedidoConfirmado['status']?.toString() ?? 'confirmado',

        'endereco': enderecoSelecionado,

        'enderecoId': enderecoId,
      };

      carrinho.limpar();

      Navigator.pushNamed(
        context,

        '/cliente/pagamento-sucesso',

        arguments: args,
      );
    } catch (e) {
      if (!mounted) return;

      String mensagem = e.toString();

      if (mensagem.startsWith('Exception: ')) {
        mensagem = mensagem.substring(11);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensagem), backgroundColor: AppColors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          finalizandoPedido = false;
        });
      }
    }
  }

  Future<void> _continuar(double totalAtual) async {
    // ==========================================================

    // VALIDAR DELIVERY

    // ==========================================================

    if (tipoPedido == TipoPedido.delivery && enderecoSelecionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe o endereço de entrega para continuar.'),
        ),
      );

      return;
    }

    // ==========================================================

    // VALIDAR MESA

    // ==========================================================

    if (tipoPedido == TipoPedido.mesa && mesaSelecionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione e reserve uma mesa para continuar.'),
        ),
      );

      return;
    }

    if (tipoPedido == TipoPedido.mesa) {
      if (mesaId == null ||
          mesaId!.isEmpty ||
          sessaoMesaId == null ||
          sessaoMesaId!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'A reserva da mesa está incompleta. Selecione a mesa novamente.',
            ),
          ),
        );

        return;
      }
    }

    // ==========================================================

    // VALIDAR PAGAMENTO LOCAL

    // ==========================================================

    if (pagamento == 'Pagar no local' && formaPagamentoLocal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escolha como deseja pagar no local.')),
      );

      return;
    }

    // ==========================================================

    // RETIRADA + PAGAMENTO NO LOCAL

    // ==========================================================

    // Este é o primeiro fluxo que estamos ligando

    // completamente ao backend.

    if (tipoPedido == TipoPedido.retirada && pagamento == 'Pagar no local') {
      await _finalizarPedidoRetirada(totalAtual);

      return;
    }

    // ==========================================================

    // MESA + PAGAMENTO NO LOCAL

    // ==========================================================

    if (tipoPedido == TipoPedido.mesa && pagamento == 'Pagar no local') {
      await _finalizarPedidoMesaLocal(totalAtual);

      return;
    }

    // ==========================================================

    // DELIVERY + PAGAR NA ENTREGA

    // ==========================================================

    if (tipoPedido == TipoPedido.delivery && pagamento == 'Pagar na entrega') {
      await _finalizarPedidoDeliveryNaEntrega(totalAtual);

      return;
    }

    // ==========================================================

    // ARGUMENTOS DOS OUTROS FLUXOS

    // ==========================================================

    final args = <String, dynamic>{
      'tipoPedido': tipoPedidoValor,

      'total': totalAtual,

      'quantidade': quantidade,

      'pagamento': pagamento,
    };

    // ==========================================================

    // PAGAMENTO LOCAL

    // ==========================================================

    if (pagamento == 'Pagar no local' && formaPagamentoLocal != null) {
      args['formaPagamentoLocal'] = formaPagamentoLocal;

      args['pagamentoLocal'] = true;

      args['forma_pagamento_local'] = formaPagamentoLocal!.toLowerCase();
    }

    // ==========================================================

    // ENDEREÇO

    // ==========================================================

    if (tipoPedido == TipoPedido.delivery && enderecoSelecionado != null) {
      final enderecoId =
          enderecoSelecionado!['enderecoId']?.toString() ??
          enderecoSelecionado!['id']?.toString();

      if (enderecoId == null || enderecoId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Este endereço ainda não está vinculado ao sistema. '
              'Selecione ou cadastre o endereço novamente.',
            ),
          ),
        );

        return;
      }

      args['endereco'] = enderecoSelecionado;

      args['enderecoId'] = enderecoId;
    }

    // ==========================================================

    // MESA

    // ==========================================================

    if (tipoPedido == TipoPedido.mesa && mesaSelecionada != null) {
      args['mesa'] = mesaSelecionada;

      args['mesa_id'] = mesaId;

      args['sessao_id'] = sessaoMesaId;

      args['sessaoMesaId'] = sessaoMesaId;

      args['numero_mesa'] = numeroMesa;
    }

    // ==========================================================

    // PIX

    // ==========================================================

    if (pagamento == 'Pix') {
      Navigator.pushNamed(context, '/cliente/pix', arguments: args);

      return;
    }

    // ==========================================================

    // CARTÃO

    // ==========================================================

    if (pagamento == 'Cartão') {
      Navigator.pushNamed(context, '/cliente/cadastro-cartao', arguments: args);

      return;
    }

    // ==========================================================

    // OUTROS FLUXOS

    // ==========================================================

    Navigator.pushNamed(context, '/cliente/pagamento-sucesso', arguments: args);
  }

  // ============================================================

  // BUILD

  // ============================================================

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
            // ==================================================

            // CABEÇALHO

            // ==================================================
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),

              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new),

                    onPressed: finalizandoPedido
                        ? null
                        : () {
                            Navigator.pop(context);
                          },
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

            // ==================================================

            // CONTEÚDO

            // ==================================================
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

                      onSelectionChanged: finalizandoPedido
                          ? null
                          : (value) {
                              setState(() {
                                tipoPedido = value.first;

                                pagamento = 'Pix';

                                formaPagamentoLocal = null;
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

                    if (tipoPedido == TipoPedido.delivery) _pagamentoEntrega(),

                    if (tipoPedido == TipoPedido.retirada ||
                        tipoPedido == TipoPedido.mesa)
                      _pagamentoLocal(),
                  ],
                ),
              ),
            ),

            // ==================================================

            // RODAPÉ

            // ==================================================
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
                      onPressed: finalizandoPedido
                          ? null
                          : () {
                              _continuar(totalAtual);
                            },

                      child: finalizandoPedido
                          ? const SizedBox(
                              width: 22,

                              height: 22,

                              child: CircularProgressIndicator(
                                strokeWidth: 2,

                                color: Colors.white,
                              ),
                            )
                          : const Text('Continuar'),
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

  // ============================================================

  // CARD PAGAR NO LOCAL

  // ============================================================

  Widget _pagamentoLocal() {
    final selecionado = pagamento == 'Pagar no local';

    final subtitulo = formaPagamentoLocal == null
        ? 'Escolha como deseja pagar'
        : formaPagamentoLocal!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),

      child: InkWell(
        borderRadius: BorderRadius.circular(8),

        onTap: finalizandoPedido ? null : _selecionarPagamentoLocal,

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
              const Icon(Icons.store, color: AppColors.green),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    const Text(
                      'Pagar no local',

                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      subtitulo,

                      style: const TextStyle(
                        color: AppColors.mutedText,

                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              Icon(
                selecionado ? Icons.radio_button_checked : Icons.chevron_right,

                color: selecionado ? AppColors.green : AppColors.mutedText,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================

  // INFORMAÇÕES DO PEDIDO

  // ============================================================

  Widget _buildInformacaoPedido() {
    switch (tipoPedido) {
      // ========================================================

      // DELIVERY

      // ========================================================

      case TipoPedido.delivery:
        if (carregandoEndereco) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(20),

              child: Row(
                children: [
                  SizedBox(
                    width: 20,

                    height: 20,

                    child: CircularProgressIndicator(
                      strokeWidth: 2,

                      color: AppColors.green,
                    ),
                  ),

                  SizedBox(width: 14),

                  Text('Carregando endereço...'),
                ],
              ),
            ),
          );
        }

        return _InfoCard(
          icon: Icons.location_on_outlined,

          title: 'Endereço de entrega',

          subtitle: _textoEndereco,

          action: enderecoSelecionado == null ? 'Adicionar' : 'Mudar',

          onTap: finalizandoPedido ? null : _selecionarEndereco,
        );

      // ========================================================

      // RETIRADA

      // ========================================================

      case TipoPedido.retirada:
        return const _InfoCard(
          icon: Icons.storefront,

          title: 'Retirada no local',

          subtitle: 'Seu pedido ficará disponível no balcão.',
        );

      // ========================================================

      // MESA

      // ========================================================

      case TipoPedido.mesa:
        if (mesaSelecionada == null) {
          return _InfoCard(
            icon: Icons.table_restaurant,

            title: 'Reservar mesa',

            subtitle: 'Escolha uma mesa disponível.',

            action: 'Escolher',

            onTap: finalizandoPedido ? null : _selecionarMesa,
          );
        }

        final numero = numeroMesa ?? '-';

        final capacidade = (mesaSelecionada!['capacidade'] as num?)?.toInt();

        String subtitulo = 'Mesa $numero';

        if (capacidade != null && capacidade > 0) {
          subtitulo +=
              '\nAté $capacidade ${capacidade == 1 ? 'pessoa' : 'pessoas'}';
        }

        return _InfoCard(
          icon: Icons.table_restaurant,

          title: 'Mesa reservada',

          subtitle: subtitulo,

          action: 'Trocar',

          onTap: finalizandoPedido ? null : _selecionarMesa,
        );
    }
  }

  // ============================================================

  // PAGAMENTO NORMAL

  // ============================================================

  Widget _pagamento(String nome, IconData icon) {
    final selecionado = pagamento == nome;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),

      child: InkWell(
        borderRadius: BorderRadius.circular(8),

        onTap: finalizandoPedido
            ? null
            : () {
                setState(() {
                  pagamento = nome;

                  // Ao escolher Pix ou Cartão antecipado,

                  // deixa de existir pagamento local.

                  if (nome != 'Pagar no local') {
                    formaPagamentoLocal = null;
                  }
                });
              },

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

// ============================================================

// TÍTULO

// ============================================================

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

// ============================================================

// CARD DE INFORMAÇÃO

// ============================================================

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

// ============================================================

// TIPO DO PEDIDO

// ============================================================

enum TipoPedido { delivery, retirada, mesa }
