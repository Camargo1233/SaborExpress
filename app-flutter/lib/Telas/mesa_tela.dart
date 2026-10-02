import 'package:flutter/material.dart';

import '../Repositories/mesa_repository.dart';
import '../utils/app_colors.dart';

class MesaTela extends StatefulWidget {
  const MesaTela({super.key});

  @override
  State<MesaTela> createState() => _MesaTelaState();
}

class _MesaTelaState extends State<MesaTela> {
  final MesaRepository repository = MesaRepository();

  List<Map<String, dynamic>> mesasDisponiveis = [];

  Map<String, dynamic>? mesaSelecionada;

  bool carregando = true;
  bool reservando = false;

  String? erro;

  @override
  void initState() {
    super.initState();
    _carregarMesas();
  }

  // ============================================================
  // CARREGAR MESAS DISPONÍVEIS
  // ============================================================

  Future<void> _carregarMesas() async {
    if (mounted) {
      setState(() {
        carregando = true;
        erro = null;
      });
    }

    try {
      final lista = await repository.listarMesasDisponiveis();

      if (!mounted) return;

      lista.sort((a, b) {
        final numeroA = int.tryParse(a['numero']?.toString() ?? '') ?? 0;

        final numeroB = int.tryParse(b['numero']?.toString() ?? '') ?? 0;

        return numeroA.compareTo(numeroB);
      });

      setState(() {
        mesasDisponiveis = lista;

        // Caso uma mesa selecionada tenha sido reservada
        // por outra pessoa durante a atualização.
        if (mesaSelecionada != null) {
          final idSelecionado = mesaSelecionada!['id']?.toString();

          final aindaDisponivel = mesasDisponiveis.any(
            (mesa) => mesa['id']?.toString() == idSelecionado,
          );

          if (!aindaDisponivel) {
            mesaSelecionada = null;
          }
        }

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
  // SELECIONAR MESA
  // ============================================================

  void _selecionarMesa(Map<String, dynamic> mesa) {
    if (reservando) return;

    setState(() {
      mesaSelecionada = mesa;
    });
  }

  // ============================================================
  // RESERVAR MESA
  // ============================================================

  Future<void> _confirmarMesa() async {
    if (mesaSelecionada == null || reservando) {
      return;
    }

    final mesa = Map<String, dynamic>.from(mesaSelecionada!);

    final mesaId = mesa['id']?.toString();

    if (mesaId == null || mesaId.isEmpty) {
      _mostrarMensagem('Não foi possível identificar a mesa.', erro: true);
      return;
    }

    setState(() {
      reservando = true;
    });

    try {
      // ========================================================
      // RESERVAR MESA NO BACKEND
      // ========================================================

      final sessao = await repository.reservarMesa(mesaId: mesaId);

      if (!mounted) return;

      // ========================================================
      // IDENTIFICAR SESSÃO CRIADA
      // ========================================================

      final sessaoId =
          sessao['id']?.toString() ?? sessao['sessao_id']?.toString();

      if (sessaoId == null || sessaoId.isEmpty) {
        setState(() {
          reservando = false;
        });

        _mostrarMensagem(
          'A mesa foi reservada, mas não foi possível '
          'identificar a sessão.',
          erro: true,
        );

        return;
      }

      // ========================================================
      // RESULTADO PARA A TELA ANTERIOR
      // ========================================================

      final resultado = <String, dynamic>{
        ...mesa,
        'mesa_id': mesaId,
        'sessao_id': sessaoId,
        'status': 'ocupada',
      };

      // ========================================================
      // VOLTAR PARA A SACOLA
      // ========================================================

      Navigator.of(context).pop(resultado);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        reservando = false;
      });

      _mostrarMensagem(_limparErro(e), erro: true);

      // Atualiza a lista caso outra pessoa tenha
      // reservado a mesma mesa.
      await _carregarMesas();
    }
  }

  // ============================================================
  // LIMPAR ERRO
  // ============================================================

  String _limparErro(Object erro) {
    return erro.toString().replaceFirst('Exception: ', '');
  }

  // ============================================================
  // MENSAGEM
  // ============================================================

  void _mostrarMensagem(String mensagem, {bool erro = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: erro ? Colors.red : AppColors.green,
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
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,

        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: reservando
              ? null
              : () {
                  Navigator.pop(context);
                },
        ),

        title: const Text(
          'Reservar mesa',
          style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w800),
        ),

        actions: [
          IconButton(
            tooltip: 'Atualizar mesas',
            onPressed: carregando || reservando ? null : _carregarMesas,
            icon: const Icon(Icons.refresh, color: AppColors.green),
          ),
        ],
      ),

      body: Column(
        children: [
          Expanded(child: _construirConteudo()),
          _construirRodape(),
        ],
      ),
    );
  }

  // ============================================================
  // CONTEÚDO
  // ============================================================

  Widget _construirConteudo() {
    if (carregando) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.green),
      );
    }

    if (erro != null) {
      return _construirErro();
    }

    if (mesasDisponiveis.isEmpty) {
      return _construirSemMesas();
    }

    return RefreshIndicator(
      onRefresh: _carregarMesas,

      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),

        padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),

        children: [
          // ====================================================
          // INFORMAÇÃO
          // ====================================================
          Container(
            width: double.infinity,

            padding: const EdgeInsets.all(18),

            decoration: BoxDecoration(
              color: AppColors.softGreen,
              borderRadius: BorderRadius.circular(18),
            ),

            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,

                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),

                  child: const Icon(
                    Icons.table_restaurant,
                    color: AppColors.green,
                    size: 27,
                  ),
                ),

                const SizedBox(width: 14),

                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Escolha sua mesa',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      SizedBox(height: 5),

                      Text(
                        'Selecione uma mesa disponível '
                        'para fazer sua reserva.',
                        style: TextStyle(color: AppColors.mutedText),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 25),

          // ====================================================
          // TÍTULO
          // ====================================================
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Mesas disponíveis',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),

                decoration: BoxDecoration(
                  color: AppColors.softGreen,
                  borderRadius: BorderRadius.circular(20),
                ),

                child: Text(
                  '${mesasDisponiveis.length}',
                  style: const TextStyle(
                    color: AppColors.green,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          // ====================================================
          // MESAS
          // ====================================================
          ...mesasDisponiveis.map((mesa) => _cardMesa(mesa)),
        ],
      ),
    );
  }

  // ============================================================
  // CARD DA MESA
  // ============================================================

  Widget _cardMesa(Map<String, dynamic> mesa) {
    final id = mesa['id']?.toString() ?? '';

    final numero = mesa['numero']?.toString() ?? '-';

    final apelido = mesa['apelido']?.toString();

    final capacidade = (mesa['capacidade'] as num?)?.toInt() ?? 0;

    final selecionada = mesaSelecionada?['id']?.toString() == id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),

      child: InkWell(
        borderRadius: BorderRadius.circular(18),

        onTap: reservando
            ? null
            : () {
                _selecionarMesa(mesa);
              },

        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),

          padding: const EdgeInsets.all(16),

          decoration: BoxDecoration(
            color: selecionada ? AppColors.softGreen : Colors.white,

            borderRadius: BorderRadius.circular(18),

            border: Border.all(
              color: selecionada ? AppColors.green : Colors.grey.shade300,

              width: selecionada ? 2 : 1,
            ),

            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),

          child: Row(
            children: [
              // ================================================
              // ÍCONE
              // ================================================
              Container(
                width: 58,
                height: 58,

                decoration: BoxDecoration(
                  color: selecionada ? AppColors.green : AppColors.softGreen,

                  borderRadius: BorderRadius.circular(16),
                ),

                child: Icon(
                  Icons.table_restaurant,
                  color: selecionada ? Colors.white : AppColors.green,
                  size: 28,
                ),
              ),

              const SizedBox(width: 15),

              // ================================================
              // DADOS
              // ================================================
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      'Mesa $numero',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    if (apelido != null && apelido.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),

                      Text(
                        apelido,
                        style: const TextStyle(
                          color: AppColors.mutedText,
                          fontSize: 13,
                        ),
                      ),
                    ],

                    const SizedBox(height: 7),

                    Row(
                      children: [
                        const Icon(
                          Icons.people_outline,
                          size: 17,
                          color: AppColors.mutedText,
                        ),

                        const SizedBox(width: 5),

                        Text(
                          capacidade > 0
                              ? 'Até $capacidade '
                                    '${capacidade == 1 ? 'pessoa' : 'pessoas'}'
                              : 'Capacidade não informada',
                          style: const TextStyle(
                            color: AppColors.mutedText,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    const Row(
                      children: [
                        Icon(Icons.circle, size: 10, color: AppColors.green),

                        SizedBox(width: 6),

                        Text(
                          'Disponível',
                          style: TextStyle(
                            color: AppColors.green,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ================================================
              // SELEÇÃO
              // ================================================
              Icon(
                selecionada
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,

                color: selecionada ? AppColors.green : AppColors.mutedText,

                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // RODAPÉ
  // ============================================================

  Widget _construirRodape() {
    if (carregando || erro != null || mesasDisponiveis.isEmpty) {
      return const SizedBox.shrink();
    }

    final numero = mesaSelecionada?['numero']?.toString();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),

      decoration: BoxDecoration(
        color: Colors.white,

        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),

      child: Column(
        mainAxisSize: MainAxisSize.min,

        children: [
          if (mesaSelecionada != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 11),

              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: AppColors.green,
                    size: 19,
                  ),

                  const SizedBox(width: 7),

                  Expanded(
                    child: Text(
                      'Mesa $numero selecionada',
                      style: const TextStyle(
                        color: AppColors.green,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          SizedBox(
            width: double.infinity,
            height: 52,

            child: ElevatedButton.icon(
              onPressed: mesaSelecionada == null || reservando
                  ? null
                  : _confirmarMesa,

              icon: reservando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check),

              label: Text(
                reservando ? 'Reservando...' : 'Reservar mesa',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SEM MESAS
  // ============================================================

  Widget _construirSemMesas() {
    return RefreshIndicator(
      onRefresh: _carregarMesas,

      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),

        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.60,

            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 30),

              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,

                children: [
                  Icon(
                    Icons.table_restaurant_outlined,
                    size: 65,
                    color: AppColors.mutedText,
                  ),

                  SizedBox(height: 18),

                  Text(
                    'Nenhuma mesa disponível',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),

                  SizedBox(height: 8),

                  Text(
                    'No momento todas as mesas '
                    'estão ocupadas. Atualize '
                    'novamente em alguns instantes.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.mutedText),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERRO
  // ============================================================

  Widget _construirErro() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            Icon(Icons.wifi_off_rounded, size: 58, color: Colors.grey.shade500),

            const SizedBox(height: 18),

            const Text(
              'Não foi possível carregar as mesas',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),

            const SizedBox(height: 8),

            Text(
              erro ?? 'Ocorreu um erro ao carregar as mesas.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.mutedText),
            ),

            const SizedBox(height: 22),

            ElevatedButton.icon(
              onPressed: _carregarMesas,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
