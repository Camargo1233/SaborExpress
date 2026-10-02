import 'dart:async';

import 'package:flutter/material.dart';

import '../Repositories/pedido_repository.dart';

import '../Repositories/pagamento_repository.dart';

class PedidosGerenteTela extends StatefulWidget {
  const PedidosGerenteTela({super.key});

  @override
  State<PedidosGerenteTela> createState() => _PedidosGerenteTelaState();
}

class _PedidosGerenteTelaState extends State<PedidosGerenteTela> {
  final PedidoRepository _pedidoRepository = PedidoRepository();

  final PagamentoRepository _pagamentoRepository = PagamentoRepository();

  Timer? _timer;

  bool carregando = true;

  bool atualizando = false;

  String? erro;

  List<Map<String, dynamic>> pedidos = [];

  final Map<String, int> _quantidadesItens = {};

  final Set<String> _buscandoQuantidade = {};

  final Map<String, String> _metodosPagamento = {};
  final Set<String> _buscandoMetodoPagamento = {};

  @override
  void initState() {
    super.initState();

    _iniciarTela();
  }

  Future<void> _iniciarTela() async {
    await carregarPedidos();

    if (!mounted) return;

    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      carregarPedidos(silencioso: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();

    super.dispose();
  }

  // ============================================================

  // CARREGAR PEDIDOS

  // ============================================================

  Future<void> carregarPedidos({bool silencioso = false}) async {
    // Não usa o bloqueio das ações dos botões para impedir a atualização

    // da lista. Assim uma ação concluída nunca deixa os botões travados.

    final estavaAtualizando = atualizando;

    if (!estavaAtualizando) {
      atualizando = true;
    }

    if (!silencioso && mounted) {
      setState(() {
        carregando = true;

        erro = null;
      });
    }

    try {
      // Apenas UMA chamada para a listagem.

      // Detalhes e pagamentos são consultados sob demanda.

      final lista = await _pedidoRepository.listarPedidos();

      if (!mounted) return;

      setState(() {
        pedidos = lista;

        carregando = false;

        erro = null;
      });
    } catch (e) {
      debugPrint('Erro ao carregar pedidos: $e');

      if (!mounted) return;

      if (!silencioso) {
        setState(() {
          carregando = false;

          erro = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (!estavaAtualizando) {
        atualizando = false;
      }
    }
  }

  // ============================================================

  // PEDIDOS EM ANDAMENTO

  // ============================================================

  bool _pedidoVazio(Map<String, dynamic> pedido) {
    final total = _paraDouble(pedido['total']);

    final qtd = _paraInt(
      pedido['qtd_itens'] ??
          pedido['quantidade_itens'] ??
          pedido['itens_count'],
    );

    final status = pedido['status']?.toString().toLowerCase() ?? '';

    return status == 'rascunho' && total <= 0 && qtd <= 0;
  }

  List<Map<String, dynamic>> get pedidosEmAndamento {
    return pedidos.where((pedido) {
      if (_pedidoVazio(pedido)) return false;

      final status = pedido['status']?.toString().toLowerCase() ?? '';

      return status != 'concluido' && status != 'cancelado';
    }).toList();
  }

  // ============================================================

  // PEDIDOS FINALIZADOS

  // ============================================================

  List<Map<String, dynamic>> get pedidosFinalizados {
    return pedidos.where((pedido) {
      if (_pedidoVazio(pedido)) return false;

      final status = pedido['status']?.toString().toLowerCase() ?? '';

      return status == 'concluido';
    }).toList();
  }

  // ============================================================

  // CONVERSÕES

  // ============================================================

  int _paraInt(dynamic valor) {
    if (valor == null) {
      return 0;
    }

    if (valor is int) {
      return valor;
    }

    if (valor is num) {
      return valor.toInt();
    }

    return int.tryParse(valor.toString()) ?? 0;
  }

  double _paraDouble(dynamic valor) {
    if (valor == null) {
      return 0;
    }

    if (valor is double) {
      return valor;
    }

    if (valor is num) {
      return valor.toDouble();
    }

    return double.tryParse(valor.toString().replaceAll(',', '.')) ?? 0;
  }

  // ============================================================

  // DINHEIRO

  // ============================================================

  String _formatarDinheiro(dynamic valor) {
    final numero = _paraDouble(valor);

    final partes = numero.toStringAsFixed(2).split('.');

    final inteiro = partes[0];

    final decimal = partes[1];

    final buffer = StringBuffer();

    for (int i = 0; i < inteiro.length; i++) {
      final restante = inteiro.length - i;

      buffer.write(inteiro[i]);

      if (restante > 1 && restante % 3 == 1) {
        buffer.write('.');
      }
    }

    return 'R\$ ${buffer.toString()},$decimal';
  }

  // ============================================================

  // NOME DA MESA

  // ============================================================

  String _nomePedido(Map<String, dynamic> pedido) {
    final tipo = pedido['tipo']?.toString().toLowerCase() ?? '';

    final numeroMesa =
        pedido['mesa_numero'] ?? pedido['numero_mesa'] ?? pedido['mesa'];

    if (tipo == 'mesa') {
      if (numeroMesa != null) {
        return 'Mesa $numeroMesa';
      }

      return 'Pedido na mesa';
    }

    final codigo = pedido['codigo']?.toString().trim() ?? '';

    if (tipo == 'delivery') {
      return codigo.isNotEmpty ? 'Pedido $codigo' : 'Delivery';
    }

    if (tipo == 'retirada') {
      return codigo.isNotEmpty ? 'Pedido $codigo' : 'Retirada';
    }

    return 'Pedido';
  }

  // ============================================================

  // QUANTIDADE DE ITENS

  // ============================================================

  String _quantidadeItens(Map<String, dynamic> pedido) {
    final pedidoId = pedido['id']?.toString();

    final quantidadeResumo = _paraInt(
      pedido['qtd_itens'] ??
          pedido['quantidade_itens'] ??
          pedido['itens_count'],
    );

    if (quantidadeResumo > 0) {
      if (pedidoId != null) {
        _quantidadesItens[pedidoId] = quantidadeResumo;
      }

      return quantidadeResumo == 1 ? '1 item' : '$quantidadeResumo itens';
    }

    if (pedido['itens'] is List) {
      final quantidade = (pedido['itens'] as List)
          .whereType<Map>()
          .where(
            (item) => item['status']?.toString().toLowerCase() != 'cancelado',
          )
          .fold<int>(
            0,

            (total, item) =>
                total +
                (_paraInt(item['quantidade']) > 0
                    ? _paraInt(item['quantidade'])
                    : 1),
          );

      if (pedidoId != null) {
        _quantidadesItens[pedidoId] = quantidade;
      }

      return quantidade == 1 ? '1 item' : '$quantidade itens';
    }

    if (pedidoId != null && _quantidadesItens.containsKey(pedidoId)) {
      final quantidade = _quantidadesItens[pedidoId]!;

      return quantidade == 1 ? '1 item' : '$quantidade itens';
    }

    if (pedidoId != null) {
      _carregarQuantidadeSobDemanda(pedidoId);
    }

    return 'Carregando itens...';
  }

  Future<void> _carregarQuantidadeSobDemanda(String pedidoId) async {
    if (_buscandoQuantidade.contains(pedidoId) ||
        _quantidadesItens.containsKey(pedidoId)) {
      return;
    }

    _buscandoQuantidade.add(pedidoId);

    try {
      final detalhes = await _pedidoRepository.detalharPedido(pedidoId);

      dynamic itensDados = detalhes['itens'];

      if (itensDados is! List &&
          detalhes['pedido'] is Map &&
          (detalhes['pedido'] as Map)['itens'] is List) {
        itensDados = (detalhes['pedido'] as Map)['itens'];
      }

      if (itensDados is! List &&
          detalhes['value'] is Map &&
          (detalhes['value'] as Map)['itens'] is List) {
        itensDados = (detalhes['value'] as Map)['itens'];
      }

      int quantidade = 0;

      if (itensDados is List) {
        quantidade = itensDados
            .whereType<Map>()
            .where(
              (item) => item['status']?.toString().toLowerCase() != 'cancelado',
            )
            .fold<int>(
              0,

              (total, item) =>
                  total +
                  (_paraInt(item['quantidade']) > 0
                      ? _paraInt(item['quantidade'])
                      : 1),
            );
      }

      _quantidadesItens[pedidoId] = quantidade;

      if (mounted) setState(() {});
    } catch (_) {
      // Não derruba a tela caso uma consulta individual seja limitada.
    } finally {
      _buscandoQuantidade.remove(pedidoId);
    }
  }

  // ============================================================

  // STATUS

  // ============================================================

  String _nomeStatus(String status) {
    switch (status) {
      case 'rascunho':
        return 'Rascunho';

      case 'confirmado':
        return 'Confirmado';

      case 'em_preparo':
        return 'Em preparo';

      case 'pronto':
        return 'Pronto';

      case 'em_entrega':
        return 'Em entrega';

      case 'concluido':
        return 'Finalizado';

      case 'cancelado':
        return 'Cancelado';

      default:
        return status;
    }
  }

  Color _corStatus(String status) {
    switch (status) {
      case 'rascunho':
        return Colors.grey;

      case 'confirmado':
        return Colors.red;

      case 'em_preparo':
        return Colors.orange;

      case 'pronto':
        return Colors.blue;

      case 'em_entrega':
        return Colors.purple;

      case 'concluido':
        return Colors.green;

      case 'cancelado':
        return Colors.red;

      default:
        return Colors.grey;
    }
  }

  String _statusPagamento(Map<String, dynamic> pedido) {
    return pedido['status_pagamento']?.toString().toLowerCase() ?? '';
  }

  bool _estaPago(Map<String, dynamic> pedido) {
    return _statusPagamento(pedido) == 'pago';
  }

  String _textoPagamento(Map<String, dynamic> pedido) {
    final status = _statusPagamento(pedido);

    if (status == 'pago') return 'Pago';

    return 'Pendente';
  }

  Color _corPagamento(Map<String, dynamic> pedido) {
    return _estaPago(pedido) ? Colors.green : Colors.orange;
  }

  String _nomeMetodoPagamento(String metodo) {
    switch (metodo.toLowerCase()) {
      case 'dinheiro':
        return 'Dinheiro';
      case 'pix':
        return 'Pix';
      case 'cartao_credito':
        return 'Crédito';
      case 'cartao_debito':
        return 'Débito';
      case 'vale_refeicao':
        return 'Vale-refeição';
      case 'na_entrega':
        return 'Na entrega';
      case 'no_local':
        return 'No local';
      default:
        return metodo;
    }
  }

  String _textoPagamentoComMetodo(Map<String, dynamic> pedido) {
    if (_estaPago(pedido)) return 'Pago';

    final pedidoId = pedido['id']?.toString() ?? '';
    final metodoDireto =
        pedido['metodo_pagamento']?.toString() ??
        pedido['forma_pagamento']?.toString() ??
        pedido['metodo']?.toString();

    if (metodoDireto != null && metodoDireto.trim().isNotEmpty) {
      return 'Pendente • ${_nomeMetodoPagamento(metodoDireto)}';
    }

    final metodoCache = _metodosPagamento[pedidoId];
    if (metodoCache != null && metodoCache.isNotEmpty) {
      return 'Pendente • ${_nomeMetodoPagamento(metodoCache)}';
    }

    if (pedidoId.isNotEmpty) {
      _carregarMetodoPagamentoSobDemanda(pedidoId);
    }

    return 'Pendente';
  }

  Future<void> _carregarMetodoPagamentoSobDemanda(String pedidoId) async {
    if (_buscandoMetodoPagamento.contains(pedidoId) ||
        _metodosPagamento.containsKey(pedidoId)) {
      return;
    }

    _buscandoMetodoPagamento.add(pedidoId);

    try {
      final pagamentos = await _pagamentoRepository.listarPagamentos(pedidoId);

      Map<String, dynamic>? escolhido;
      for (final pagamento in pagamentos) {
        final status = pagamento['status']?.toString().toLowerCase() ?? '';
        if (status == 'pendente') {
          escolhido = pagamento;
          break;
        }
        if (escolhido == null && status == 'aprovado') {
          escolhido = pagamento;
        }
      }

      final metodo =
          escolhido?['metodo']?.toString() ??
          escolhido?['forma_pagamento']?.toString();

      if (metodo != null && metodo.trim().isNotEmpty) {
        _metodosPagamento[pedidoId] = metodo;
        if (mounted) setState(() {});
      }
    } catch (_) {
      // Mantém somente "Pendente" caso não seja possível consultar o método.
    } finally {
      _buscandoMetodoPagamento.remove(pedidoId);
    }
  }

  void _atualizarPedidoLocal(
    String pedidoId, {

    String? status,

    String? statusPagamento,
  }) {
    if (!mounted) return;

    setState(() {
      pedidos = pedidos.map((pedido) {
        if (pedido['id']?.toString() != pedidoId) {
          return pedido;
        }

        return <String, dynamic>{
          ...pedido,

          if (status != null) 'status': status,

          if (statusPagamento != null) 'status_pagamento': statusPagamento,
        };
      }).toList();
    });
  }

  void _finalizarPedidoLocal(String pedidoId) {
    _atualizarPedidoLocal(
      pedidoId,

      status: 'concluido',

      statusPagamento: 'pago',
    );
  }

  Future<void> _atualizarListaImediatamente() async {
    try {
      final lista = await _pedidoRepository.listarPedidos();

      if (!mounted) return;

      setState(() {
        pedidos = lista;

        erro = null;

        carregando = false;
      });
    } catch (e) {
      debugPrint('Erro ao atualizar lista após ação: $e');
    }
  }

  // ============================================================

  // AÇÕES DO GERENTE - RETIRADA

  // ============================================================

  bool _ehRetirada(Map<String, dynamic> pedido) {
    return pedido['tipo']?.toString().toLowerCase() == 'retirada';
  }

  String? _proximoStatusRetirada(Map<String, dynamic> pedido) {
    final status = pedido['status']?.toString().toLowerCase() ?? '';

    switch (status) {
      case 'em_preparo':
        return 'pronto';

      case 'pronto':
        return 'concluido';

      default:
        return null;
    }
  }

  String _textoAcaoRetirada(Map<String, dynamic> pedido) {
    switch (_proximoStatusRetirada(pedido)) {
      case 'pronto':
        return 'Marcar como pronto';

      case 'concluido':
        return 'Confirmar retirada';

      default:
        return '';
    }
  }

  IconData _iconeAcaoRetirada(Map<String, dynamic> pedido) {
    switch (_proximoStatusRetirada(pedido)) {
      case 'pronto':
        return Icons.check_circle_outline;

      case 'concluido':
        return Icons.shopping_bag_outlined;

      default:
        return Icons.arrow_forward;
    }
  }

  Future<String?> _selecionarPagamentoLocal() async {
    String selecionado = 'dinheiro';

    return showDialog<String>(
      context: context,

      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Pagamento no local'),

              content: Column(
                mainAxisSize: MainAxisSize.min,

                children: [
                  RadioListTile<String>(
                    value: 'dinheiro',

                    groupValue: selecionado,

                    title: const Text('Dinheiro'),

                    onChanged: (valor) {
                      if (valor != null) {
                        setModalState(() => selecionado = valor);
                      }
                    },
                  ),

                  RadioListTile<String>(
                    value: 'pix',

                    groupValue: selecionado,

                    title: const Text('Pix'),

                    onChanged: (valor) {
                      if (valor != null) {
                        setModalState(() => selecionado = valor);
                      }
                    },
                  ),

                  RadioListTile<String>(
                    value: 'cartao_credito',

                    groupValue: selecionado,

                    title: const Text('Cartão de crédito'),

                    onChanged: (valor) {
                      if (valor != null) {
                        setModalState(() => selecionado = valor);
                      }
                    },
                  ),

                  RadioListTile<String>(
                    value: 'cartao_debito',

                    groupValue: selecionado,

                    title: const Text('Cartão de débito'),

                    onChanged: (valor) {
                      if (valor != null) {
                        setModalState(() => selecionado = valor);
                      }
                    },
                  ),
                ],
              ),

              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),

                  child: const Text('Cancelar'),
                ),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,

                    foregroundColor: Colors.white,
                  ),

                  onPressed: () => Navigator.pop(dialogContext, selecionado),

                  child: const Text('Confirmar pagamento'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<Map<String, dynamic>> _pedidoAtualizado(String pedidoId) async {
    final detalhes = await _pedidoRepository.detalharPedido(pedidoId);

    if (detalhes['pedido'] is Map) {
      return Map<String, dynamic>.from(detalhes['pedido']);
    }

    if (detalhes['value'] is Map) {
      final value = Map<String, dynamic>.from(detalhes['value']);

      if (value['pedido'] is Map) {
        return Map<String, dynamic>.from(value['pedido']);
      }

      return value;
    }

    return Map<String, dynamic>.from(detalhes);
  }

  Future<void> _avancarRetirada(Map<String, dynamic> pedido) async {
    final pedidoId = pedido['id']?.toString();

    if (pedidoId == null || pedidoId.isEmpty) return;

    try {
      setState(() => atualizando = true);

      // IMPORTANTE:

      // O card pode estar desatualizado. Sempre consulta o pedido real

      // antes de decidir a próxima transição. Isso evita pronto -> pronto.

      var atual = await _pedidoAtualizado(pedidoId);

      var statusAtual =
          atual['status']?.toString().toLowerCase() ??
          pedido['status']?.toString().toLowerCase() ??
          '';

      var statusPagamento =
          atual['status_pagamento']?.toString().toLowerCase() ??
          pedido['status_pagamento']?.toString().toLowerCase() ??
          '';

      if (statusAtual == 'concluido' || statusAtual == 'cancelado') {
        _atualizarListaImediatamente();

        return;
      }

      // CONFIRMADO -> EM PREPARO

      if (statusAtual == 'confirmado') {
        await _pedidoRepository.alterarStatus(
          pedidoId: pedidoId,

          status: 'em_preparo',
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pedido enviado para preparo.'),

            backgroundColor: Colors.green,
          ),
        );

        _atualizarListaImediatamente();

        return;
      }

      // EM PREPARO -> PRONTO

      if (statusAtual == 'em_preparo') {
        await _pedidoRepository.alterarStatus(
          pedidoId: pedidoId,

          status: 'pronto',
        );

        if (!mounted) return;

        // Atualiza o card imediatamente, sem depender do botão de atualizar.

        _atualizarPedidoLocal(pedidoId, status: 'pronto');

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pedido marcado como pronto para retirada.'),

            backgroundColor: Colors.green,
          ),
        );

        _atualizarListaImediatamente();

        return;
      }

      // A partir daqui, só pode finalizar se realmente estiver PRONTO.

      if (statusAtual != 'pronto') {
        throw Exception('O pedido ainda não está pronto para retirada.');
      }

      // Revalida pagamentos existentes. O status resumido do card pode

      // estar atrasado em relação ao backend.

      final pagamentos = await _pagamentoRepository.listarPagamentos(pedidoId);

      Map<String, dynamic>? pagamentoAprovado;

      Map<String, dynamic>? pagamentoPendente;

      for (final pagamentoExistente in pagamentos) {
        final statusExistente =
            pagamentoExistente['status']?.toString().toLowerCase() ?? '';

        if (statusExistente == 'aprovado') {
          pagamentoAprovado = pagamentoExistente;

          break;
        }

        if (statusExistente == 'pendente') {
          pagamentoPendente = pagamentoExistente;
        }
      }

      final jaPago = statusPagamento == 'pago' || pagamentoAprovado != null;

      if (jaPago) {
        // PAGOU PELO APP:

        // não mostra nenhuma forma de pagamento.

        setState(() => atualizando = false);

        final confirmar = await showDialog<bool>(
          context: context,

          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Confirmar retirada'),

              content: const Text(
                'O pedido já está pago. Confirma que o cliente retirou o pedido?',
              ),

              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),

                  child: const Text('Cancelar'),
                ),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,

                    foregroundColor: Colors.white,
                  ),

                  onPressed: () => Navigator.pop(dialogContext, true),

                  child: const Text('Pedido retirado'),
                ),
              ],
            );
          },
        );

        if (confirmar != true || !mounted) return;

        setState(() => atualizando = true);

        // Consulta mais uma vez antes de concluir para evitar uma

        // transição duplicada caso outra tela tenha atualizado o pedido.

        atual = await _pedidoAtualizado(pedidoId);

        statusAtual = atual['status']?.toString().toLowerCase() ?? statusAtual;

        if (statusAtual == 'pronto') {
          await _pedidoRepository.alterarStatus(
            pedidoId: pedidoId,

            status: 'concluido',
          );

          if (!mounted) return;

          // Sai de "em andamento" e entra em "finalizados" na mesma hora.

          _finalizarPedidoLocal(pedidoId);
        }

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pedido retirado e finalizado com sucesso.'),

            backgroundColor: Colors.green,
          ),
        );

        _atualizarListaImediatamente();

        return;
      }

      // PAGAMENTO NO LOCAL:

      // o gerente escolhe a forma de pagamento e só depois finaliza.

      setState(() => atualizando = false);

      final metodo = await _selecionarPagamentoLocal();

      if (metodo == null || !mounted) return;

      setState(() => atualizando = true);

      String? pagamentoId;

      if (pagamentoPendente != null) {
        pagamentoId = pagamentoPendente['id']?.toString();
      } else {
        final pagamentoCriado = await _pagamentoRepository.criarPagamento(
          pedidoId: pedidoId,

          metodo: metodo,
        );

        final pagamentoDados = pagamentoCriado['pagamento'] is Map
            ? Map<String, dynamic>.from(pagamentoCriado['pagamento'])
            : pagamentoCriado;

        pagamentoId =
            pagamentoDados['id']?.toString() ??
            pagamentoCriado['pagamento_id']?.toString();
      }

      if (pagamentoId == null || pagamentoId.isEmpty) {
        throw Exception('Não foi possível identificar o pagamento do pedido.');
      }

      await _pagamentoRepository.confirmarPagamento(pagamentoId);

      // Confere se o backend realmente marcou como pago.

      atual = await _pedidoAtualizado(pedidoId);

      statusPagamento =
          atual['status_pagamento']?.toString().toLowerCase() ?? '';

      if (statusPagamento != 'pago') {
        throw Exception('O pagamento ainda não foi confirmado pelo sistema.');
      }

      _atualizarPedidoLocal(pedidoId, statusPagamento: 'pago');

      statusAtual = atual['status']?.toString().toLowerCase() ?? statusAtual;

      if (statusAtual == 'pronto') {
        await _pedidoRepository.alterarStatus(
          pedidoId: pedidoId,

          status: 'concluido',
        );

        if (!mounted) return;

        // Atualiza status operacional e financeiro imediatamente.

        _finalizarPedidoLocal(pedidoId);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pagamento confirmado. Pedido retirado e finalizado.'),

          backgroundColor: Colors.green,
        ),
      );

      _atualizarListaImediatamente();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),

          backgroundColor: Colors.red,
        ),
      );

      // Atualiza o card também em caso de conflito de status.

      _atualizarListaImediatamente();
    } finally {
      if (mounted) {
        setState(() => atualizando = false);
      }
    }
  }

  // ============================================================
  // AÇÕES DO GERENTE - DELIVERY
  // ============================================================

  bool _ehDelivery(Map<String, dynamic> pedido) {
    return pedido['tipo']?.toString().toLowerCase() == 'delivery';
  }

  String? _proximoStatusDelivery(Map<String, dynamic> pedido) {
    final status = pedido['status']?.toString().toLowerCase() ?? '';
    switch (status) {
      case 'confirmado':
        return 'pronto';
      case 'em_preparo':
        return 'pronto';
      case 'pronto':
        return 'em_entrega';
      case 'em_entrega':
        return 'concluido';
      default:
        return null;
    }
  }

  String _textoAcaoDelivery(Map<String, dynamic> pedido) {
    switch (_proximoStatusDelivery(pedido)) {
      case 'pronto':
        return 'Marcar como pronto';
      case 'em_entrega':
        return 'Saiu para entrega';
      case 'concluido':
        return 'Confirmar entrega';
      default:
        return '';
    }
  }

  IconData _iconeAcaoDelivery(Map<String, dynamic> pedido) {
    switch (_proximoStatusDelivery(pedido)) {
      case 'pronto':
        return Icons.check_circle_outline;
      case 'em_entrega':
        return Icons.delivery_dining;
      case 'concluido':
        return Icons.task_alt;
      default:
        return Icons.arrow_forward;
    }
  }

  Future<void> _avancarDelivery(Map<String, dynamic> pedido) async {
    final pedidoId = pedido['id']?.toString();
    if (pedidoId == null || pedidoId.isEmpty) return;

    try {
      setState(() => atualizando = true);

      var atual = await _pedidoAtualizado(pedidoId);
      var statusAtual =
          atual['status']?.toString().toLowerCase() ??
          pedido['status']?.toString().toLowerCase() ??
          '';

      if (statusAtual == 'concluido' || statusAtual == 'cancelado') {
        await _atualizarListaImediatamente();
        return;
      }

      if (statusAtual == 'confirmado') {
        await _pedidoRepository.alterarStatus(
          pedidoId: pedidoId,
          status: 'em_preparo',
        );

        // O gerente usa um único botão "Marcar como pronto".
        // Como o backend exige a sequência confirmado -> em_preparo -> pronto,
        // fazemos as duas transições no mesmo clique.
        await _pedidoRepository.alterarStatus(
          pedidoId: pedidoId,
          status: 'pronto',
        );

        if (!mounted) return;
        _atualizarPedidoLocal(pedidoId, status: 'pronto');

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Delivery marcado como pronto.'),
            backgroundColor: Colors.green,
          ),
        );

        await _atualizarListaImediatamente();
        return;
      }

      if (statusAtual == 'em_preparo') {
        await _pedidoRepository.alterarStatus(
          pedidoId: pedidoId,
          status: 'pronto',
        );
        if (!mounted) return;
        _atualizarPedidoLocal(pedidoId, status: 'pronto');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Delivery marcado como pronto.'),
            backgroundColor: Colors.green,
          ),
        );
        await _atualizarListaImediatamente();
        return;
      }

      if (statusAtual == 'pronto') {
        await _pedidoRepository.alterarStatus(
          pedidoId: pedidoId,
          status: 'em_entrega',
        );
        if (!mounted) return;
        _atualizarPedidoLocal(pedidoId, status: 'em_entrega');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pedido saiu para entrega.'),
            backgroundColor: Colors.purple,
          ),
        );
        await _atualizarListaImediatamente();
        return;
      }

      if (statusAtual == 'em_entrega') {
        final pagamentos = await _pagamentoRepository.listarPagamentos(
          pedidoId,
        );

        Map<String, dynamic>? pagamentoAprovado;
        Map<String, dynamic>? pagamentoPendente;

        for (final pagamento in pagamentos) {
          final statusPagamento =
              pagamento['status']?.toString().toLowerCase() ?? '';

          if (statusPagamento == 'aprovado') {
            pagamentoAprovado = pagamento;
            break;
          }

          if (statusPagamento == 'pendente') {
            pagamentoPendente = pagamento;
          }
        }

        final statusPagamentoPedido =
            atual['status_pagamento']?.toString().toLowerCase() ??
            pedido['status_pagamento']?.toString().toLowerCase() ??
            '';

        final jaPago =
            statusPagamentoPedido == 'pago' || pagamentoAprovado != null;

        setState(() => atualizando = false);

        final metodoPendente =
            pagamentoPendente?['metodo']?.toString() ??
            pagamentoPendente?['forma_pagamento']?.toString();

        final textoConfirmacao = jaPago
            ? 'O pedido já está pago. Confirma que ele foi entregue ao cliente?'
            : metodoPendente != null && metodoPendente.isNotEmpty
            ? 'Pagamento pendente em ${_nomeMetodoPagamento(metodoPendente)}. Confirma o recebimento e a entrega?'
            : 'O pagamento está pendente. Confirma o recebimento e a entrega?';

        final confirmar = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Confirmar entrega'),
            content: Text(textoConfirmacao),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(jaPago ? 'Pedido entregue' : 'Receber e entregar'),
              ),
            ],
          ),
        );

        if (confirmar != true || !mounted) return;
        setState(() => atualizando = true);

        // Se o cliente escolheu pagar na entrega, confirma exatamente
        // o pagamento pendente já criado por ele. Não troca a forma.
        if (!jaPago) {
          final pagamentoId = pagamentoPendente?['id']?.toString();

          if (pagamentoId == null || pagamentoId.isEmpty) {
            throw Exception(
              'Não foi encontrado o pagamento escolhido pelo cliente.',
            );
          }

          await _pagamentoRepository.confirmarPagamento(pagamentoId);

          atual = await _pedidoAtualizado(pedidoId);
          final novoStatusPagamento =
              atual['status_pagamento']?.toString().toLowerCase() ?? '';

          if (novoStatusPagamento != 'pago') {
            throw Exception(
              'O pagamento ainda não foi confirmado pelo sistema.',
            );
          }

          _atualizarPedidoLocal(pedidoId, statusPagamento: 'pago');
        }

        atual = await _pedidoAtualizado(pedidoId);
        statusAtual = atual['status']?.toString().toLowerCase() ?? statusAtual;

        if (statusAtual == 'em_entrega') {
          await _pedidoRepository.alterarStatus(
            pedidoId: pedidoId,
            status: 'concluido',
          );

          if (!mounted) return;
          _atualizarPedidoLocal(
            pedidoId,
            status: 'concluido',
            statusPagamento: 'pago',
          );
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pedido entregue e finalizado com sucesso.'),
            backgroundColor: Colors.green,
          ),
        );

        await _atualizarListaImediatamente();
        return;
      }

      throw Exception('O Delivery não pode avançar a partir deste status.');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
      await _atualizarListaImediatamente();
    } finally {
      if (mounted) setState(() => atualizando = false);
    }
  }

  // ============================================================

  // DETALHES DO PEDIDO

  // ============================================================

  Future<void> _abrirDetalhes(Map<String, dynamic> pedido) async {
    final pedidoId = pedido['id']?.toString();

    if (pedidoId == null || pedidoId.isEmpty) {
      return;
    }

    showDialog(
      context: context,

      barrierDismissible: false,

      builder: (_) {
        return const Center(
          child: CircularProgressIndicator(color: Colors.green),
        );
      },
    );

    try {
      final detalhes = await _pedidoRepository.detalharPedido(pedidoId);

      if (!mounted) return;

      Navigator.pop(context);

      _mostrarDetalhes(detalhes);
    } catch (e) {
      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  // ============================================================

  // MODAL DE DETALHES

  // ============================================================

  void _mostrarDetalhes(Map<String, dynamic> detalhes) {
    final pedidoDados = detalhes['pedido'] is Map
        ? Map<String, dynamic>.from(detalhes['pedido'])
        : detalhes;

    dynamic itensDados = detalhes['itens'];

    if (itensDados is! List && pedidoDados['itens'] is List) {
      itensDados = pedidoDados['itens'];
    }

    if (itensDados is! List &&
        detalhes['value'] is Map &&
        (detalhes['value'] as Map)['itens'] is List) {
      itensDados = (detalhes['value'] as Map)['itens'];
    }

    final List<Map<String, dynamic>> itens = [];

    if (itensDados is List) {
      for (final item in itensDados) {
        if (item is Map) {
          final convertido = Map<String, dynamic>.from(item);

          final status = convertido['status']?.toString().toLowerCase() ?? '';

          if (status != 'cancelado') {
            itens.add(convertido);
          }
        }
      }
    }

    final mesa = _nomePedido(pedidoDados);

    final total = _formatarDinheiro(pedidoDados['total']);

    final status = pedidoDados['status']?.toString().toLowerCase() ?? '';
    final tipoDetalhe = pedidoDados['tipo']?.toString().toLowerCase() ?? '';
    final exibirPagamentoDetalhe =
        tipoDetalhe == 'retirada' || tipoDetalhe == 'delivery';

    showModalBottomSheet(
      context: context,

      isScrollControlled: true,

      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),

      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 25,

              right: 25,

              top: 25,

              bottom: MediaQuery.of(context).viewInsets.bottom + 25,
            ),

            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Row(
                    children: [
                      const Icon(Icons.receipt_long, color: Colors.green),

                      const SizedBox(width: 10),

                      Expanded(
                        child: Text(
                          mesa,

                          style: const TextStyle(
                            fontSize: 24,

                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },

                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,

                      vertical: 6,
                    ),

                    decoration: BoxDecoration(
                      color: _corStatus(status).withValues(alpha: .15),

                      borderRadius: BorderRadius.circular(20),
                    ),

                    child: Text(
                      _nomeStatus(status),

                      style: TextStyle(
                        color: _corStatus(status),

                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  if (exibirPagamentoDetalhe) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _corPagamento(
                          pedidoDados,
                        ).withValues(alpha: .15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _textoPagamentoComMetodo(pedidoDados),
                        style: TextStyle(
                          color: _corPagamento(pedidoDados),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  const Text(
                    'Produtos',

                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 10),

                  if (itens.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 15),

                      child: Text('Nenhum item encontrado.'),
                    ),

                  ...itens.map((item) {
                    final nome =
                        item['produto_nome']?.toString() ??
                        item['nome']?.toString() ??
                        'Produto';

                    final quantidade = _paraInt(item['quantidade']);

                    final totalItem = item['total'] ?? item['preco_unitario'];

                    final observacao = item['observacao']?.toString() ?? '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),

                      padding: const EdgeInsets.all(12),

                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,

                        borderRadius: BorderRadius.circular(12),
                      ),

                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          Container(
                            width: 34,

                            height: 34,

                            alignment: Alignment.center,

                            decoration: BoxDecoration(
                              color: Colors.green.shade100,

                              borderRadius: BorderRadius.circular(10),
                            ),

                            child: Text(
                              '${quantidade}x',

                              style: const TextStyle(
                                color: Colors.green,

                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,

                              children: [
                                Text(
                                  nome,

                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                if (observacao.trim().isNotEmpty) ...[
                                  const SizedBox(height: 3),

                                  Text(
                                    observacao,

                                    style: TextStyle(
                                      color: Colors.grey.shade600,

                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          const SizedBox(width: 8),

                          Text(
                            _formatarDinheiro(totalItem),

                            style: const TextStyle(
                              color: Colors.green,

                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const Divider(height: 30),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,

                    children: [
                      const Text(
                        'Total',

                        style: TextStyle(
                          fontWeight: FontWeight.bold,

                          fontSize: 20,
                        ),
                      ),

                      Text(
                        total,

                        style: const TextStyle(
                          color: Colors.green,

                          fontSize: 22,

                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================

  // BUILD

  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      body: SafeArea(
        child: Column(
          children: [
            // ==================================================

            // CABEÇALHO

            // ==================================================
            Container(
              padding: const EdgeInsets.all(20),

              decoration: const BoxDecoration(
                color: Colors.green,

                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),

                  bottomRight: Radius.circular(30),
                ),
              ),

              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new,

                      color: Colors.white,
                    ),

                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),

                  const Expanded(
                    child: Text(
                      'Pedidos',

                      textAlign: TextAlign.center,

                      style: TextStyle(
                        color: Colors.white,

                        fontSize: 28,

                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  IconButton(
                    tooltip: 'Atualizar',

                    onPressed: () {
                      carregarPedidos();
                    },

                    icon: const Icon(
                      Icons.refresh,

                      color: Colors.white,

                      size: 30,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ==================================================

            // CONTEÚDO

            // ==================================================
            Expanded(
              child: RefreshIndicator(
                color: Colors.green,

                onRefresh: carregarPedidos,

                child: _conteudo(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================

  // CONTEÚDO

  // ============================================================

  Widget _conteudo() {
    if (carregando && pedidos.isEmpty) {
      return ListView(
        physics: AlwaysScrollableScrollPhysics(),

        children: [
          SizedBox(height: 250),

          Center(child: CircularProgressIndicator(color: Colors.green)),
        ],
      );
    }

    if (erro != null && pedidos.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),

        padding: const EdgeInsets.all(20),

        children: [
          const SizedBox(height: 100),

          Icon(Icons.error_outline, size: 50, color: Colors.red.shade400),

          const SizedBox(height: 15),

          Text(
            erro!,

            textAlign: TextAlign.center,

            style: const TextStyle(color: Colors.red),
          ),

          const SizedBox(height: 10),

          Center(
            child: TextButton.icon(
              onPressed: () {
                carregarPedidos();
              },

              icon: const Icon(Icons.refresh),

              label: const Text('Tentar novamente'),
            ),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),

      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),

      children: [
        // ======================================================

        // EM ANDAMENTO

        // ======================================================
        Row(
          children: [
            const Expanded(
              child: Text(
                'Pedidos em andamento',

                style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              ),
            ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),

              decoration: BoxDecoration(
                color: Colors.orange.shade50,

                borderRadius: BorderRadius.circular(20),
              ),

              child: Text(
                '${pedidosEmAndamento.length}',

                style: TextStyle(
                  color: Colors.orange.shade800,

                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 15),

        if (pedidosEmAndamento.isEmpty)
          _mensagemVazia('Nenhum pedido em andamento.', Icons.receipt_long),

        ...pedidosEmAndamento.map(
          (pedido) => Padding(
            padding: const EdgeInsets.only(bottom: 15),

            child: _pedidoCard(pedido),
          ),
        ),

        const SizedBox(height: 20),

        // ======================================================

        // FINALIZADOS

        // ======================================================
        Row(
          children: [
            const Expanded(
              child: Text(
                'Pedidos finalizados',

                style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              ),
            ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),

              decoration: BoxDecoration(
                color: Colors.green.shade50,

                borderRadius: BorderRadius.circular(20),
              ),

              child: Text(
                '${pedidosFinalizados.length}',

                style: const TextStyle(
                  color: Colors.green,

                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 15),

        if (pedidosFinalizados.isEmpty)
          _mensagemVazia(
            'Nenhum pedido finalizado.',

            Icons.check_circle_outline,
          ),

        ...pedidosFinalizados.map(
          (pedido) => Padding(
            padding: const EdgeInsets.only(bottom: 15),

            child: _pedidoCard(pedido),
          ),
        ),

        const SizedBox(height: 30),
      ],
    );
  }

  // ============================================================

  // CARD DO PEDIDO

  // ============================================================

  Widget _pedidoCard(Map<String, dynamic> pedido) {
    final status = pedido['status']?.toString().toLowerCase() ?? '';

    final finalizado = status == 'concluido';

    final cor = _corStatus(status);

    final mesa = _nomePedido(pedido);

    final total = _formatarDinheiro(pedido['total']);

    final retirada = _ehRetirada(pedido);

    final proximoStatusRetirada = retirada
        ? _proximoStatusRetirada(pedido)
        : null;

    final delivery = _ehDelivery(pedido);
    final proximoStatusDelivery = delivery
        ? _proximoStatusDelivery(pedido)
        : null;

    return Container(
      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: finalizado ? Colors.grey.shade100 : Colors.white,

        borderRadius: BorderRadius.circular(20),

        border: Border.all(
          color: finalizado ? Colors.grey.shade300 : Colors.grey.shade200,
        ),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .06),

            blurRadius: 8,

            offset: const Offset(0, 3),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),

                decoration: BoxDecoration(
                  color: finalizado
                      ? Colors.grey.shade200
                      : Colors.green.shade100,

                  borderRadius: BorderRadius.circular(15),
                ),

                child: Icon(
                  retirada
                      ? Icons.shopping_bag_outlined
                      : delivery
                      ? Icons.delivery_dining
                      : Icons.table_restaurant,

                  color: finalizado ? Colors.grey : Colors.green,
                ),
              ),

              const SizedBox(width: 15),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      mesa,

                      style: const TextStyle(
                        fontSize: 20,

                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      _quantidadeItens(pedido),

                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),

              if (retirada || delivery)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,

                    vertical: 5,
                  ),

                  decoration: BoxDecoration(
                    color: _corPagamento(pedido).withValues(alpha: .15),

                    borderRadius: BorderRadius.circular(20),
                  ),

                  child: Text(
                    _textoPagamentoComMetodo(pedido),

                    style: TextStyle(
                      color: _corPagamento(pedido),

                      fontSize: 12,

                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,

                    vertical: 6,
                  ),

                  decoration: BoxDecoration(
                    color: cor.withValues(alpha: .15),

                    borderRadius: BorderRadius.circular(20),
                  ),

                  child: Text(
                    _nomeStatus(status),

                    style: TextStyle(color: cor, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),

          const Divider(height: 30),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,

            children: [
              const Text(
                'Total do pedido',

                style: TextStyle(color: Colors.grey),
              ),

              Text(
                total,

                style: TextStyle(
                  color: finalizado ? Colors.grey : Colors.green,

                  fontSize: 22,

                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          if (retirada && proximoStatusRetirada != null) ...[
            SizedBox(
              width: double.infinity,

              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: proximoStatusRetirada == 'concluido'
                      ? Colors.blue
                      : Colors.green,

                  foregroundColor: Colors.white,

                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),

                icon: Icon(_iconeAcaoRetirada(pedido)),

                label: Text(
                  proximoStatusRetirada == 'concluido'
                      ? (_estaPago(pedido)
                            ? 'Confirmar retirada'
                            : 'Receber e finalizar')
                      : _textoAcaoRetirada(pedido),
                ),

                onPressed: () => _avancarRetirada(pedido),
              ),
            ),

            const SizedBox(height: 10),
          ],

          if (delivery && proximoStatusDelivery != null) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: proximoStatusDelivery == 'em_entrega'
                      ? Colors.purple
                      : proximoStatusDelivery == 'concluido'
                      ? Colors.blue
                      : Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                icon: Icon(_iconeAcaoDelivery(pedido)),
                label: Text(_textoAcaoDelivery(pedido)),
                onPressed: atualizando ? null : () => _avancarDelivery(pedido),
              ),
            ),
            const SizedBox(height: 10),
          ],

          SizedBox(
            width: double.infinity,

            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: finalizado ? Colors.grey : Colors.green,

                side: BorderSide(
                  color: finalizado ? Colors.grey : Colors.green,
                ),

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),

              icon: const Icon(Icons.visibility),

              label: const Text('Ver detalhes'),

              onPressed: () {
                _abrirDetalhes(pedido);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================

  // LISTA VAZIA

  // ============================================================

  Widget _mensagemVazia(String mensagem, IconData icone) {
    return Container(
      width: double.infinity,

      margin: const EdgeInsets.only(bottom: 10),

      padding: const EdgeInsets.all(25),

      decoration: BoxDecoration(
        color: Colors.grey.shade100,

        borderRadius: BorderRadius.circular(15),
      ),

      child: Column(
        children: [
          Icon(icone, color: Colors.grey.shade500, size: 35),

          const SizedBox(height: 8),

          Text(
            mensagem,

            textAlign: TextAlign.center,

            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
