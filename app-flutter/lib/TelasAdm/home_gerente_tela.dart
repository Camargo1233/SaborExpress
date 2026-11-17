import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Repositories/relatorio_repository.dart';

class HomeGerenteTela extends StatefulWidget {
  const HomeGerenteTela({super.key});

  @override
  State<HomeGerenteTela> createState() => _HomeGerenteTelaState();
}

class _HomeGerenteTelaState extends State<HomeGerenteTela> {
  final RelatorioRepository _relatorioRepository = RelatorioRepository();

  bool carregando = true;
  String? erro;

  // Controle do carregamento do dashboard
  bool _buscandoDashboard = false;
  bool _carregouDashboard = false;
  DateTime? _bloqueadoAte;
  Timer? _timerDashboard;

  // Indicadores do painel
  int pedidosHoje = 0;
  double faturamentoHoje = 0;
  String maisVendido = 'Sem vendas';
  int unidadesMaisVendido = 0;
  int mesasOcupadas = 0;
  int totalMesas = 0;

  @override
  void initState() {
    super.initState();
    carregarDashboard();
    _timerDashboard = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) carregarDashboard();
    });
  }

  @override
  void dispose() {
    _timerDashboard?.cancel();
    super.dispose();
  }

  bool _erroDeLimite(Object e) {
    final mensagem = e.toString().toLowerCase();

    return mensagem.contains('429') ||
        mensagem.contains('muitas requisições') ||
        mensagem.contains('too many requests');
  }

  // ============================================================
  // CARREGAR DASHBOARD
  // ============================================================

  Future<void> carregarDashboard() async {
    if (!mounted || _buscandoDashboard) return;

    final agora = DateTime.now();

    if (_bloqueadoAte != null && agora.isBefore(_bloqueadoAte!)) {
      if (!mounted) return;

      setState(() {
        erro =
            'Servidor temporariamente ocupado. '
            'Aguarde alguns instantes antes de atualizar.';
      });

      return;
    }

    _buscandoDashboard = true;

    setState(() {
      carregando = !_carregouDashboard;
      erro = null;
    });

    String? aviso;
    void registrarErro(Object e) {
      debugPrint('Falha ao atualizar painel do gerente: $e');

      if (_erroDeLimite(e)) {
        _bloqueadoAte = DateTime.now().add(const Duration(seconds: 60));

        aviso =
            'Muitas requisições. '
            'Aguarde cerca de 1 minuto '
            'antes de tentar novamente.';
      } else {
        aviso ??= e.toString().replaceFirst('Exception: ', '');
      }
    }

    try {
      // ========================================================
      // 1. RESUMO DO DASHBOARD
      // ========================================================

      try {
        final dados = Map<String, dynamic>.from(
          await _relatorioRepository.buscarDashboard(),
        );

        if (!mounted) return;

        final maisVendidoDados = dados['mais_vendido'];

        setState(() {
          pedidosHoje = _paraInt(dados['pedidos_total']);

          faturamentoHoje = _paraDouble(dados['faturamento']);

          mesasOcupadas = _paraInt(dados['mesas_ocupadas']);

          totalMesas = _paraInt(dados['total_mesas']);

          if (maisVendidoDados is Map) {
            maisVendido =
                maisVendidoDados['nome']?.toString() ??
                maisVendidoDados['produto_nome']?.toString() ??
                'Sem vendas';

            unidadesMaisVendido = _paraInt(
              maisVendidoDados['unidades'] ?? maisVendidoDados['quantidade'],
            );
          } else {
            maisVendido = 'Sem vendas';
            unidadesMaisVendido = 0;
          }
        });

        _carregouDashboard = true;
      } catch (e) {
        registrarErro(e);
      }

      if (!mounted) return;
      setState(() => erro = aviso);
    } finally {
      _buscandoDashboard = false;

      if (mounted) {
        setState(() {
          carregando = false;
        });
      }
    }
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
                    onPressed: carregando || _buscandoDashboard
                        ? null
                        : carregarDashboard,
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
                                onPressed: _buscandoDashboard
                                    ? null
                                    : carregarDashboard,
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
                            carregando && !_carregouDashboard
                                ? '...'
                                : '$pedidosHoje',
                            subtitulo: 'Hoje',
                            corPrincipal: const Color(0xFFFFA000),
                            corFundo: const Color(0xFFFFF0C7),
                          ),

                          const SizedBox(width: 15),

                          _cardInfo(
                            Icons.attach_money,
                            'Faturamento',
                            carregando && !_carregouDashboard
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
                            carregando && !_carregouDashboard
                                ? '...'
                                : maisVendido,
                            subtitulo: unidadesMaisVendido > 0
                                ? '$unidadesMaisVendido vendidos hoje'
                                : 'Nenhuma venda hoje',
                            corPrincipal: const Color(0xFF079447),
                            corFundo: const Color(0xFFDDF3E3),
                          ),

                          const SizedBox(width: 15),

                          _cardInfo(
                            Icons.table_restaurant,
                            'Mesas',
                            carregando && !_carregouDashboard
                                ? '...'
                                : '$mesasOcupadas ocupadas',
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

                      const SizedBox(height: 20),
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

              if (pedidos) ...[
                Positioned(
                  right: 14,
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
            await carregarDashboard();
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
}
