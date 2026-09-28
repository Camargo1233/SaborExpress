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
  Map<String, dynamic>? pedido;
  List<Map<String, dynamic>> itens = [];
  bool carregando = true;
  bool inicializado = false;
  bool processando = false;
  String? erro;
  String? get pedidoId => pedido?["id"]?.toString();
  String? get sessaoId => mesa?["sessao_id"]?.toString();
  String get statusPedido => pedido?["status"]?.toString() ?? "rascunho";
  bool get pedidoRascunho => statusPedido == "rascunho";
  double get subtotal => (pedido?["subtotal"] as num?)?.toDouble() ?? 0.0;
  double get taxaServico =>
      (pedido?["taxa_servico"] as num?)?.toDouble() ?? 0.0;
  double get total => (pedido?["total"] as num?)?.toDouble() ?? 0.0;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (inicializado) return;
    inicializado = true;
    final argumentos = ModalRoute.of(context)?.settings.arguments;
    if (argumentos is Map<String, dynamic>) {
      mesa = argumentos;
      carregarPedido();
    } else {
      setState(() {
        carregando = false;
        erro = "Mesa não informada.";
      });
    }
  }

  // ============================================================
  // CARREGAR OU CRIAR PEDIDO
  // ============================================================
  Future<void> carregarPedido() async {
    final sessao = sessaoId;
    if (sessao == null || sessao.isEmpty) {
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
      final pedidos = await repository.listarPedidos(tipo: "mesa");
      Map<String, dynamic>? encontrado;
      // Primeiro procura um rascunho da sessão.
      // Isso evita criar pedidos duplicados.
      for (final item in pedidos) {
        final mesmaSessao = item["sessao_mesa_id"]?.toString() == sessao;
        final status = item["status"]?.toString() ?? "";
        if (mesmaSessao && status == "rascunho") {
          encontrado = item;
          break;
        }
      }
      // Se não existir rascunho, procura o pedido ativo
      // mais recente da sessão para exibi-lo.
      if (encontrado == null) {
        for (final item in pedidos) {
          final mesmaSessao = item["sessao_mesa_id"]?.toString() == sessao;
          final status = item["status"]?.toString() ?? "";
          final ativo = status != "concluido" && status != "cancelado";
          if (mesmaSessao && ativo) {
            encontrado = item;
            break;
          }
        }
      }
      // Se a mesa ainda não possui nenhum pedido,
      // cria o primeiro rascunho.
      if (encontrado == null) {
        encontrado = await repository.criarPedidoMesa(sessaoMesaId: sessao);
      }
      final detalhes = await repository.detalharPedido(
        encontrado["id"].toString(),
      );
      if (!mounted) return;
      setState(() {
        pedido = detalhes;
        itens = _converterItens(detalhes["itens"]);
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
  // ATUALIZAR PEDIDO
  // ============================================================
  Future<void> atualizarPedido() async {
    final id = pedidoId;
    if (id == null) return;
    try {
      final detalhes = await repository.detalharPedido(id);
      if (!mounted) return;
      setState(() {
        pedido = detalhes;
        itens = _converterItens(detalhes["itens"]);
      });
    } catch (e) {
      if (!mounted) return;
      _mostrarMensagem(_limparErro(e), erro: true);
    }
  }

  List<Map<String, dynamic>> _converterItens(dynamic dados) {
    if (dados is! List) {
      return [];
    }
    return dados.map((item) => Map<String, dynamic>.from(item)).toList();
  }

  // ============================================================
  // ABRIR CARDÁPIO / ADICIONAR NOVOS ITENS
  // ============================================================
  Future<void> abrirCardapio() async {
    if (processando) return;

    final sessao = sessaoId;

    if (sessao == null || sessao.isEmpty) {
      _mostrarMensagem("Esta mesa não possui uma comanda aberta.", erro: true);
      return;
    }

    try {
      setState(() {
        processando = true;
      });

      // Se o pedido atual já foi enviado para preparo, procura um
      // rascunho da mesma mesa. Se não existir, cria um novo pedido
      // dentro da mesma comanda/sessão.
      if (!pedidoRascunho) {
        final pedidos = await repository.listarPedidos(tipo: "mesa");
        Map<String, dynamic>? rascunhoExistente;

        for (final item in pedidos) {
          final mesmaSessao = item["sessao_mesa_id"]?.toString() == sessao;
          final status = item["status"]?.toString() ?? "";

          if (mesmaSessao && status == "rascunho") {
            rascunhoExistente = item;
            break;
          }
        }

        Map<String, dynamic> detalhes;

        if (rascunhoExistente != null) {
          detalhes = await repository.detalharPedido(
            rascunhoExistente["id"].toString(),
          );
        } else {
          final novoPedido = await repository.criarPedidoMesa(
            sessaoMesaId: sessao,
          );
          detalhes = await repository.detalharPedido(
            novoPedido["id"].toString(),
          );
        }

        if (!mounted) return;

        setState(() {
          pedido = detalhes;
          itens = _converterItens(detalhes["itens"]);
        });
      }

      if (!mounted) return;

      setState(() {
        processando = false;
      });

      // O garçom pode selecionar vários produtos.
      // Depois de cada produto, o cardápio abre novamente.
      // Ao apertar voltar, retorna para a tela da mesa.
      while (mounted && pedidoRascunho) {
        final produto = await Navigator.pushNamed(context, "/garcom/cardapio");

        if (produto is! Map<String, dynamic>) {
          break;
        }

        final produtoId = produto["produtoId"]?.toString();

        if (produtoId == null || produtoId.isEmpty || pedidoId == null) {
          continue;
        }

        await adicionarProduto(
          produtoId,
          produto["nome"]?.toString() ?? "Produto",
        );
      }
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
  // ADICIONAR PRODUTO
  // ============================================================
  Future<void> adicionarProduto(String produtoId, String nome) async {
    final id = pedidoId;
    if (id == null) return;
    try {
      setState(() {
        processando = true;
      });
      Map<String, dynamic>? itemExistente;
      for (final item in itens) {
        if (item["produto_id"]?.toString() == produtoId) {
          itemExistente = item;
          break;
        }
      }
      if (itemExistente != null) {
        final quantidadeAtual =
            (itemExistente["quantidade"] as num?)?.toInt() ?? 1;
        await repository.atualizarItem(
          pedidoId: id,
          itemId: itemExistente["id"].toString(),
          quantidade: quantidadeAtual + 1,
        );
      } else {
        await repository.adicionarItem(
          pedidoId: id,
          produtoId: produtoId,
          quantidade: 1,
        );
      }
      await atualizarPedido();
      if (!mounted) return;
      _mostrarMensagem("$nome adicionado ao pedido.");
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
  // AUMENTAR QUANTIDADE
  // ============================================================
  Future<void> aumentarQuantidade(Map<String, dynamic> item) async {
    if (!pedidoRascunho || processando) {
      return;
    }
    final id = pedidoId;
    if (id == null) return;
    final quantidade = (item["quantidade"] as num?)?.toInt() ?? 1;
    if (quantidade >= 99) {
      _mostrarMensagem("Quantidade máxima permitida: 99.", erro: true);
      return;
    }
    try {
      setState(() {
        processando = true;
      });
      await repository.atualizarItem(
        pedidoId: id,
        itemId: item["id"].toString(),
        quantidade: quantidade + 1,
      );
      await atualizarPedido();
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
  // DIMINUIR / REMOVER
  // ============================================================
  Future<void> diminuirQuantidade(Map<String, dynamic> item) async {
    if (!pedidoRascunho || processando) {
      return;
    }
    final id = pedidoId;
    if (id == null) return;
    final quantidade = (item["quantidade"] as num?)?.toInt() ?? 1;
    try {
      setState(() {
        processando = true;
      });
      if (quantidade > 1) {
        await repository.atualizarItem(
          pedidoId: id,
          itemId: item["id"].toString(),
          quantidade: quantidade - 1,
        );
      } else {
        await repository.removerItem(
          pedidoId: id,
          itemId: item["id"].toString(),
        );
      }
      await atualizarPedido();
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
  // CONFIRMAR PEDIDO
  // ============================================================
  Future<void> confirmarPedido() async {
    final id = pedidoId;
    if (id == null) return;
    if (itens.isEmpty) {
      _mostrarMensagem(
        "Adicione pelo menos um produto antes de confirmar.",
        erro: true,
      );
      return;
    }
    if (!pedidoRascunho) {
      _mostrarMensagem("Este pedido já foi confirmado.", erro: true);
      return;
    }
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Confirmar pedido"),
          content: const Text(
            "Deseja confirmar este pedido e enviá-lo para preparo?",
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
      await repository.confirmarPedido(id);
      await atualizarPedido();
      if (!mounted) return;
      _mostrarMensagem("Pedido confirmado e enviado para preparo.");
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
  // FINALIZAÇÃO
  // ============================================================
  Future<void> abrirFinalizacao() async {
    if (sessaoId == null) {
      return;
    }
    final resultado = await Navigator.pushNamed(
      context,
      "/garcom/finalizacao",
      arguments: mesa,
    );
    if (resultado == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  // ============================================================
  // STATUS
  // ============================================================
  String textoStatus() {
    switch (statusPedido) {
      case "rascunho":
        return "Montando pedido";
      case "confirmado":
        return "Pedido confirmado";
      case "em_preparo":
        return "Pedido em preparo";
      case "pronto":
        return "Pedido pronto";
      case "em_entrega":
        return "Pedido em entrega";
      case "concluido":
        return "Pedido concluído";
      case "cancelado":
        return "Pedido cancelado";
      default:
        return statusPedido;
    }
  }

  Color corStatus() {
    switch (statusPedido) {
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
              onPressed: carregarPedido,
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
    final cor = corStatus();
    return Column(
      children: [
        // ========================================================
        // CABEÇALHO
        // ========================================================
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new),
                onPressed: () {
                  Navigator.pop(context, true);
                },
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
                    if (pedido?["codigo"] != null)
                      Text(
                        pedido!["codigo"].toString(),
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: processando ? null : atualizarPedido,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        // ========================================================
        // STATUS
        // ========================================================
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: cor.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Icon(Icons.restaurant, color: cor),
                const SizedBox(width: 10),
                Text(
                  textoStatus(),
                  style: TextStyle(fontWeight: FontWeight.bold, color: cor),
                ),
                if (processando) ...[
                  const Spacer(),
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: cor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        // ========================================================
        // ITENS
        // ========================================================
        Expanded(
          child: itens.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.restaurant_menu, size: 60, color: Colors.grey),
                      SizedBox(height: 12),
                      Text(
                        "Nenhum produto adicionado.",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: atualizarPedido,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: itens.length,
                    itemBuilder: (context, index) {
                      return _item(itens[index]);
                    },
                  ),
                ),
        ),
        // ========================================================
        // RODAPÉ
        // ========================================================
        Container(
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
              _linhaValor("Subtotal", subtotal),
              if (taxaServico > 0) _linhaValor("Taxa de serviço", taxaServico),
              const Divider(),
              Row(
                children: [
                  const Text(
                    "Total",
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  const Spacer(),
                  Text(
                    "R\$ ${total.toStringAsFixed(2)}",
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // ==================================================
              // AÇÕES DA COMANDA
              // ==================================================
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
                      label: const Text("Fechar Conta"),
                    ),
                  ),
                ],
              ),

              // Quando houver itens novos, o garçom envia este pedido
              // para preparo. A mesa continua ocupada.
              if (pedidoRascunho && itens.isNotEmpty) ...[
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
                    label: const Text("Enviar pedido para preparo"),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _linhaValor(String titulo, double valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
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

  Widget _item(Map<String, dynamic> item) {
    final nome = item["produto_nome"]?.toString() ?? "Produto";
    final preco = (item["preco_unitario"] as num?)?.toDouble() ?? 0.0;
    final quantidade = (item["quantidade"] as num?)?.toInt() ?? 1;
    final totalItem =
        (item["total"] as num?)?.toDouble() ?? (preco * quantidade);
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.green,
          child: Icon(Icons.fastfood, color: Colors.white),
        ),
        title: Text(nome, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          "R\$ ${preco.toStringAsFixed(2)}"
          " • Total: R\$ ${totalItem.toStringAsFixed(2)}",
        ),
        trailing: pedidoRascunho
            ? Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  color: Colors.grey.shade100,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle, color: Colors.red),
                      onPressed: processando
                          ? null
                          : () {
                              diminuirQuantidade(item);
                            },
                    ),
                    Text(
                      quantidade.toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.green),
                      onPressed: processando
                          ? null
                          : () {
                              aumentarQuantidade(item);
                            },
                    ),
                  ],
                ),
              )
            : Text(
                "${quantidade}x",
                style: const TextStyle(
                  color: Colors.green,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
