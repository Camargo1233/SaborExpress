import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../Repositories/relatorio_repository.dart';

import '../Repositories/pedido_repository.dart';

import '../Repositories/mesa_repository.dart';

class HomeGerenteTela extends StatefulWidget {
  const HomeGerenteTela({super.key});

  @override
  State<HomeGerenteTela> createState() => _HomeGerenteTelaState();
}

class _HomeGerenteTelaState extends State<HomeGerenteTela> {
  final RelatorioRepository _relatorioRepository = RelatorioRepository();

  final PedidoRepository _pedidoRepository = PedidoRepository();

  final MesaRepository _mesaRepository = MesaRepository();

  bool carregando = true;

  String? erro;

  int pedidosHoje = 0;

  double faturamentoHoje = 0;

  String maisVendido = 'Sem vendas';

  int unidadesMaisVendido = 0;

  int mesasOcupadas = 0;

  int totalMesas = 0;

  // ============================================================

  // ATIVIDADES RECENTES

  // ============================================================

  List<Map<String, dynamic>> atividadesRecentes = [];

  @override
  void initState() {
    super.initState();

    carregarDashboard();
  }

  // ============================================================

  // CARREGAR DASHBOARD

  // ============================================================

  Future<void> carregarDashboard() async {
    if (!mounted) return;

    setState(() {
      carregando = true;

      erro = null;
    });

    try {
      // Carrega dashboard, atividades das mesas e pedidos

      // de retirada/delivery ao mesmo tempo.

      final resultados = await Future.wait<dynamic>([
        _relatorioRepository.buscarDashboard(),

        _relatorioRepository.buscarAtividadesRecentes(),

        _pedidoRepository.listarPedidos(),

        _mesaRepository.listarMesas(),
      ]);

      final dados = Map<String, dynamic>.from(resultados[0] as Map);

      final atividadesMesas = (resultados[1] as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      final pedidos = (resultados[2] as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      final mesas = (resultados[3] as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      final atividades = _montarAtividadesRecentes(
        atividadesMesas,

        pedidos,

        mesas,
      );

      final maisVendidoDados = dados['mais_vendido'];

      if (!mounted) return;

      setState(() {
        pedidosHoje = _paraInt(dados['pedidos_total']);

        faturamentoHoje = _paraDouble(dados['faturamento']);

        mesasOcupadas = _paraInt(dados['mesas_ocupadas']);

        totalMesas = _paraInt(dados['total_mesas']);

        if (maisVendidoDados is Map) {
          maisVendido =
              maisVendidoDados['produto_nome']?.toString() ?? 'Sem vendas';

          unidadesMaisVendido = _paraInt(maisVendidoDados['unidades']);
        } else {
          maisVendido = 'Sem vendas';

          unidadesMaisVendido = 0;
        }

        atividadesRecentes = atividades;

        carregando = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar dashboard: $e');

      if (!mounted) return;

      setState(() {
        erro = e.toString().replaceFirst('Exception: ', '');

        carregando = false;
      });
    }
  }

  // ============================================================

  // ATIVIDADES RECENTES - MESAS + RETIRADA + DELIVERY

  // ============================================================

  List<Map<String, dynamic>> _montarAtividadesRecentes(
    List<Map<String, dynamic>> atividadesMesas,

    List<Map<String, dynamic>> pedidos,

    List<Map<String, dynamic>> mesas,
  ) {
    final atividades = <Map<String, dynamic>>[];

    final sessoesMesaJaListadas = <String>{};

    // Atividades registradas pelo backend para abertura/fechamento de mesa.

    for (final atividade in atividadesMesas) {
      final item = Map<String, dynamic>.from(atividade);

      item['_origem'] = 'mesa';

      item['_data_atividade'] = _dataAtividade(item);

      final sessaoId =
          (item['sessao_id'] ?? item['sessao_mesa_id'] ?? item['id'])
              ?.toString();

      if (sessaoId != null && sessaoId.isNotEmpty) {
        sessoesMesaJaListadas.add(sessaoId);
      }

      atividades.add(item);
    }

    // Mostra TODOS os tipos de pedido: mesa, retirada e delivery.

    // A forma de pagamento não interfere: pago no app ou no local

    // continua aparecendo nas atividades recentes.

    for (final pedido in pedidos) {
      final tipo = pedido['tipo']?.toString().toLowerCase() ?? '';

      if (tipo != 'mesa' && tipo != 'retirada' && tipo != 'delivery') {
        continue;
      }

      final item = Map<String, dynamic>.from(pedido);

      item['_origem'] = tipo;

      item['_atividade_pedido'] = true;

      item['_data_atividade'] = _dataAtividade(item);

      atividades.add(item);
    }

    // Garante que uma mesa atualmente ocupada/reservada apareça mesmo

    // quando o endpoint de atividades não devolver o evento de abertura.

    for (final mesa in mesas) {
      final status = mesa['status']?.toString().toLowerCase() ?? '';

      final sessaoId = (mesa['sessao_id'] ?? mesa['sessao_mesa_id'])
          ?.toString();

      final ocupada =
          status == 'ocupada' ||
          status == 'reservada' ||
          (sessaoId != null && sessaoId.isNotEmpty);

      if (!ocupada) continue;

      if (sessaoId != null &&
          sessaoId.isNotEmpty &&
          sessoesMesaJaListadas.contains(sessaoId)) {
        continue;
      }

      final item = <String, dynamic>{
        ...mesa,

        '_origem': 'mesa',

        '_mesa_atual': true,

        'tipo': 'aberta',

        'mesa_numero': mesa['numero'] ?? mesa['mesa_numero'],

        'sessao_id': sessaoId,
      };

      item['_data_atividade'] = _dataAtividade(item);

      atividades.add(item);
    }

    atividades.sort((a, b) {
      final dataA = a['_data_atividade'] as DateTime?;

      final dataB = b['_data_atividade'] as DateTime?;

      // Itens atuais sem timestamp (ex.: mesa ocupada) continuam visíveis.

      if (dataA == null && dataB == null) return 0;

      if (dataA == null) return 1;

      if (dataB == null) return -1;

      return dataB.compareTo(dataA);
    });

    return atividades.take(30).toList();
  }

  DateTime? _dataAtividade(Map<String, dynamic> item) {
    final valor =
        item['atualizado_em'] ??
        item['updated_at'] ??
        item['criado_em'] ??
        item['created_at'] ??
        item['confirmado_em'] ??
        item['fechado_em'] ??
        item['aberta_em'] ??
        item['aberto_em'] ??
        item['iniciada_em'] ??
        item['data_hora'] ??
        item['data'];

    if (valor == null) return null;

    return DateTime.tryParse(valor.toString())?.toLocal();
  }

  String _statusPedido(Map<String, dynamic> pedido) {
    return (pedido['status'] ?? '').toString().toLowerCase();
  }

  String _textoStatus(String status) {
    switch (status) {
      case 'rascunho':
        return 'Aguardando confirmação';

      case 'confirmado':
        return 'Pedido confirmado';

      case 'em_preparo':
        return 'Em preparo';

      case 'pronto':
        return 'Pronto';

      case 'em_entrega':
        return 'Saiu para entrega';

      case 'concluido':
        return 'Concluído';

      case 'cancelado':
        return 'Cancelado';

      default:
        return status.isEmpty ? 'Pedido atualizado' : status;
    }
  }

  String _numeroPedido(Map<String, dynamic> pedido) {
    final codigo = pedido['codigo']?.toString().trim() ?? '';

    if (codigo.isNotEmpty) return codigo;

    final numero = pedido['numero_pedido'] ?? pedido['numero'];

    if (numero != null && numero.toString().trim().isNotEmpty) {
      return numero.toString();
    }

    final id = pedido['id']?.toString() ?? '';

    return id.length > 8 ? id.substring(0, 8) : id;
  }

  String _formatarHorarioAtividade(DateTime? data) {
    if (data == null) return '';

    final agora = DateTime.now();

    final hoje = DateTime(agora.year, agora.month, agora.day);

    final dia = DateTime(data.year, data.month, data.day);

    final hora =
        '${data.hour.toString().padLeft(2, '0')}:'
        '${data.minute.toString().padLeft(2, '0')}';

    if (dia == hoje) {
      return 'Hoje às $hora';
    }

    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')} às $hora';
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

  // FORMATAÇÃO DE DINHEIRO

  // ============================================================

  String _formatarDinheiro(double valor) {
    final partes = valor.toStringAsFixed(2).split('.');

    final inteiro = partes[0];

    final decimal = partes[1];

    final buffer = StringBuffer();

    for (int i = 0; i < inteiro.length; i++) {
      final posicaoRestante = inteiro.length - i;

      buffer.write(inteiro[i]);

      if (posicaoRestante > 1 && posicaoRestante % 3 == 1) {
        buffer.write('.');
      }
    }

    return 'R\$ ${buffer.toString()},$decimal';
  }

  // ============================================================

  // SAIR

  // ============================================================

  Future<void> _sair() async {
    final confirmar = await showDialog<bool>(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Sair'),

          content: const Text('Deseja realmente sair da conta?'),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },

              child: const Text('Cancelar'),
            ),

            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),

              onPressed: () {
                Navigator.pop(dialogContext, true);
              },

              child: const Text('Sair', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirmar != true) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('token');

    await prefs.remove('email_login');

    await prefs.remove('usuario_id');

    await prefs.remove('usuario_nome');

    await prefs.remove('usuario_email');

    await prefs.remove('perfil');

    await prefs.remove('restaurante_slug');

    await prefs.remove('restaurante_id');

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
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
                  const CircleAvatar(
                    radius: 28,

                    backgroundColor: Colors.white,

                    child: Icon(
                      Icons.admin_panel_settings,

                      color: Colors.green,

                      size: 35,
                    ),
                  ),

                  const SizedBox(width: 15),

                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        Text(
                          'Olá, Gerente',

                          style: TextStyle(
                            color: Colors.white,

                            fontSize: 22,

                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        Text(
                          'Painel Administrativo',

                          style: TextStyle(color: Colors.white70, fontSize: 15),
                        ),
                      ],
                    ),
                  ),

                  IconButton(
                    onPressed: carregarDashboard,

                    tooltip: 'Atualizar',

                    icon: const Icon(
                      Icons.refresh,

                      color: Colors.white,

                      size: 28,
                    ),
                  ),

                  IconButton(
                    onPressed: _sair,

                    tooltip: 'Sair',

                    icon: const Icon(
                      Icons.logout,

                      color: Colors.white,

                      size: 30,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ==================================================

            // CONTEÚDO

            // ==================================================
            Expanded(
              child: RefreshIndicator(
                onRefresh: carregarDashboard,

                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),

                  padding: const EdgeInsets.all(20),

                  child: Column(
                    children: [
                      // ========================================

                      // CARREGANDO

                      // ========================================
                      if (carregando)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 20),

                          child: LinearProgressIndicator(color: Colors.green),
                        ),

                      // ========================================

                      // ERRO

                      // ========================================
                      if (erro != null)
                        Container(
                          width: double.infinity,

                          margin: const EdgeInsets.only(bottom: 20),

                          padding: const EdgeInsets.all(15),

                          decoration: BoxDecoration(
                            color: Colors.red.shade50,

                            borderRadius: BorderRadius.circular(15),

                            border: Border.all(color: Colors.red.shade200),
                          ),

                          child: Column(
                            children: [
                              const Icon(
                                Icons.error_outline,

                                color: Colors.red,
                              ),

                              const SizedBox(height: 8),

                              Text(
                                erro!,

                                textAlign: TextAlign.center,

                                style: const TextStyle(color: Colors.red),
                              ),

                              const SizedBox(height: 10),

                              TextButton.icon(
                                onPressed: carregarDashboard,

                                icon: const Icon(Icons.refresh),

                                label: const Text('Tentar novamente'),
                              ),
                            ],
                          ),
                        ),

                      // ========================================

                      // INDICADORES

                      // ========================================
                      Row(
                        children: [
                          _cardInfo(
                            Icons.receipt_long,

                            'Pedidos',

                            carregando ? '...' : '$pedidosHoje',

                            subtitulo: 'Hoje',

                            corPrincipal: const Color(0xFFFFA000),

                            corFundo: const Color(0xFFFFF0C7),
                          ),

                          const SizedBox(width: 15),

                          _cardInfo(
                            Icons.attach_money,

                            'Faturamento',

                            carregando
                                ? '...'
                                : _formatarDinheiro(faturamentoHoje),

                            subtitulo: 'Hoje',

                            corPrincipal: const Color(0xFFE92D35),

                            corFundo: const Color(0xFFFFDDE0),
                          ),
                        ],
                      ),

                      const SizedBox(height: 15),

                      Row(
                        children: [
                          _cardInfo(
                            Icons.local_pizza,

                            'Mais vendido',

                            carregando ? '...' : maisVendido,

                            subtitulo: unidadesMaisVendido > 0
                                ? '$unidadesMaisVendido vendidos na semana'
                                : 'Últimos 7 dias',

                            corPrincipal: const Color(0xFF079447),

                            corFundo: const Color(0xFFDDF3E3),
                          ),

                          const SizedBox(width: 15),

                          _cardInfo(
                            Icons.table_restaurant,

                            'Mesas',

                            carregando ? '...' : '$mesasOcupadas ocupadas',

                            subtitulo: totalMesas > 0
                                ? '$mesasOcupadas de $totalMesas'
                                : 'Nenhuma mesa',

                            corPrincipal: const Color(0xFF6947D4),

                            corFundo: const Color(0xFFE9E2FA),
                          ),
                        ],
                      ),

                      const SizedBox(height: 30),

                      // ========================================

                      // MENU

                      // ========================================
                      _botaoMenu(
                        context,

                        'Gerenciar Pedidos',

                        Icons.receipt,

                        '/adm/pedidos',

                        const Color(0xFF63B977),

                        const Color(0xFFE7F5EA),
                      ),

                      const SizedBox(height: 15),

                      _botaoMenu(
                        context,

                        'Gerenciar Cardápio',

                        Icons.restaurant_menu,

                        '/adm/cardapio',

                        const Color(0xFFE87979),

                        const Color(0xFFFFEAEA),
                      ),

                      const SizedBox(height: 15),

                      _botaoMenu(
                        context,

                        'Relatórios',

                        Icons.bar_chart,

                        '/adm/relatorios',

                        const Color(0xFFE8A936),

                        const Color(0xFFFFF3D8),
                      ),

                      const SizedBox(height: 35),

                      // ========================================

                      // ATIVIDADES RECENTES

                      // ========================================
                      const Align(
                        alignment: Alignment.centerLeft,

                        child: Text(
                          'Atividades recentes',

                          style: TextStyle(
                            fontSize: 22,

                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      const SizedBox(height: 15),

                      if (!carregando && atividadesRecentes.isEmpty)
                        _nenhumaAtividade(),

                      if (!carregando)
                        ...atividadesRecentes.map(
                          (atividade) => _cardAtividade(atividade),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================

  // CARD DE INFORMAÇÃO

  // ============================================================

  Widget _cardInfo(
    IconData icon,

    String titulo,

    String valor, {

    String? subtitulo,

    required Color corPrincipal,

    required Color corFundo,
  }) {
    final pedidos = titulo == 'Pedidos';

    final faturamento = titulo == 'Faturamento';

    final vendido = titulo == 'Mais vendido';

    final mesas = titulo == 'Mesas';

    return Expanded(
      child: Container(
        height: 176,

        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),

          boxShadow: [
            BoxShadow(
              color: corPrincipal.withValues(alpha: 0.10),

              blurRadius: 18,

              offset: const Offset(0, 8),
            ),
          ],
        ),

        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),

          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,

                      end: Alignment.bottomRight,

                      colors: [Colors.white, corFundo.withValues(alpha: 0.94)],
                    ),
                  ),
                ),
              ),

              // Formas decorativas do fundo.

              // No card de Pedidos, as curvas ficam no canto SUPERIOR DIREITO,

              // seguindo a mesma composição visual do card Faturamento.
              if (pedidos) ...[
                Positioned(
                  top: -38,

                  right: -30,

                  child: Transform.rotate(
                    angle: 0.35,

                    child: Container(
                      width: 132,

                      height: 78,

                      decoration: BoxDecoration(
                        color: corPrincipal.withValues(alpha: 0.18),

                        borderRadius: BorderRadius.circular(60),
                      ),
                    ),
                  ),
                ),

                Positioned(
                  top: -52,

                  right: 18,

                  child: Transform.rotate(
                    angle: 0.35,

                    child: Container(
                      width: 105,

                      height: 66,

                      decoration: BoxDecoration(
                        color: corPrincipal.withValues(alpha: 0.09),

                        borderRadius: BorderRadius.circular(60),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                Positioned(
                  top: -38,

                  right: -30,

                  child: Transform.rotate(
                    angle: 0.35,

                    child: Container(
                      width: 132,

                      height: 78,

                      decoration: BoxDecoration(
                        color: corPrincipal.withValues(alpha: 0.18),

                        borderRadius: BorderRadius.circular(60),
                      ),
                    ),
                  ),
                ),

                Positioned(
                  top: -52,

                  right: 18,

                  child: Transform.rotate(
                    angle: 0.35,

                    child: Container(
                      width: 105,

                      height: 66,

                      decoration: BoxDecoration(
                        color: corPrincipal.withValues(alpha: 0.09),

                        borderRadius: BorderRadius.circular(60),
                      ),
                    ),
                  ),
                ),
              ],

              if (pedidos) ...[
                Positioned(
                  right: 14, // ← ALTERADO: era left: 14

                  bottom: 13,

                  child: Icon(
                    Icons.restaurant_menu,

                    size: 27,

                    color: corPrincipal.withValues(alpha: 0.24),
                  ),
                ),

                Positioned(
                  right: 13,

                  top: 14,

                  child: Icon(
                    Icons.eco_outlined,

                    size: 22,

                    color: corPrincipal.withValues(alpha: 0.22),
                  ),
                ),
              ],

              if (faturamento) ...[
                Positioned(
                  right: 16,

                  bottom: 18,

                  child: Icon(
                    Icons.currency_exchange,

                    size: 28,

                    color: corPrincipal.withValues(alpha: 0.18),
                  ),
                ),

                Positioned(
                  left: 17,

                  bottom: 14,

                  child: Text(
                    '•••',

                    style: TextStyle(
                      letterSpacing: 3,

                      color: corPrincipal.withValues(alpha: 0.25),

                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],

              if (vendido)
                Positioned(
                  right: 15,

                  bottom: 14,

                  child: Icon(
                    Icons.eco,

                    size: 29,

                    color: corPrincipal.withValues(alpha: 0.20),
                  ),
                ),

              if (mesas)
                Positioned(
                  right: 12,

                  bottom: 10,

                  child: Icon(
                    Icons.chair_alt_outlined,

                    size: 34,

                    color: corPrincipal.withValues(alpha: 0.20),
                  ),
                ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 15, 13, 13),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Container(
                      width: 51,

                      height: 51,

                      decoration: BoxDecoration(
                        color: corPrincipal,

                        borderRadius: BorderRadius.circular(15),

                        boxShadow: [
                          BoxShadow(
                            color: corPrincipal.withValues(alpha: 0.24),

                            blurRadius: 9,

                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),

                      child: Icon(icon, color: Colors.white, size: 29),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      titulo,

                      maxLines: 1,

                      overflow: TextOverflow.ellipsis,

                      style: const TextStyle(
                        color: Color(0xFF262626),

                        fontSize: 15,

                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      valor,

                      maxLines: vendido ? 2 : 1,

                      overflow: TextOverflow.ellipsis,

                      style: TextStyle(
                        color: corPrincipal,

                        fontSize: vendido ? 14 : 18,

                        fontWeight: FontWeight.w900,

                        height: 1.05,
                      ),
                    ),

                    if (subtitulo != null) ...[
                      const SizedBox(height: 4),

                      Text(
                        subtitulo,

                        maxLines: 1,

                        overflow: TextOverflow.ellipsis,

                        style: const TextStyle(
                          color: Color(0xFF6E6E6E),

                          fontSize: 10.5,

                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================

  // BOTÃO DO MENU

  // ============================================================

  Widget _botaoMenu(
    BuildContext context,

    String texto,

    IconData icon,

    String rota,

    Color cor,

    Color corFundo,
  ) {
    return SizedBox(
      width: double.infinity,

      height: 62,

      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: corFundo,

          foregroundColor: cor,

          elevation: 0,

          shadowColor: Colors.transparent,

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),

            side: BorderSide(color: cor.withValues(alpha: 0.18)),
          ),

          padding: const EdgeInsets.symmetric(horizontal: 22),
        ),

        onPressed: () async {
          await Navigator.pushNamed(context, rota);

          if (mounted) {
            carregarDashboard();
          }
        },

        child: Row(
          children: [
            Container(
              width: 40,

              height: 40,

              decoration: BoxDecoration(
                color: cor.withValues(alpha: 0.13),

                borderRadius: BorderRadius.circular(12),
              ),

              child: Icon(icon, color: cor, size: 22),
            ),

            const SizedBox(width: 15),

            Expanded(
              child: Text(
                texto,

                style: TextStyle(
                  color: cor,

                  fontSize: 17,

                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            Icon(Icons.chevron_right_rounded, color: cor, size: 27),
          ],
        ),
      ),
    );
  }

  // ============================================================

  // CARD DE ATIVIDADE

  // ============================================================

  Widget _cardAtividade(Map<String, dynamic> atividade) {
    final origem = atividade['_origem']?.toString().toLowerCase() ?? 'mesa';

    final data =
        atividade['_data_atividade'] as DateTime? ?? _dataAtividade(atividade);

    final atividadePedido = atividade['_atividade_pedido'] == true;

    if (atividadePedido || origem == 'retirada' || origem == 'delivery') {
      final status = _statusPedido(atividade);

      final numero = _numeroPedido(atividade);

      final valor = _paraDouble(
        atividade['total'] ??
            atividade['valor_total'] ??
            atividade['total_final'] ??
            atividade['valor'],
      );

      final bool retirada = origem == 'retirada';

      final bool delivery = origem == 'delivery';

      final bool mesaPedido = origem == 'mesa';

      Color cor;

      IconData icone;

      if (status == 'cancelado') {
        cor = Colors.red;

        icone = Icons.cancel_outlined;
      } else if (status == 'concluido') {
        cor = Colors.green;

        icone = Icons.check_circle;
      } else if (status == 'pronto') {
        cor = Colors.blue;

        icone = Icons.done_all;
      } else if (status == 'em_entrega') {
        cor = Colors.blue;

        icone = Icons.delivery_dining;
      } else if (status == 'em_preparo') {
        cor = Colors.orange;

        icone = Icons.restaurant;
      } else {
        cor = Colors.orange;

        icone = retirada
            ? Icons.shopping_bag_outlined
            : delivery
            ? Icons.delivery_dining
            : Icons.table_restaurant;
      }

      String tituloTipo;

      if (retirada) {
        tituloTipo = 'Retirada';
      } else if (delivery) {
        tituloTipo = 'Delivery';
      } else if (mesaPedido) {
        final numeroMesa =
            atividade['mesa_numero'] ??
            atividade['numero_mesa'] ??
            atividade['mesa'];

        tituloTipo = numeroMesa != null ? 'Mesa $numeroMesa' : 'Pedido da mesa';
      } else {
        tituloTipo = 'Pedido';
      }

      final titulo = numero.isEmpty
          ? '$tituloTipo - ${_textoStatus(status)}'
          : '$tituloTipo - Pedido $numero - ${_textoStatus(status)}';

      final partes = <String>[
        if (valor > 0) _formatarDinheiro(valor),

        if (_formatarHorarioAtividade(data).isNotEmpty)
          _formatarHorarioAtividade(data),
      ];

      return _atividadeContainer(
        cor: cor,

        icone: icone,

        titulo: titulo,

        descricao: partes.isEmpty ? 'Pedido atualizado' : partes.join(' • '),
      );
    }

    final tipo = atividade['tipo']?.toString() ?? '';

    final numeroMesa = atividade['mesa_numero']?.toString() ?? '';

    final valor = _paraDouble(atividade['valor']);

    final bool fechada = tipo == 'fechada';

    final Color cor = fechada ? Colors.green : Colors.orange;

    final IconData icone = fechada
        ? Icons.check_circle
        : Icons.table_restaurant;

    final String titulo = fechada
        ? 'Mesa $numeroMesa - Pedido fechado'
        : 'Mesa $numeroMesa foi reservada';

    final horario = _formatarHorarioAtividade(data);

    final String descricao = fechada
        ? [
            _formatarDinheiro(valor),

            if (horario.isNotEmpty) horario,
          ].join(' • ')
        : ['Conta em andamento', if (horario.isNotEmpty) horario].join(' • ');

    return _atividadeContainer(
      cor: cor,

      icone: icone,

      titulo: titulo,

      descricao: descricao,
    );
  }

  Widget _atividadeContainer({
    required Color cor,

    required IconData icone,

    required String titulo,

    required String descricao,
  }) {
    return Container(
      width: double.infinity,

      margin: const EdgeInsets.only(bottom: 12),

      padding: const EdgeInsets.all(15),

      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.08),

        borderRadius: BorderRadius.circular(15),

        border: Border.all(color: cor.withValues(alpha: 0.25)),
      ),

      child: Row(
        children: [
          Container(
            width: 46,

            height: 46,

            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.12),

              shape: BoxShape.circle,
            ),

            child: Icon(icone, color: cor),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  titulo,

                  style: const TextStyle(
                    fontWeight: FontWeight.bold,

                    fontSize: 15,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  descricao,

                  style: TextStyle(color: cor, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

          Icon(Icons.chevron_right, color: Colors.grey.shade400),
        ],
      ),
    );
  }

  // ============================================================

  // NENHUMA ATIVIDADE

  // ============================================================

  Widget _nenhumaAtividade() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),

      decoration: BoxDecoration(
        color: Colors.grey.shade100,

        borderRadius: BorderRadius.circular(15),
      ),

      child: Column(
        children: [
          Icon(Icons.notifications_none, size: 40, color: Colors.grey.shade500),

          const SizedBox(height: 10),

          Text(
            'Nenhuma atividade recente',

            style: TextStyle(
              color: Colors.grey.shade700,

              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            'As movimentações de mesas, retiradas e deliveries aparecerão aqui.',

            textAlign: TextAlign.center,

            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
