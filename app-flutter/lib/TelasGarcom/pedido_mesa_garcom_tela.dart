import 'package:flutter/material.dart';

import '../Repositories/pedido_repository.dart';

class PedidoMesaGarcomTela extends StatefulWidget {
  const PedidoMesaGarcomTela({super.key});

  @override
  State<PedidoMesaGarcomTela> createState() => _PedidoMesaGarcomTelaState();
}

class _PedidoMesaGarcomTelaState extends State<PedidoMesaGarcomTela> {
  final PedidoRepository repository = PedidoRepository();

  Map<String, dynamic>? mesa;

  // Todos os pedidos da sessão da mesa, inclusive os já pagos.
  List<Map<String, dynamic>> pedidosSessao = [];

  // Pedido em rascunho usado somente para novos itens.
  Map<String, dynamic>? pedidoRascunhoAtual;
  List<Map<String, dynamic>> itensRascunho = [];

  bool carregando = true;
  bool inicializado = false;
  bool processando = false;
  String? erro;

  String? get sessaoId => mesa?["sessao_id"]?.toString();

  String? get pedidoRascunhoId => pedidoRascunhoAtual?["id"]?.toString();

  double _numero(dynamic valor) {
    if (valor is num) return valor.toDouble();
    return double.tryParse(valor?.toString() ?? "") ?? 0.0;
  }

  bool _pedidoPago(Map<String, dynamic> pedido) {
    return pedido["status_pagamento"]?.toString().toLowerCase() == "pago";
  }

  bool _pedidoCancelado(Map<String, dynamic> pedido) {
    return pedido["status"]?.toString().toLowerCase() == "cancelado";
  }

  double get totalPago {
    return pedidosSessao
        .where((p) => _pedidoPago(p) && !_pedidoCancelado(p))
        .fold(0.0, (soma, p) => soma + _numero(p["total"]));
  }

  double get totalEmAberto {
    return pedidosSessao
        .where((p) => !_pedidoPago(p) && !_pedidoCancelado(p))
        .fold(0.0, (soma, p) => soma + _numero(p["total"]));
  }

  int get quantidadePedidosEmAberto {
    return pedidosSessao
        .where((p) => !_pedidoPago(p) && !_pedidoCancelado(p))
        .length;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (inicializado) return;
    inicializado = true;

    final argumentos = ModalRoute.of(context)?.settings.arguments;

    if (argumentos is Map<String, dynamic>) {
      mesa = argumentos;
      carregarPedidosDaSessao();
    } else {
      setState(() {
        carregando = false;
        erro = "Mesa não informada.";
      });
    }
  }

  // ============================================================
  // CARREGAR TODOS OS PEDIDOS DA SESSÃO
  // ============================================================

  Future<void> carregarPedidosDaSessao({bool mostrarLoading = true}) async {
    final sessao = sessaoId;

    if (sessao == null || sessao.isEmpty) {
      if (!mounted) return;
      setState(() {
        carregando = false;
        erro = "Esta mesa não possui uma comanda aberta.";
      });
      return;
    }

    try {
      if (mostrarLoading && mounted) {
        setState(() {
          carregando = true;
          erro = null;
        });
      }

      final lista = await repository.listarPedidos(tipo: "mesa");

      final daSessao = lista.where((item) {
        return item["sessao_mesa_id"]?.toString() == sessao;
      }).toList();

      // Carrega os detalhes para termos itens e status de pagamento atualizados.
      final detalhados = <Map<String, dynamic>>[];

      for (final item in daSessao) {
        final id = item["id"]?.toString();
        if (id == null || id.isEmpty) continue;

        try {
          final detalhes = await repository.detalharPedido(id);
          detalhados.add(Map<String, dynamic>.from(detalhes));
        } catch (_) {
          // Se um detalhe falhar, mantém pelo menos o resumo retornado na lista.
          detalhados.add(Map<String, dynamic>.from(item));
        }
      }

      // Mantém os pedidos mais recentes primeiro.
      detalhados.sort((a, b) {
        final dataA =
            a["criado_em"]?.toString() ?? a["created_at"]?.toString() ?? "";
        final dataB =
            b["criado_em"]?.toString() ?? b["created_at"]?.toString() ?? "";
        return dataB.compareTo(dataA);
      });

      Map<String, dynamic>? rascunho;

      for (final item in detalhados) {
        if (item["status"]?.toString() == "rascunho") {
          rascunho = item;
          break;
        }
      }

      if (!mounted) return;

      setState(() {
        pedidosSessao = detalhados;
        pedidoRascunhoAtual = rascunho;
        itensRascunho = rascunho == null
            ? []
            : _converterItens(rascunho["itens"]);
        carregando = false;
        erro = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        carregando = false;
        erro = _limparErro(e);
      });
    }
  }

