import 'dart:async';

import 'package:flutter/material.dart';

import '../Repositories/pedido_repository.dart';
import '../Repositories/relatorio_repository.dart';

class RelatorioGerenteTela extends StatefulWidget {
  const RelatorioGerenteTela({super.key});

  @override
  State<RelatorioGerenteTela> createState() => _RelatorioGerenteTelaState();
}

class _RelatorioGerenteTelaState extends State<RelatorioGerenteTela> {
  final RelatorioRepository _repository = RelatorioRepository();
  final PedidoRepository _pedidoRepository = PedidoRepository();

  final List<String> filtros = ['Hoje', 'Ontem', 'Semana', 'Mês', 'Ano'];

  int filtroSelecionado = 0;

  bool carregando = true;
  bool atualizando = false;

  String? erro;

  double faturamento = 0;
  int quantidadePedidos = 0;

  String produtoMaisPedido = 'Nenhum produto';

  List<Map<String, dynamic>> produtos = [];

  Timer? _timer;

  // ============================================================
  // INICIALIZAÇÃO
  // ============================================================

  @override
  void initState() {
    super.initState();
    _iniciarTela();
  }

  Future<void> _iniciarTela() async {
    await _carregarRelatorio();

    if (!mounted) return;

    // Atualiza automaticamente, inclusive após a meia-noite.
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      _carregarRelatorio(silencioso: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ============================================================
  // DATA E HORA DE BRASÍLIA
  // ============================================================

  // Representa a hora de Brasília independentemente do
  // fuso configurado no emulador.
  //
  // A data é utilizada somente para montar o período
  // YYYY-MM-DD enviado ao backend.
  DateTime _agoraBrasilia() {
    final utc = DateTime.now().toUtc();

    return utc.subtract(const Duration(hours: 3));
  }

  DateTime _inicioPeriodo() {
    final agora = _agoraBrasilia();

    final hoje = DateTime.utc(agora.year, agora.month, agora.day);

    switch (filtroSelecionado) {
      // HOJE
      case 0:
        return hoje;

      // ONTEM
      case 1:
        return hoje.subtract(const Duration(days: 1));

      // SEMANA
      case 2:
        return hoje.subtract(Duration(days: hoje.weekday - 1));

      // MÊS
      case 3:
        return DateTime.utc(agora.year, agora.month, 1);

      // ANO
      case 4:
        return DateTime.utc(agora.year, 1, 1);

      default:
        return hoje;
    }
  }

  DateTime _fimPeriodo() {
    final agora = _agoraBrasilia();

    final hoje = DateTime.utc(agora.year, agora.month, agora.day);

    if (filtroSelecionado == 1) {
      return hoje.subtract(const Duration(days: 1));
    }

    return hoje;
  }

  // ============================================================
  // CARREGAMENTO DOS RELATÓRIOS
  // ============================================================

  Future<void> _carregarRelatorio({bool silencioso = false}) async {
    if (atualizando) return;

    atualizando = true;

    final filtroDaConsulta = filtroSelecionado;

    if (!silencioso && mounted) {
      setState(() {
        carregando = true;
        erro = null;
      });
    }

    try {
      final inicio = _inicioPeriodo();
      final fim = _fimPeriodo();

      debugPrint('RELATÓRIO: ${filtros[filtroSelecionado]}');

      debugPrint('PERÍODO: $inicio até $fim');

      final resultados = await Future.wait<dynamic>([
        _repository.buscarResumo(de: inicio, ate: fim),
        _repository.buscarMaisVendidos(de: inicio, ate: fim),
      ]);

      final resumo = Map<String, dynamic>.from(resultados[0] as Map);

      final listaProdutos = (resultados[1] as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      if (!mounted) return;

      // Evita exibir resultados de um filtro antigo.
      if (filtroDaConsulta != filtroSelecionado) return;

      setState(() {
        faturamento = _paraDouble(resumo['faturamento']);

        quantidadePedidos = _paraInt(
          resumo['pedidos_total'] ??
              resumo['total_pedidos'] ??
              resumo['pedidos'],
        );

        produtos = listaProdutos;

        produtoMaisPedido = produtos.isNotEmpty
            ? _nomeProduto(produtos.first)
            : 'Nenhum produto';

        carregando = false;
        erro = null;
      });
    } catch (e) {
      debugPrint('Erro ao carregar relatório: $e');

      if (!mounted) return;

      if (!silencioso) {
        setState(() {
          carregando = false;

          erro = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      atualizando = false;
    }
  }

  Future<void> _selecionarFiltro(int index) async {
    if (filtroSelecionado == index) return;

    setState(() {
      filtroSelecionado = index;
    });

    await _carregarRelatorio();
  }

  // ============================================================
  // CONVERSÕES E FORMATAÇÕES
  // ============================================================

  double _paraDouble(dynamic valor) {
    if (valor == null) return 0;

    if (valor is num) {
      return valor.toDouble();
    }

    return double.tryParse(valor.toString().replaceAll(',', '.')) ?? 0;
  }

  int _paraInt(dynamic valor) {
    if (valor == null) return 0;

    if (valor is int) return valor;

    if (valor is num) return valor.toInt();

    return int.tryParse(valor.toString()) ?? 0;
  }

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

  String _nomeProduto(Map<String, dynamic> produto) {
    return produto['nome']?.toString() ??
        produto['produto_nome']?.toString() ??
        'Produto';
  }

  int _quantidadeProduto(Map<String, dynamic> produto) {
    return _paraInt(
      produto['unidades'] ??
          produto['quantidade'] ??
          produto['total_vendido'] ??
          produto['pedidos'],
    );
  }

  String _formatarData(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/'
        '${data.year}';
  }

  String _formatarHora(DateTime data) {
    return '${data.hour.toString().padLeft(2, '0')}:'
        '${data.minute.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // DATA DOS PEDIDOS
  // ============================================================

  DateTime? _dataPedido(Map<String, dynamic> pedido) {
    final status = pedido['status']?.toString().toLowerCase() ?? '';

    dynamic valor;

    if (status == 'concluido') {
      valor = pedido['concluido_em'];
    } else {
      valor =
          pedido['criado_em'] ?? pedido['created_at'] ?? pedido['data_criacao'];
    }

    if (valor == null) return null;

    final data = DateTime.tryParse(valor.toString());

    if (data == null) return null;

    // Converte o instante para Brasília.
    final brasilia = data.toUtc().subtract(const Duration(hours: 3));

    // Usa uma representação uniforme para comparar
    // as datas sem depender do fuso do emulador.
    return DateTime.utc(
      brasilia.year,
      brasilia.month,
      brasilia.day,
      brasilia.hour,
      brasilia.minute,
      brasilia.second,
      brasilia.millisecond,
    );
  }

  bool _estaNoPeriodo(DateTime data) {
    final inicio = _inicioPeriodo();
    final fim = _fimPeriodo();

    // Inclui o dia final inteiro.
    final fimExclusivo = fim.add(const Duration(days: 1));

    return !data.isBefore(inicio) && data.isBefore(fimExclusivo);
  }

  // ============================================================
  // INFORMAÇÕES DOS PEDIDOS
  // ============================================================

  String _tipoPedido(Map<String, dynamic> pedido) {
    final tipo = pedido['tipo']?.toString().toLowerCase() ?? '';

    if (tipo == 'mesa') {
      final numero =
          pedido['mesa_numero'] ?? pedido['numero_mesa'] ?? pedido['mesa'];

      if (numero != null && numero.toString().isNotEmpty) {
        return 'Mesa $numero';
      }

      return 'Mesa';
    }

    if (tipo == 'retirada') return 'Retirada';

    if (tipo == 'delivery') return 'Delivery';

    return tipo.isEmpty ? 'Pedido' : tipo;
  }

  String _numeroPedido(Map<String, dynamic> pedido) {
    final numero =
        pedido['numero'] ?? pedido['codigo'] ?? pedido['numero_pedido'];

    if (numero != null && numero.toString().isNotEmpty) {
      return '#$numero';
    }

    final id = pedido['id']?.toString() ?? '';

    if (id.length > 8) {
      return '#${id.substring(0, 8)}';
    }

    return id.isEmpty ? 'Pedido' : '#$id';
  }

  double _totalPedido(Map<String, dynamic> pedido) {
    return _paraDouble(
      pedido['total'] ??
          pedido['valor_total'] ??
          pedido['total_final'] ??
          pedido['valor'],
    );
  }

  String _formaPagamento(Map<String, dynamic> pedido) {
    final valor =
        pedido['metodo_pagamento'] ??
        pedido['forma_pagamento'] ??
        pedido['pagamento_metodo'];

    if (valor == null || valor.toString().trim().isEmpty) {
      return 'Pagamento registrado';
    }

    switch (valor.toString().toLowerCase()) {
      case 'pix':
        return 'Pix';

      case 'dinheiro':
        return 'Dinheiro';

      case 'cartao_credito':
        return 'Crédito';

      case 'cartao_debito':
        return 'Débito';

      case 'vale_refeicao':
        return 'Vale-refeição';

      case 'no_local':
        return 'No local';

      case 'na_entrega':
        return 'Na entrega';

      default:
        return valor.toString();
    }
  }

  // ============================================================
  // HISTÓRICO DE FATURAMENTO
  // ============================================================

  Future<List<Map<String, dynamic>>> _buscarHistorico() async {
    final lista = await _pedidoRepository.listarPedidos();

    final historico = <Map<String, dynamic>>[];

    for (final item in lista) {
      final pedido = Map<String, dynamic>.from(item);

      // Faturamento considera pedidos concluídos.
      final status = pedido['status']?.toString().toLowerCase() ?? '';

      if (status != 'concluido') {
        continue;
      }

      final data = _dataPedido(pedido);

      if (data == null || !_estaNoPeriodo(data)) {
        continue;
      }

      historico.add(pedido);
    }

    historico.sort((a, b) {
      final dataA = _dataPedido(a) ?? DateTime.utc(2000);

      final dataB = _dataPedido(b) ?? DateTime.utc(2000);

      return dataB.compareTo(dataA);
    });

    return historico;
  }

  Future<void> _abrirHistoricoFaturamento() async {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.88,
          minChildSize: 0.55,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _buscarHistorico(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.green),
                    );
                  }

                  if (snapshot.hasError) {
                    return _erroHistorico(
                      snapshot.error.toString().replaceFirst('Exception: ', ''),
                    );
                  }

                  final pedidos = snapshot.data ?? [];

                  return _conteudoHistorico(pedidos, scrollController);
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _erroHistorico(String mensagem) {
    return Padding(
      padding: const EdgeInsets.all(25),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 50),
          const SizedBox(height: 15),
          const Text(
            'Não foi possível carregar o histórico.',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
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

  Widget _conteudoHistorico(
    List<Map<String, dynamic>> pedidos,
    ScrollController controller,
  ) {
    final totalHistorico = pedidos.fold<double>(
      0,
      (total, pedido) => total + _totalPedido(pedido),
    );

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
      children: [
        Center(
          child: Container(
            width: 45,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),

        const SizedBox(height: 20),

        Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.receipt_long, color: Colors.green),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Histórico de faturamento',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    filtros[filtroSelecionado],
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
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

        const SizedBox(height: 18),

        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Total faturado',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                _formatarDinheiro(faturamento),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        Text(
          '${pedidos.length} pedido(s) concluído(s) encontrado(s)',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),

        if ((totalHistorico - faturamento).abs() > 0.01 &&
            pedidos.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Soma dos pedidos listados: '
            '${_formatarDinheiro(totalHistorico)}',
            style: TextStyle(
              color: Colors.orange.shade800,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],

        const SizedBox(height: 20),

        if (pedidos.isEmpty)
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 45,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Nenhum pedido concluído encontrado neste período.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ..._agruparHistoricoPorDia(pedidos),
      ],
    );
  }

  List<Widget> _agruparHistoricoPorDia(List<Map<String, dynamic>> pedidos) {
    final grupos = <String, List<Map<String, dynamic>>>{};

    for (final pedido in pedidos) {
      final data = _dataPedido(pedido);

      if (data == null) continue;

      final chave = _formatarData(data);

      grupos.putIfAbsent(chave, () => []);

      grupos[chave]!.add(pedido);
    }

    final widgets = <Widget>[];

    for (final entry in grupos.entries) {
      final totalDia = entry.value.fold<double>(
        0,
        (total, pedido) => total + _totalPedido(pedido),
      );

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  entry.key,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                _formatarDinheiro(totalDia),
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );

      for (final pedido in entry.value) {
        final data = _dataPedido(pedido);

        if (data == null) continue;

        widgets.add(
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.check_circle_outline,
                    color: Colors.green,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _numeroPedido(pedido),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${_tipoPedido(pedido)} • '
                        '${_formatarHora(data)} • '
                        '${_formaPagamento(pedido)}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                Text(
                  _formatarDinheiro(_totalPedido(pedido)),
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    return widgets;
  }

  // ============================================================
  // INTERFACE PRINCIPAL
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // CABEÇALHO
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
                      'Relatórios',
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
                      _carregarRelatorio();
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

            const SizedBox(height: 20),

            // FILTROS
            SizedBox(
              height: 45,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: filtros.length,
                itemBuilder: (context, index) {
                  final selecionado = filtroSelecionado == index;

                  return GestureDetector(
                    onTap: () {
                      _selecionarFiltro(index);
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 25,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: selecionado
                            ? Colors.green
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Text(
                        filtros[index],
                        style: TextStyle(
                          color: selecionado ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 10),

            Expanded(
              child: RefreshIndicator(
                color: Colors.green,
                onRefresh: () {
                  return _carregarRelatorio();
                },
                child: _conteudo(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CONTEÚDO DOS RELATÓRIOS
  // ============================================================

  Widget _conteudo() {
    if (carregando) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 220),
          Center(child: CircularProgressIndicator(color: Colors.green)),
        ],
      );
    }

    if (erro != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(25),
        children: [
          const SizedBox(height: 100),
          Icon(Icons.error_outline, color: Colors.red.shade400, size: 50),
          const SizedBox(height: 15),
          Text(
            erro!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
          const SizedBox(height: 15),
          Center(
            child: TextButton.icon(
              onPressed: () {
                _carregarRelatorio();
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
      padding: const EdgeInsets.all(20),
      children: [
        // FATURAMENTO E PEDIDOS
        Row(
          children: [
            _cardIndicador(
              Icons.attach_money,
              'Faturamento',
              _formatarDinheiro(faturamento),
              onTap: _abrirHistoricoFaturamento,
              mostrarSeta: true,
            ),

            const SizedBox(width: 15),

            _cardIndicador(
              Icons.receipt_long,
              'Pedidos',
              quantidadePedidos.toString(),
            ),
          ],
        ),

        const SizedBox(height: 15),

        // PRODUTO MAIS PEDIDO
        _cardProdutoMaisPedido(),

        const SizedBox(height: 30),

        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Produtos mais pedidos',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),

        const SizedBox(height: 15),

        if (produtos.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  color: Colors.grey.shade500,
                  size: 40,
                ),
                const SizedBox(height: 10),
                Text(
                  'Nenhum pedido encontrado neste período.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),

        // LISTAGEM DE PRODUTOS
        ...produtos.asMap().entries.map((entry) {
          final index = entry.key;
          final produto = entry.value;

          final quantidade = _quantidadeProduto(produto);

          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              leading: CircleAvatar(
                backgroundColor: Colors.green.shade100,
                child: Text(
                  '${index + 1}º',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                _nomeProduto(produto),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: Text(
                quantidade == 1 ? '1 unidade' : '$quantidade unidades',
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }),

        const SizedBox(height: 30),
      ],
    );
  }

  // ============================================================
  // CARD DOS INDICADORES
  // ============================================================

  Widget _cardIndicador(
    IconData icon,
    String titulo,
    String valor, {
    VoidCallback? onTap,
    bool mostrarSeta = false,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: Colors.green, size: 35),

                      const SizedBox(height: 8),

                      Text(
                        titulo,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),

                      const SizedBox(height: 3),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            valor,
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (mostrarSeta)
                  const Positioned(
                    right: 10,
                    top: 10,
                    child: Icon(Icons.chevron_right, color: Colors.green),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CARD DO PRODUTO MAIS PEDIDO
  // ============================================================

  Widget _cardProdutoMaisPedido() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Mais pedido', style: TextStyle(color: Colors.white70)),

          const SizedBox(height: 10),

          Text(
            produtoMaisPedido,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          if (produtos.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              _quantidadeProduto(produtos.first) == 1
                  ? '1 unidade pedida'
                  : '${_quantidadeProduto(produtos.first)} unidades pedidas',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ],
      ),
    );
  }
}
