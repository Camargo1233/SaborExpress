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

    if (dados is Map<String, dynamic>) {
      return dados;
    }

    return {};
  }

  List<Map<String, dynamic>> get pedidos {
    final dados = dadosSessao?["pedidos"];

    if (dados is! List) {
      return [];
    }

    return dados.map((item) => Map<String, dynamic>.from(item)).toList();
  }

  List<Map<String, dynamic>> get itens {
    final dados = dadosSessao?["itens"];

    if (dados is! List) {
      return [];
    }

    return dados.map((item) => Map<String, dynamic>.from(item)).toList();
  }

  Map<String, dynamic> get totais {
    final dados = dadosSessao?["totais"];

    if (dados is Map<String, dynamic>) {
      return dados;
    }

    return {};
  }

  double get subtotal => (totais["subtotal"] as num?)?.toDouble() ?? 0.0;

  double get taxaServico => (totais["taxa_servico"] as num?)?.toDouble() ?? 0.0;

  double get total => (totais["total"] as num?)?.toDouble() ?? 0.0;

  double get totalPago => (totais["total_pago"] as num?)?.toDouble() ?? 0.0;

  double get restante {
    final valor = total - totalPago;

    return valor < 0 ? 0 : valor;
  }

  bool get servicoAceito => sessao["servico_aceito"] == true;

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
      setState(() {
        processando = true;
      });

      await mesaRepository.definirServico(sessaoId: sessaoId, aceito: aceito);

      await carregarConta();
    } catch (e) {
      if (!mounted) return;

      _mostrarMensagem(_limparErro(e), erro: true);
    } finally {
      if (mounted) {
        setState(() {
          processando = false;
        });
      }
    }
  }

  // ============================================================
  // FORMA DE PAGAMENTO
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

  // ============================================================
  // FINALIZAR PAGAMENTO
  // ============================================================

  Future<void> finalizarPagamento() async {
    if (pagamento.isEmpty) {
      _mostrarMensagem("Selecione uma forma de pagamento.", erro: true);

      return;
    }

    if (pedidos.isEmpty) {
      _mostrarMensagem("Não existem pedidos nesta comanda.", erro: true);

      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Finalizar conta"),
          content: Text(
            "Confirmar pagamento de "
            "R\$ ${restante.toStringAsFixed(2)} "
            "via $pagamento?",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text("Confirmar"),
            ),
          ],
        );
      },
    );

    if (confirmar != true) {
      return;
    }

    try {
      setState(() {
        processando = true;
      });

      // ----------------------------------------------------------
      // PAGAR TODOS OS PEDIDOS AINDA NÃO PAGOS
      // ----------------------------------------------------------

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

        // O backend exige que o pedido tenha sido confirmado
        // antes de receber pagamento.
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

      // Atualiza os valores depois dos pagamentos.
      await carregarConta();

      // ----------------------------------------------------------
      // TENTAR CONCLUIR PEDIDOS
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

        // O pedido precisa respeitar a máquina de estados.
        // Por isso avançamos pelas etapas.
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
      // FECHAR COMANDA
      // ----------------------------------------------------------

      await mesaRepository.fecharSessao(sessaoId);

      if (!mounted) return;

      _mostrarMensagem("Pagamento confirmado e mesa liberada.");

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      await carregarConta();

      if (!mounted) return;

      _mostrarMensagem(_limparErro(e), erro: true);
    } finally {
      if (mounted) {
        setState(() {
          processando = false;
        });
      }
    }
  }

  // ============================================================
  // AUXILIARES
  // ============================================================

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
          onPressed: processando
              ? null
              : () {
                  Navigator.pop(context);
                },
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
                      final item = itens[index];

                      final nome =
                          item["produto_nome"]?.toString() ?? "Produto";

                      final quantidade =
                          (item["quantidade"] as num?)?.toInt() ?? 1;

                      final valor = (item["total"] as num?)?.toDouble() ?? 0.0;

                      return Card(
                        elevation: 3,
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.green,
                            child: Icon(Icons.fastfood, color: Colors.white),
                          ),
                          title: Text(
                            nome,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            "$quantidade x "
                            "R\$ ${((item["preco_unitario"] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}",
                          ),
                          trailing: Text(
                            "R\$ ${valor.toStringAsFixed(2)}",
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // ======================================================
          // TAXA DE SERVIÇO
          // ======================================================
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

          if (totalPago > 0) _linhaValor("Já pago", totalPago),

          const SizedBox(height: 5),

          Row(
            children: [
              const Text(
                "Total",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                "R\$ ${total.toStringAsFixed(2)}",
                style: const TextStyle(
                  color: Colors.green,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

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

  Widget _linhaValor(String titulo, double valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(titulo, style: const TextStyle(color: Colors.grey)),
          const Spacer(),
          Text(
            "R\$ ${valor.toStringAsFixed(2)}",
            style: const TextStyle(fontWeight: FontWeight.w600),
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
