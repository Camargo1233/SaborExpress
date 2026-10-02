import 'package:flutter/material.dart';

import '../Repositories/mesa_repository.dart';
import 'finalizacao_garcom_tela.dart';

class MesasGarcomTela extends StatefulWidget {
  const MesasGarcomTela({super.key});

  @override
  State<MesasGarcomTela> createState() => _MesasGarcomTelaState();
}

class _MesasGarcomTelaState extends State<MesasGarcomTela> {
  final MesaRepository repository = MesaRepository();

  List<Map<String, dynamic>> mesas = [];

  bool carregando = true;
  String? erro;

  @override
  void initState() {
    super.initState();
    carregarMesas();
  }

  // ============================================================
  // CARREGAR MESAS DO BANCO
  // ============================================================

  Future<void> carregarMesas() async {
    if (mounted) {
      setState(() {
        carregando = true;
        erro = null;
      });
    }

    try {
      final lista = await repository.listarMesas();

      if (!mounted) return;

      setState(() {
        mesas = lista.where((mesa) {
          return mesa["ativo"] != false;
        }).toList();

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
  // ABRIR OPÇÕES DA MESA
  // ============================================================

  void abrirOpcoesMesa(Map<String, dynamic> mesa) {
    final status = mesa["status"]?.toString().toLowerCase() ?? "livre";

    if (status == "livre") {
      mostrarDialogOcuparMesa(mesa);
      return;
    }

    final sessaoId = mesa["sessao_id"]?.toString();

    if (sessaoId == null || sessaoId.isEmpty) {
      _mostrarMensagem(
        "A mesa está ocupada, mas não possui uma comanda aberta.",
        erro: true,
      );
      return;
    }

    abrirPedido(mesa);
  }

  // ============================================================
  // DIÁLOGO PARA OCUPAR MESA
  // ============================================================

  Future<void> mostrarDialogOcuparMesa(Map<String, dynamic> mesa) async {
    final controller = TextEditingController(text: "1");

    final resultado = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            "Mesa ${mesa["numero"]}",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Informe a quantidade de pessoas:"),
              const SizedBox(height: 15),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Quantidade de pessoas",
                  prefixIcon: const Icon(Icons.people, color: Colors.green),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final quantidade = int.tryParse(controller.text.trim());

                if (quantidade == null || quantidade <= 0 || quantidade > 50) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Informe uma quantidade válida de pessoas.",
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                Navigator.pop(dialogContext, quantidade);
              },
              child: const Text("Ocupar mesa"),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (resultado == null) {
      return;
    }

    await ocuparMesa(mesa, resultado);
  }

  // ============================================================
  // OCUPAR MESA / ABRIR COMANDA
  // ============================================================

  Future<void> ocuparMesa(Map<String, dynamic> mesa, int qtdPessoas) async {
    try {
      _mostrarCarregando();

      final sessao = await repository.abrirSessao(
        mesaId: mesa["id"].toString(),
        qtdPessoas: qtdPessoas,
      );

      if (!mounted) return;

      Navigator.of(context, rootNavigator: true).pop();

      _mostrarMensagem("Mesa ${mesa["numero"]} ocupada com sucesso!");

      await carregarMesas();

      final mesaAtualizada = mesas.firstWhere(
        (item) => item["id"].toString() == mesa["id"].toString(),
        orElse: () => {
          ...mesa,
          "status": "ocupada",
          "sessao_id": sessao["id"],
          "qtd_pessoas": qtdPessoas,
        },
      );

      if (!mounted) return;

      abrirPedido(mesaAtualizada);
    } catch (e) {
      if (!mounted) return;

      _fecharCarregamentoSeAberto();

      _mostrarMensagem(_limparErro(e), erro: true);
    }
  }

  // ============================================================
  // ABRIR PEDIDO
  // ============================================================

  Future<void> abrirPedido(Map<String, dynamic> mesa) async {
    final resultado = await Navigator.pushNamed(
      context,
      "/garcom/pedido",
      arguments: mesa,
    );

    // Quando voltar do pedido, atualizamos a situação da mesa.
    if (resultado != null || mounted) {
      await carregarMesas();
    }
  }

  // ============================================================
  // FINALIZAR MESA
  // ============================================================

  Future<void> finalizarMesa(Map<String, dynamic> mesa) async {
    final sessaoId = mesa["sessao_id"]?.toString();

    if (sessaoId == null || sessaoId.isEmpty) {
      _mostrarMensagem("Esta mesa não possui uma comanda aberta.", erro: true);
      return;
    }

    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FinalizacaoGarcomTela(mesa: mesa)),
    );

    if (resultado == true) {
      await carregarMesas();
    }
  }

  // ============================================================
  // CORES E TEXTOS
  // ============================================================

  Color corMesa(Map<String, dynamic> mesa) {
    final status = mesa["status"]?.toString().toLowerCase() ?? "livre";

    final quantidadePedidos = (mesa["qtd_pedidos"] as num?)?.toInt() ?? 0;

    if (status == "livre") {
      return Colors.green;
    }

    if (quantidadePedidos > 0) {
      return Colors.red;
    }

    return Colors.orange;
  }

  String textoStatus(Map<String, dynamic> mesa) {
    final status = mesa["status"]?.toString().toLowerCase() ?? "livre";

    final quantidadePedidos = (mesa["qtd_pedidos"] as num?)?.toInt() ?? 0;

    if (status == "livre") {
      return "Livre";
    }

    if (quantidadePedidos > 0) {
      return "Pedido em andamento";
    }

    return "Ocupada";
  }

  // ============================================================
  // AUXILIARES
  // ============================================================

  String _limparErro(Object erro) {
    return erro.toString().replaceFirst("Exception: ", "");
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

  void _mostrarCarregando() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return const Center(
          child: CircularProgressIndicator(color: Colors.green),
        );
      },
    );
  }

  void _fecharCarregamentoSeAberto() {
    if (!mounted) return;

    final navigator = Navigator.of(context, rootNavigator: true);

    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.green,
        centerTitle: true,

        leading: IconButton(
          tooltip: "Sair",
          icon: const Icon(Icons.logout, color: Colors.white),
          onPressed: () {
            Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
          },
        ),

        title: const Text(
          "Mesas",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),

        actions: [
          IconButton(
            onPressed: carregarMesas,
            tooltip: "Atualizar mesas",
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),

      body: _construirConteudo(),
    );
  }

  // ============================================================
  // CONTEÚDO
  // ============================================================

  Widget _construirConteudo() {
    if (carregando) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.green),
      );
    }

    if (erro != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 50),
              const SizedBox(height: 15),
              Text(erro!, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: carregarMesas,
                icon: const Icon(Icons.refresh),
                label: const Text("Tentar novamente"),
              ),
            ],
          ),
        ),
      );
    }

    if (mesas.isEmpty) {
      return const Center(child: Text("Nenhuma mesa cadastrada."));
    }

    return RefreshIndicator(
      onRefresh: carregarMesas,
      child: ListView.builder(
        padding: const EdgeInsets.all(15),
        itemCount: mesas.length,
        itemBuilder: (context, index) {
          final mesa = mesas[index];

          final cor = corMesa(mesa);
          final status = textoStatus(mesa);

          final numero = mesa["numero"]?.toString() ?? "";

          final capacidade = (mesa["capacidade"] as num?)?.toInt() ?? 0;

          final qtdPessoas = (mesa["qtd_pessoas"] as num?)?.toInt();

          final qtdPedidos = (mesa["qtd_pedidos"] as num?)?.toInt() ?? 0;

          final total = (mesa["total_aberto"] as num?)?.toDouble() ?? 0.0;

          return InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              abrirOpcoesMesa(mesa);
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 15),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .08),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    height: 60,
                    width: 60,
                    decoration: BoxDecoration(
                      color: cor,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Center(
                      child: Text(
                        numero,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 18),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Mesa $numero",
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Row(
                          children: [
                            CircleAvatar(radius: 6, backgroundColor: cor),
                            const SizedBox(width: 8),
                            Text(
                              status,
                              style: TextStyle(
                                color: cor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 6),

                        Text(
                          qtdPessoas != null
                              ? "$qtdPessoas pessoa(s) • Capacidade: $capacidade"
                              : "Capacidade: $capacidade",
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),

                        if (qtdPedidos > 0) ...[
                          const SizedBox(height: 5),
                          Text(
                            "$qtdPedidos pedido(s) • "
                            "R\$ ${total.toStringAsFixed(2)}",
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const Icon(Icons.arrow_forward_ios, size: 18),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
