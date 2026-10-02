import 'package:flutter/material.dart';

import '../Repositories/mesa_repository.dart';
import '../Repositories/pagamento_repository.dart';
import '../Repositories/pedido_repository.dart';

class FinalizacaoGarcomTela extends StatefulWidget {
  final Map<String, dynamic> mesa;

  const FinalizacaoGarcomTela({super.key, required this.mesa});

  @override
  State<FinalizacaoGarcomTela> createState() => _FinalizacaoGarcomTelaState();
}

class _FinalizacaoGarcomTelaState extends State<FinalizacaoGarcomTela> {
  final MesaRepository mesaRepository = MesaRepository();
  final PagamentoRepository pagamentoRepository = PagamentoRepository();
  final PedidoRepository pedidoRepository = PedidoRepository();

  Map<String, dynamic>? dadosSessao;

  String pagamento = "";
  bool carregando = true;
  bool processando = false;
  String? erro;

  String get sessaoId => widget.mesa["sessao_id"]?.toString() ?? "";

  Map<String, dynamic> get sessao {
    final dados = dadosSessao?["sessao"];
    if (dados is Map<String, dynamic>) return dados;
    if (dados is Map) return Map<String, dynamic>.from(dados);
    return {};
  }

  List<Map<String, dynamic>> get pedidos {
    final dados = dadosSessao?["pedidos"];
    if (dados is! List) return [];

    return dados
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  List<Map<String, dynamic>> get itens {
    final dados = dadosSessao?["itens"];
    if (dados is! List) return [];

    return dados
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Map<String, dynamic> get totais {
    final dados = dadosSessao?["totais"];
    if (dados is Map<String, dynamic>) return dados;
    if (dados is Map) return Map<String, dynamic>.from(dados);
    return {};
  }

  double _numero(dynamic valor) {
    if (valor is num) return valor.toDouble();
    return double.tryParse(valor?.toString() ?? "") ?? 0.0;
  }

  double get subtotal => _numero(totais["subtotal"]);
  double get taxaServico => _numero(totais["taxa_servico"]);
  double get total => _numero(totais["total"]);
  double get totalPago => _numero(totais["total_pago"]);

  double get restante {
    final valor = total - totalPago;
    return valor < 0 ? 0 : valor;
  }

  bool get servicoAceito => sessao["servico_aceito"] == true;

  bool _pedidoPago(Map<String, dynamic> pedido) {
    return pedido["status_pagamento"]?.toString().toLowerCase() == "pago";
  }

  @override
  void initState() {
    super.initState();
    carregarConta();
  }

  // ============================================================
  // CARREGAR CONTA
  // ============================================================

  Future<void> carregarConta() async {
    if (sessaoId.isEmpty) {
      if (!mounted) return;

      setState(() {
        carregando = false;
        erro = "Esta mesa não possui uma comanda aberta.";
      });
      return;
    }

    try {
      setState(() {
        carregando = true;
        erro = null;
      });

      final dados = await mesaRepository.detalharSessao(sessaoId);

      if (!mounted) return;

      setState(() {
        dadosSessao = dados;
        carregando = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        carregando = false;
        erro = _limparErro(e);
      });
    }
  }

  // ============================================================
  // TAXA DE SERVIÇO
  // ============================================================

  Future<void> alterarServico(bool aceito) async {
    if (processando) return;

    try {
      setState(() => processando = true);

      await mesaRepository.definirServico(sessaoId: sessaoId, aceito: aceito);

      await carregarConta();
    } catch (e) {
      if (!mounted) return;
      _mostrarMensagem(_limparErro(e), erro: true);
    } finally {
      if (mounted) setState(() => processando = false);
    }
  }

  // ============================================================
  // PAGAMENTO
  // ============================================================

  String metodoBackend() {
    switch (pagamento) {
      case "Dinheiro":
        return "dinheiro";
      case "Pix":
        return "pix";
      case "Crédito":
        return "cartao_credito";
      case "Débito":
        return "cartao_debito";
      default:
        throw Exception("Selecione uma forma de pagamento.");
    }
  }

  Future<void> finalizarPagamento() async {
    if (pedidos.isEmpty) {
      _mostrarMensagem("Não existem pedidos nesta comanda.", erro: true);
      return;
    }

    // Se já está tudo pago, não exige escolher pagamento novamente.
    if (restante > 0 && pagamento.isEmpty) {
      _mostrarMensagem("Selecione uma forma de pagamento.", erro: true);
      return;
    }

    final mensagem = restante > 0
        ? "Confirmar pagamento de "
              "R\$ ${restante.toStringAsFixed(2)} via $pagamento "
              "e fechar a mesa?"
        : "Todos os pedidos desta mesa já estão pagos. "
              "Deseja fechar a mesa?";

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(restante > 0 ? "Finalizar conta" : "Fechar mesa"),
          content: Text(mensagem),
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

      // ----------------------------------------------------------
      // COBRAR SOMENTE PEDIDOS AINDA NÃO PAGOS
      // ----------------------------------------------------------

      if (restante > 0) {
        for (final pedido in pedidos) {
          final pedidoId = pedido["id"]?.toString();
          final status = pedido["status"]?.toString() ?? "";
          final statusPagamento = pedido["status_pagamento"]?.toString() ?? "";

          if (pedidoId == null ||
              pedidoId.isEmpty ||
              status == "cancelado" ||
              statusPagamento == "pago") {
            continue;
          }

          if (status == "rascunho") {
            await pedidoRepository.confirmarPedido(pedidoId);
          }

          final pagamentoCriado = await pagamentoRepository.criarPagamento(
            pedidoId: pedidoId,
            metodo: metodoBackend(),
          );

          final pagamentoId = pagamentoCriado["id"]?.toString();

          if (pagamentoId == null || pagamentoId.isEmpty) {
            throw Exception("O pagamento foi criado sem identificador.");
          }

          await pagamentoRepository.confirmarPagamento(pagamentoId);
        }

        await carregarConta();
      }

      // ----------------------------------------------------------
      // CONCLUIR OS PEDIDOS PAGOS AO FECHAR A MESA
      // ----------------------------------------------------------

      final pedidosAtualizados = List<Map<String, dynamic>>.from(pedidos);

      for (final pedido in pedidosAtualizados) {
        final pedidoId = pedido["id"]?.toString();
        var status = pedido["status"]?.toString() ?? "";
        final statusPagamento = pedido["status_pagamento"]?.toString() ?? "";

        if (pedidoId == null ||
            pedidoId.isEmpty ||
            status == "cancelado" ||
            status == "concluido" ||
            statusPagamento != "pago") {
          continue;
        }

        if (status == "confirmado") {
          await pedidoRepository.alterarStatus(
            pedidoId: pedidoId,
            status: "em_preparo",
          );
          status = "em_preparo";
        }

        if (status == "em_preparo") {
          await pedidoRepository.alterarStatus(
            pedidoId: pedidoId,
            status: "pronto",
          );
          status = "pronto";
        }

        if (status == "pronto") {
          await pedidoRepository.alterarStatus(
            pedidoId: pedidoId,
            status: "concluido",
          );
        }
      }

      // ----------------------------------------------------------
      // FECHAR SESSÃO / LIBERAR MESA
      // ----------------------------------------------------------

      await mesaRepository.fecharSessao(sessaoId);

      if (!mounted) return;

      _mostrarMensagem(
        restante > 0
            ? "Pagamento confirmado e mesa liberada."
            : "Mesa fechada com sucesso.",
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      await carregarConta();

      if (!mounted) return;

      _mostrarMensagem(_limparErro(e), erro: true);
    } finally {
      if (mounted) setState(() => processando = false);
    }
  }

  String _limparErro(Object e) {
    return e.toString().replaceFirst("Exception: ", "");
  }

  void _mostrarMensagem(String mensagem, {bool erro = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
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
      appBar: AppBar(
        backgroundColor: Colors.green,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: processando ? null : () => Navigator.pop(context),
        ),
        title: const Text(
          "Finalização",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: processando ? null : carregarConta,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
      body: carregando
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : erro != null
          ? _telaErro()
          : _conteudo(),
    );
  }

  Widget _telaErro() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 55),
            const SizedBox(height: 15),
            Text(erro!, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: carregarConta,
              icon: const Icon(Icons.refresh),
              label: const Text("Tentar novamente"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _conteudo() {
    final numeroMesa =
        sessao["mesa_numero"]?.toString() ??
        widget.mesa["numero"]?.toString() ??
        "";

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Mesa $numeroMesa",
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),
          Text(
            "${sessao["qtd_pessoas"] ?? 0} pessoa(s)",
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          const Text(
            "Resumo da conta",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),

          Expanded(
            child: itens.isEmpty
                ? const Center(
                    child: Text(
                      "Nenhum item nesta comanda.",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: itens.length,
                    itemBuilder: (context, index) {
                      return _cardItem(itens[index]);
                    },
                  ),
          ),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              "Taxa de serviço (10%)",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              servicoAceito ? "Incluída na conta" : "Não incluída na conta",
            ),
            value: servicoAceito,
            activeThumbColor: Colors.green,
            onChanged: processando ? null : alterarServico,
          ),

          const Divider(),

          _linhaValor("Subtotal", subtotal),
          _linhaValor("Taxa de serviço", taxaServico),

          if (totalPago > 0)
            _linhaValor("Já pago", totalPago, cor: Colors.green),

          const SizedBox(height: 5),

          Row(
            children: [
              const Text(
                "Restante a pagar",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                "R\$ ${restante.toStringAsFixed(2)}",
                style: TextStyle(
                  color: restante > 0 ? Colors.orange : Colors.green,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          if (totalPago > 0) ...[
            const SizedBox(height: 5),
            Text(
              "Total consumido: R\$ ${total.toStringAsFixed(2)}",
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],

          const SizedBox(height: 20),

          // Só pede nova forma de pagamento se existir saldo pendente.
          if (restante > 0) ...[
            const Text(
              "Forma de pagamento",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                pagamentoBotao("Dinheiro", Icons.money),
                const SizedBox(width: 10),
                pagamentoBotao("Pix", Icons.pix),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                pagamentoBotao("Crédito", Icons.credit_card),
                const SizedBox(width: 10),
                pagamentoBotao("Débito", Icons.credit_card),
              ],
            ),
            const SizedBox(height: 20),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Todos os pedidos desta mesa já estão pagos.",
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: processando ? null : finalizarPagamento,
              child: processando
                  ? const SizedBox(
                      width: 25,
                      height: 25,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      restante > 0
                          ? "Finalizar • R\$ ${restante.toStringAsFixed(2)}"
                          : "Fechar Mesa",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardItem(Map<String, dynamic> item) {
    final nome = item["produto_nome"]?.toString() ?? "Produto";
    final quantidade = (item["quantidade"] as num?)?.toInt() ?? 1;
    final preco = _numero(item["preco_unitario"]);
    final valor = _numero(item["total"]);
    final pedidoId = item["pedido_id"]?.toString();

    Map<String, dynamic>? pedidoDoItem;

    if (pedidoId != null) {
      for (final p in pedidos) {
        if (p["id"]?.toString() == pedidoId) {
          pedidoDoItem = p;
          break;
        }
      }
    }

    final pago = pedidoDoItem != null && _pedidoPago(pedidoDoItem);

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: pago ? Colors.green : Colors.orange,
          child: Icon(pago ? Icons.check : Icons.fastfood, color: Colors.white),
        ),
        title: Text(nome, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          "$quantidade x R\$ ${preco.toStringAsFixed(2)}"
          "${pago ? " • PAGO" : " • EM ABERTO"}",
          style: TextStyle(
            color: pago ? Colors.green : null,
            fontWeight: pago ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        trailing: Text(
          "R\$ ${valor.toStringAsFixed(2)}",
          style: TextStyle(
            color: pago ? Colors.green : Colors.orange,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _linhaValor(String titulo, double valor, {Color? cor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(titulo, style: TextStyle(color: cor ?? Colors.grey)),
          const Spacer(),
          Text(
            "R\$ ${valor.toStringAsFixed(2)}",
            style: TextStyle(color: cor, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget pagamentoBotao(String texto, IconData icone) {
    final selecionado = pagamento == texto;

    return Expanded(
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: selecionado ? Colors.green : Colors.green.shade200,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        icon: Icon(icone, color: Colors.white),
        label: Text(texto, style: const TextStyle(color: Colors.white)),
        onPressed: processando
            ? null
            : () {
                setState(() {
                  pagamento = texto;
                });
              },
      ),
    );
  }
}