  List<Map<String, dynamic>> _converterItens(dynamic dados) {
    if (dados is! List) return [];

    return dados
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  // ============================================================
  // GARANTIR NOVO PEDIDO PARA NOVO CONSUMO
  // ============================================================

  Future<void> _garantirPedidoRascunho() async {
    final atual = pedidoRascunhoAtual;

    if (atual != null &&
        atual["status"]?.toString() == "rascunho" &&
        !_pedidoPago(atual)) {
      return;
    }

    final sessao = sessaoId;

    if (sessao == null || sessao.isEmpty) {
      throw Exception("Esta mesa não possui uma comanda aberta.");
    }

    final lista = await repository.listarPedidos(tipo: "mesa");

    Map<String, dynamic>? encontrado;

    for (final item in lista) {
      final mesmaSessao = item["sessao_mesa_id"]?.toString() == sessao;
      final status = item["status"]?.toString() ?? "";
      final pago = item["status_pagamento"]?.toString().toLowerCase() == "pago";

      if (mesmaSessao && status == "rascunho" && !pago) {
        encontrado = Map<String, dynamic>.from(item);
        break;
      }
    }

    if (encontrado == null) {
      encontrado = await repository.criarPedidoMesa(sessaoMesaId: sessao);
    }

    final detalhes = await repository.detalharPedido(
      encontrado["id"].toString(),
    );

    if (!mounted) return;

    setState(() {
      pedidoRascunhoAtual = detalhes;
      itensRascunho = _converterItens(detalhes["itens"]);
    });
  }

  Future<void> _atualizarRascunho() async {
    final id = pedidoRascunhoId;
    if (id == null) return;

    final detalhes = await repository.detalharPedido(id);

    if (!mounted) return;

    setState(() {
      pedidoRascunhoAtual = detalhes;
      itensRascunho = _converterItens(detalhes["itens"]);
    });
  }

  // ============================================================
  // CARDÁPIO / NOVOS ITENS
  // ============================================================

  Future<void> abrirCardapio() async {
    if (processando) return;

    try {
      // Primeiro abre o cardápio. O pedido só será criado se o garçom
      // realmente selecionar pelo menos um produto.
      final resultado = await Navigator.pushNamed(context, "/garcom/cardapio");

      if (!mounted) return;

      // Se voltou sem selecionar nada, não cria pedido vazio.
      if (resultado is! List || resultado.isEmpty) {
        return;
      }

      setState(() => processando = true);

      // Agora que existem produtos selecionados, procura um rascunho
      // existente ou cria um novo pedido para esta sessão.
      await _garantirPedidoRascunho();

      final id = pedidoRascunhoId;
      if (id == null || id.isEmpty) {
        throw Exception("Não foi possível identificar o novo pedido.");
      }

      for (final dado in resultado) {
        if (dado is! Map) continue;

        final produto = Map<String, dynamic>.from(dado);
        final produtoId = produto["produtoId"]?.toString();
        final quantidade = (produto["quantidade"] as num?)?.toInt() ?? 1;

        if (produtoId == null || produtoId.isEmpty || quantidade <= 0) {
          continue;
        }

        Map<String, dynamic>? itemExistente;

        for (final item in itensRascunho) {
          if (item["produto_id"]?.toString() == produtoId) {
            itemExistente = item;
            break;
          }
        }

        if (itemExistente != null) {
          final atual = (itemExistente["quantidade"] as num?)?.toInt() ?? 1;
          final nova = atual + quantidade;

          if (nova > 99) {
            throw Exception("A quantidade máxima permitida por produto é 99.");
          }

          await repository.atualizarItem(
            pedidoId: id,
            itemId: itemExistente["id"].toString(),
            quantidade: nova,
          );
        } else {
          if (quantidade > 99) {
            throw Exception("A quantidade máxima permitida por produto é 99.");
          }

          await repository.adicionarItem(
            pedidoId: id,
            produtoId: produtoId,
            quantidade: quantidade,
          );
        }

        await _atualizarRascunho();
      }

      await carregarPedidosDaSessao(mostrarLoading: false);

      if (!mounted) return;

      final quantidadeTotal = resultado.fold<int>(0, (total, dado) {
        if (dado is! Map) return total;
        return total + ((dado["quantidade"] as num?)?.toInt() ?? 0);
      });

      _mostrarMensagem(
        quantidadeTotal == 1
            ? "1 item adicionado ao novo pedido."
            : "$quantidadeTotal itens adicionados ao novo pedido.",
      );
    } catch (e) {
      if (!mounted) return;
      _mostrarMensagem(_limparErro(e), erro: true);
    } finally {
      if (mounted) {
        setState(() => processando = false);
      }
    }
  }

  Future<void> aumentarQuantidade(Map<String, dynamic> item) async {
    if (processando || pedidoRascunhoId == null) return;

    final quantidade = (item["quantidade"] as num?)?.toInt() ?? 1;

    if (quantidade >= 99) {
      _mostrarMensagem("Quantidade máxima permitida: 99.", erro: true);
      return;
    }

    try {
      setState(() => processando = true);

      await repository.atualizarItem(
        pedidoId: pedidoRascunhoId!,
        itemId: item["id"].toString(),
        quantidade: quantidade + 1,
      );

      await _atualizarRascunho();
      await carregarPedidosDaSessao(mostrarLoading: false);
    } catch (e) {
      if (!mounted) return;
      _mostrarMensagem(_limparErro(e), erro: true);
    } finally {
      if (mounted) setState(() => processando = false);
    }
  }

  Future<void> diminuirQuantidade(Map<String, dynamic> item) async {
    if (processando || pedidoRascunhoId == null) return;

    final quantidade = (item["quantidade"] as num?)?.toInt() ?? 1;

    try {
      setState(() => processando = true);

      if (quantidade > 1) {
        await repository.atualizarItem(
          pedidoId: pedidoRascunhoId!,
          itemId: item["id"].toString(),
          quantidade: quantidade - 1,
        );
      } else {
        await repository.removerItem(
          pedidoId: pedidoRascunhoId!,
          itemId: item["id"].toString(),
        );
      }

      await _atualizarRascunho();
      await carregarPedidosDaSessao(mostrarLoading: false);
    } catch (e) {
      if (!mounted) return;
      _mostrarMensagem(_limparErro(e), erro: true);
    } finally {
      if (mounted) setState(() => processando = false);
    }
  }

  // ============================================================
  // ENVIAR NOVO PEDIDO PARA PREPARO
  // ============================================================

  Future<void> confirmarPedido() async {
    final id = pedidoRascunhoId;

    if (id == null) {
      _mostrarMensagem("Não existe novo pedido para enviar.", erro: true);
      return;
    }

    if (itensRascunho.isEmpty) {
      _mostrarMensagem(
        "Adicione pelo menos um produto antes de confirmar.",
        erro: true,
      );
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Confirmar novo pedido"),
          content: const Text("Deseja enviar os novos itens para preparo?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text("Confirmar"),
            ),
          ],
        );
      },
    );

    if (confirmar != true) return;

    try {
      setState(() => processando = true);

      await repository.confirmarPedido(id);
      await carregarPedidosDaSessao(mostrarLoading: false);

      if (!mounted) return;

      _mostrarMensagem("Novo pedido confirmado e enviado para preparo.");
    } catch (e) {
      if (!mounted) return;
      _mostrarMensagem(_limparErro(e), erro: true);
    } finally {
      if (mounted) setState(() => processando = false);
    }
  }

  // ============================================================
  // FINALIZAÇÃO
  // ============================================================

  Future<void> abrirFinalizacao() async {
    if (sessaoId == null) return;

    final resultado = await Navigator.pushNamed(
      context,
      "/garcom/finalizacao",
      arguments: mesa,
    );

    if (!mounted) return;

    if (resultado == true) {
      Navigator.pop(context, true);
      return;
    }

    await carregarPedidosDaSessao(mostrarLoading: false);
  }

  // ============================================================
  // TEXTOS / CORES
  // ============================================================

  String _textoStatusPedido(Map<String, dynamic> pedido) {
    if (_pedidoPago(pedido)) return "Pago";

    switch (pedido["status"]?.toString()) {
      case "rascunho":
        return "Novo consumo";
      case "confirmado":
        return "Confirmado";
      case "em_preparo":
        return "Em preparo";
      case "pronto":
        return "Pronto";
      case "em_entrega":
        return "Em entrega";
      case "concluido":
        return "Concluído";
      case "cancelado":
        return "Cancelado";
      default:
        return pedido["status"]?.toString() ?? "Pedido";
    }
  }

  Color _corPedido(Map<String, dynamic> pedido) {
    if (_pedidoPago(pedido)) return Colors.green;

    switch (pedido["status"]?.toString()) {
      case "rascunho":
        return Colors.blue;
      case "confirmado":
      case "em_preparo":
        return Colors.orange;
      case "pronto":
      case "concluido":
        return Colors.green;
      case "cancelado":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _limparErro(Object e) {
    return e.toString().replaceFirst("Exception: ", "");
  }

  void _mostrarMensagem(String mensagem, {bool erro = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(mensagem),
          backgroundColor: erro ? Colors.red : Colors.green,
        ),
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
        child: carregando
            ? const Center(
                child: CircularProgressIndicator(color: Colors.green),
              )
            : erro != null
            ? _telaErro()
            : _conteudo(),
      ),
    );
  }

  Widget _telaErro() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 50),
            const SizedBox(height: 15),
            Text(erro!, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: carregarPedidosDaSessao,
              icon: const Icon(Icons.refresh),
              label: const Text("Tentar novamente"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _conteudo() {
    final numeroMesa = mesa?["numero"]?.toString() ?? "";

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new),
                onPressed: () => Navigator.pop(context, true),
              ),
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      "Pedido",
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "Mesa $numeroMesa",
                      style: const TextStyle(color: Colors.grey, fontSize: 17),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: processando
                    ? null
                    : () => carregarPedidosDaSessao(mostrarLoading: false),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const Icon(Icons.table_restaurant, color: Colors.green),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    quantidadePedidosEmAberto > 0
                        ? "$quantidadePedidosEmAberto pedido(s) em aberto"
                        : "Nenhum valor pendente",
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (processando)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.green,
                    ),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        Expanded(
          child: pedidosSessao.isEmpty
              ? const Center(
                  child: Text(
                    "Nenhum pedido nesta mesa.",
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () =>
                      carregarPedidosDaSessao(mostrarLoading: false),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: pedidosSessao.length,
                    itemBuilder: (context, index) {
                      return _cardPedido(pedidosSessao[index]);
                    },
                  ),
                ),
        ),

        _rodape(),
      ],
    );
  }

  Widget _cardPedido(Map<String, dynamic> pedidoAtual) {
    final cor = _corPedido(pedidoAtual);
    final pago = _pedidoPago(pedidoAtual);
    final rascunho = pedidoAtual["status"]?.toString() == "rascunho";
    final idAtual = pedidoAtual["id"]?.toString();
    final ehRascunhoAtual = rascunho && idAtual == pedidoRascunhoId;

    final codigo = pedidoAtual["codigo"]?.toString() ?? "Pedido";
    final listaItens = _converterItens(pedidoAtual["itens"]);
    final valorTotal = _numero(pedidoAtual["total"]);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: pago
              ? Colors.green.withValues(alpha: .35)
              : Colors.transparent,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    codigo,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: cor.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _textoStatusPedido(pedidoAtual),
                    style: TextStyle(color: cor, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (listaItens.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  "Nenhum produto neste pedido.",
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ...listaItens.map(
                (item) => _itemPedido(item, editavel: ehRascunhoAtual && !pago),
              ),

            const Divider(),

            Row(
              children: [
                Text(
                  pago ? "Total pago" : "Total do pedido",
                  style: TextStyle(
                    color: pago ? Colors.green : Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  "R\$ ${valorTotal.toStringAsFixed(2)}",
                  style: TextStyle(
                    color: pago ? Colors.green : Colors.black87,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            if (pago) ...[
              const SizedBox(height: 6),
              const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 18),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "Este valor já foi pago e não será cobrado novamente.",
                      style: TextStyle(color: Colors.green, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _itemPedido(Map<String, dynamic> item, {required bool editavel}) {
    final nome = item["produto_nome"]?.toString() ?? "Produto";
    final preco = _numero(item["preco_unitario"]);
    final quantidade = (item["quantidade"] as num?)?.toInt() ?? 1;
    final totalItem = _numero(item["total"]) > 0
        ? _numero(item["total"])
        : preco * quantidade;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 18,
            backgroundColor: Colors.green,
            child: Icon(Icons.fastfood, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  "R\$ ${preco.toStringAsFixed(2)} • "
                  "Total: R\$ ${totalItem.toStringAsFixed(2)}",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          if (editavel)
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                    onPressed: processando
                        ? null
                        : () => diminuirQuantidade(item),
                  ),
                  Text(
                    quantidade.toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.add_circle, color: Colors.green),
                    onPressed: processando
                        ? null
                        : () => aumentarQuantidade(item),
                  ),
                ],
              ),
            )
          else
            Text(
              "${quantidade}x",
              style: const TextStyle(
                color: Colors.green,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }

  Widget _rodape() {
    final possuiNovoPedido =
        pedidoRascunhoAtual != null && itensRascunho.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .08),
            blurRadius: 8,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        children: [
          if (totalPago > 0)
            _linhaValor("Já pago", totalPago, cor: Colors.green),
          _linhaValor(
            "Em aberto",
            totalEmAberto,
            cor: totalEmAberto > 0 ? Colors.orange : Colors.green,
          ),
          const Divider(),
          Row(
            children: [
              const Text(
                "Total a cobrar",
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const Spacer(),
              Text(
                "R\$ ${totalEmAberto.toStringAsFixed(2)}",
                style: TextStyle(
                  color: totalEmAberto > 0 ? Colors.orange : Colors.green,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 52),
                  ),
                  onPressed: processando ? null : abrirCardapio,
                  icon: const Icon(Icons.add),
                  label: const Text("Adicionar"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 52),
                  ),
                  onPressed: processando ? null : abrirFinalizacao,
                  icon: const Icon(Icons.receipt_long),
                  label: Text(
                    totalEmAberto > 0 ? "Fechar Conta" : "Fechar Mesa",
                  ),
                ),
              ),
            ],
          ),
          if (possuiNovoPedido) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green,
                  minimumSize: const Size(0, 48),
                ),
                onPressed: processando ? null : confirmarPedido,
                icon: const Icon(Icons.restaurant),
                label: const Text("Enviar novo pedido para preparo"),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _linhaValor(String titulo, double valor, {Color? cor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Text(
            titulo,
            style: TextStyle(
              color: cor ?? Colors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            "R\$ ${valor.toStringAsFixed(2)}",
            style: TextStyle(color: cor, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
