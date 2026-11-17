import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Repositories/pedido_repository.dart';
import '../Repositories/produto_repository.dart';
import '../models/produto.dart';
import '../utils/app_colors.dart';
import '../utils/formatters.dart';
import 'produto_tela.dart';

class HomeTela extends StatefulWidget {
  const HomeTela({super.key});

  @override
  State<HomeTela> createState() => _HomeTelaState();
}

class _HomeTelaState extends State<HomeTela> with WidgetsBindingObserver {
  final ProdutoRepository repository = ProdutoRepository();
  final PedidoRepository pedidoRepository = PedidoRepository();

  late Future<List<Produto>> produtosFuture;

  String categoriaSelecionada = 'Mais Pedidos';

  Timer? _timerPedidos;
  List<Map<String, dynamic>> _pedidosAtivos = [];
  bool _consultandoPedidos = false;
  bool _appAtivo = true;

  static const Set<String> _statusAtivos = {
    'aguardando_confirmacao',
    'confirmado',
    'em_preparo',
    'pronto',
    'em_entrega',
  };

  final List<String> categorias = const [
    'Mais Pedidos',
    'Pizzas',
    'Lanches',
    'Bebidas',
    'Sobremesas',
  ];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    produtosFuture = repository.listarProdutos();

    _consultarPedidosAtivos();

    _timerPedidos = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_appAtivo) {
        _consultarPedidosAtivos();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appAtivo = state == AppLifecycleState.resumed;

    if (_appAtivo) {
      _consultarPedidosAtivos();
    }
  }

  @override
  void dispose() {
    _timerPedidos?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ============================================================
  // CONSULTAR TODOS OS PEDIDOS EM ANDAMENTO
  // ============================================================

  Future<void> _consultarPedidosAtivos() async {
    if (!mounted || _consultandoPedidos) return;

    _consultandoPedidos = true;

    try {
      final pedidos = await pedidoRepository.listarPedidos(apenasAtivos: true);

      final ativos = pedidos
          .where((pedido) {
            final status = pedido['status']?.toString() ?? '';
            return _statusAtivos.contains(status);
          })
          .map((pedido) {
            return Map<String, dynamic>.from(pedido);
          })
          .toList();

      if (!mounted) return;

      setState(() {
        _pedidosAtivos = ativos;
      });
    } catch (erro) {
      debugPrint('Erro ao consultar pedidos ativos: $erro');
    } finally {
      _consultandoPedidos = false;
    }
  }

  // ============================================================
  // INFORMAÇÕES DOS PEDIDOS
  // ============================================================

  String _numeroPedido(Map<String, dynamic> pedido) {
    final codigo = pedido['codigo']?.toString();

    if (codigo != null && codigo.isNotEmpty) {
      return codigo;
    }

    final numeroDia = pedido['numero_dia']?.toString();

    if (numeroDia != null && numeroDia.isNotEmpty) {
      return numeroDia.padLeft(4, '0');
    }

    return '---';
  }

  String _tituloStatus(String status) {
    switch (status) {
      case 'aguardando_confirmacao':
        return 'Aguardando confirmação';

      case 'confirmado':
        return 'Pedido confirmado';

      case 'em_preparo':
        return 'Preparando seu pedido';

      case 'pronto':
        return 'Pedido pronto!';

      case 'em_entrega':
        return 'Saiu para entrega';

      case 'concluido':
        return 'Pedido concluído';

      case 'cancelado':
        return 'Pedido cancelado';

      default:
        return 'Acompanhando pedido';
    }
  }

  String _descricaoStatus(String status, String tipo) {
    switch (status) {
      case 'aguardando_confirmacao':
        return 'O restaurante recebeu seu pedido.';

      case 'confirmado':
        return 'O restaurante confirmou seu pedido.';

      case 'em_preparo':
        return 'A cozinha está preparando seus produtos.';

      case 'pronto':
        if (tipo == 'retirada') {
          return 'Seu pedido está disponível para retirada.';
        }

        if (tipo == 'mesa') {
          return 'Seu pedido está pronto para ser servido.';
        }

        return 'Seu pedido está pronto para entrega.';

      case 'em_entrega':
        return 'Seu pedido está a caminho.';

      case 'concluido':
        return 'Seu pedido foi concluído.';

      case 'cancelado':
        return 'Seu pedido foi cancelado.';

      default:
        return 'Acompanhe as atualizações do pedido.';
    }
  }

  IconData _iconeStatus(String status) {
    switch (status) {
      case 'aguardando_confirmacao':
        return Icons.schedule_rounded;

      case 'confirmado':
        return Icons.check_circle_outline_rounded;

      case 'em_preparo':
        return Icons.restaurant_rounded;

      case 'pronto':
        return Icons.task_alt_rounded;

      case 'em_entrega':
        return Icons.delivery_dining_rounded;

      case 'concluido':
        return Icons.check_circle_rounded;

      case 'cancelado':
        return Icons.cancel_outlined;

      default:
        return Icons.receipt_long_rounded;
    }
  }

  double _progressoPedido(String status) {
    switch (status) {
      case 'aguardando_confirmacao':
        return 0.15;

      case 'confirmado':
        return 0.35;

      case 'em_preparo':
        return 0.60;

      case 'pronto':
        return 0.85;

      case 'em_entrega':
        return 0.95;

      case 'concluido':
        return 1.0;

      default:
        return 0;
    }
  }

  String? _numeroMesa(Map<String, dynamic> pedido) {
    final valor = pedido['mesa_numero'];
    if (valor == null) return null;
    final numero = valor.toString().trim();
    if (numero.isEmpty) return null;
    return numero;
  }

  String _tipoPedido(String tipo) {
    switch (tipo) {
      case 'delivery':
        return 'Entrega';

      case 'retirada':
        return 'Retirada';

      case 'mesa':
        return 'Mesa';

      default:
        return 'Pedido';
    }
  }

  String _valorMonetario(dynamic valor) {
    final numero = double.tryParse(valor?.toString() ?? '');

    return Formatters.money(numero ?? 0);
  }

  // ============================================================
  // DETALHES DE UM PEDIDO
  // ============================================================

  Future<void> _abrirDetalhesPedido(Map<String, dynamic> pedido) async {
    final pedidoId = pedido['id']?.toString();

    if (pedidoId == null || pedidoId.isEmpty) {
      return;
    }

    try {
      final detalhes = await pedidoRepository.detalharPedido(pedidoId);

      if (!mounted) return;

      final status = detalhes['status']?.toString() ?? '';
      final tipo = detalhes['tipo']?.toString() ?? '';
      final numero = _numeroPedido(detalhes);
      final mesaNumero = tipo == 'mesa' ? _numeroMesa(detalhes) : null;

      final itensBrutos = detalhes['itens'];

      final List<Map<String, dynamic>> itens = [];

      if (itensBrutos is List) {
        for (final item in itensBrutos) {
          if (item is Map) {
            itens.add(Map<String, dynamic>.from(item));
          }
        }
      }

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (modalContext) {
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(modalContext).height * 0.75,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                        const Icon(
                          Icons.receipt_long_rounded,
                          color: AppColors.green,
                          size: 28,
                        ),

                        const SizedBox(width: 10),

                        Expanded(
                          child: Text(
                            'Pedido #$numero',
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              color: AppColors.darkGreen,
                            ),
                          ),
                        ),

                        IconButton(
                          onPressed: () {
                            Navigator.pop(modalContext);
                          },
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),

                    if (mesaNumero != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            Icons.table_restaurant_outlined,
                            color: AppColors.green,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Mesa $mesaNumero',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.darkGreen,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Confirme este número com o garçom.',
                        style: TextStyle(
                          color: AppColors.mutedText,
                          fontSize: 12,
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: AppColors.softGreen,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _iconeStatus(status),
                            color: AppColors.green,
                            size: 28,
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _tituloStatus(status),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.darkGreen,
                                  ),
                                ),

                                const SizedBox(height: 4),

                                Text(
                                  _descricaoStatus(status, tipo),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.mutedText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    Text(
                      'Tipo: ${_tipoPedido(tipo)}',
                      style: const TextStyle(
                        color: AppColors.mutedText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Pagamento: ${detalhes['status_pagamento'] ?? 'Não informado'}',
                      style: const TextStyle(
                        color: AppColors.mutedText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 18),

                    const Text(
                      'Itens do pedido',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkGreen,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Expanded(
                      child: ListView.separated(
                        itemCount: itens.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = itens[index];

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              item['produto_nome']?.toString() ?? 'Produto',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              'Quantidade: ${item['quantidade'] ?? 1}',
                            ),
                            trailing: Text(
                              _valorMonetario(item['total']),
                              style: const TextStyle(
                                color: AppColors.green,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const Divider(),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          _valorMonetario(detalhes['total']),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.green,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(modalContext);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(15),
                        ),
                        child: const Text('Fechar'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

      if (mounted) {
        await _consultarPedidosAtivos();
      }
    } catch (erro) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível consultar o pedido: $erro')),
      );
    }
  }

  // ============================================================
  // LISTA DE TODOS OS PEDIDOS ATIVOS
  // ============================================================

  Widget _cardPedidoAtivo() {
    if (_pedidosAtivos.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      constraints: const BoxConstraints(maxHeight: 300),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.receipt_long_rounded,
                color: AppColors.green,
                size: 21,
              ),

              const SizedBox(width: 8),

              const Expanded(
                child: Text(
                  'Meus pedidos em andamento',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkGreen,
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.softGreen,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_pedidosAtivos.length}',
                  style: const TextStyle(
                    color: AppColors.green,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _pedidosAtivos.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final pedido = _pedidosAtivos[index];

                final status = pedido['status']?.toString() ?? '';

                final tipo = pedido['tipo']?.toString() ?? '';

                final numero = _numeroPedido(pedido);
                final mesaNumero = tipo == 'mesa' ? _numeroMesa(pedido) : null;

                return Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _abrirDetalhesPedido(pedido),
                    child: Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppColors.green.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _iconeStatus(status),
                                color: AppColors.green,
                                size: 24,
                              ),

                              const SizedBox(width: 10),

                              Expanded(
                                child: Text(
                                  'Pedido #$numero',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.darkGreen,
                                  ),
                                ),
                              ),

                              Text(
                                _tipoPedido(tipo),
                                style: const TextStyle(
                                  color: AppColors.mutedText,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),

                          if (mesaNumero != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.table_restaurant_outlined,
                                  color: AppColors.green,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Mesa $mesaNumero',
                                  style: const TextStyle(
                                    color: AppColors.darkGreen,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 12),

                          Text(
                            _tituloStatus(status),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.darkGreen,
                            ),
                          ),

                          const SizedBox(height: 5),

                          Text(
                            _descricaoStatus(status, tipo),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.mutedText,
                            ),
                          ),

                          const SizedBox(height: 12),

                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: _progressoPedido(status),
                              minHeight: 6,
                              backgroundColor: AppColors.softGreen,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.green,
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          const Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                'Ver detalhes',
                                style: TextStyle(
                                  color: AppColors.green,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: AppColors.green,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // A PARTE 2 CONTINUA AQUI, DENTRO DE _HomeTelaState.

  // ============================================================
  // ATUALIZAR CARDÁPIO E PEDIDOS
  // ============================================================

  Future<void> atualizar() async {
    setState(() {
      produtosFuture = repository.listarProdutos();
    });

    try {
      await produtosFuture;
    } finally {
      await _consultarPedidosAtivos();
    }
  }

  // ============================================================
  // FILTRAR PRODUTOS
  // ============================================================

  List<Produto> _filtrarProdutos(List<Produto> produtos) {
    return produtos.where((produto) {
      final categoriaProduto = produto.categoria.trim().toLowerCase();

      final categoriaAtual = categoriaSelecionada.trim().toLowerCase();

      final bool combinaCategoria;

      if (categoriaSelecionada == 'Mais Pedidos') {
        combinaCategoria = produto.destaque;
      } else {
        combinaCategoria = categoriaProduto == categoriaAtual;
      }

      return combinaCategoria;
    }).toList();
  }

  // ============================================================
  // PRODUTO E CARRINHO
  // ============================================================

  void _abrirProduto(Produto produto) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProdutoTela(produto: produto)),
    );
  }

  void _abrirCarrinho() {
    Navigator.pushNamed(context, '/cliente/carrinho');
  }

  // ============================================================
  // SAIR DA CONTA
  // ============================================================

  Future<void> _sair() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: const Row(
            children: [
              Icon(Icons.logout_rounded, color: AppColors.green),
              SizedBox(width: 10),
              Text('Sair', style: TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          content: const Text('Deseja realmente sair da sua conta?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Sair'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) return;

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
  // TELA PRINCIPAL
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      body: SafeArea(
        child: Column(
          children: [
            _cabecalho(),

            _cardPedidoAtivo(),

            const SizedBox(height: 14),

            _categorias(),

            const SizedBox(height: 8),

            Expanded(
              child: FutureBuilder<List<Produto>>(
                future: produtosFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.green),
                    );
                  }

                  if (snapshot.hasError) {
                    return _erroAoCarregar();
                  }

                  final produtos = _filtrarProdutos(snapshot.data ?? []);

                  if (produtos.isEmpty) {
                    return _nenhumProduto();
                  }

                  return RefreshIndicator(
                    onRefresh: atualizar,
                    color: AppColors.green,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  categoriaSelecionada,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.darkGreen,
                                  ),
                                ),
                              ),
                              Text(
                                '${produtos.length} '
                                '${produtos.length == 1 ? 'produto' : 'produtos'}',
                                style: const TextStyle(
                                  color: AppColors.mutedText,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...produtos.map(
                          (produto) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _ProdutoCard(
                              produto: produto,
                              onTap: () => _abrirProduto(produto),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CABEÇALHO
  // ============================================================

  Widget _cabecalho() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: const BoxDecoration(
        color: AppColors.green,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.restaurant_menu,
                  color: Colors.white,
                  size: 25,
                ),
              ),

              const SizedBox(width: 12),

              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sabor Express',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Escolha o que deseja pedir',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 6),

              _HeaderButton(
                tooltip: 'Carrinho',
                icon: Icons.shopping_bag_outlined,
                onPressed: _abrirCarrinho,
              ),

              const SizedBox(width: 5),

              _HeaderButton(
                tooltip: 'Sair',
                icon: Icons.logout_rounded,
                onPressed: _sair,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CATEGORIAS
  // ============================================================

  Widget _categorias() {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: categorias.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final categoria = categorias[index];

          final selecionada = categoriaSelecionada == categoria;

          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              setState(() {
                categoriaSelecionada = categoria;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selecionada ? AppColors.green : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selecionada ? AppColors.green : Colors.grey.shade300,
                ),
              ),
              child: Text(
                categoria,
                style: TextStyle(
                  color: selecionada ? Colors.white : AppColors.darkGreen,
                  fontWeight: selecionada ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // ERRO AO CARREGAR
  // ============================================================

  Widget _erroAoCarregar() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 60,
              color: AppColors.mutedText,
            ),

            const SizedBox(height: 16),

            const Text(
              'Não foi possível carregar o cardápio',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.darkGreen,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Verifique sua conexão e tente novamente.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.mutedText),
            ),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: atualizar,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // NENHUM PRODUTO
  // ============================================================

  Widget _nenhumProduto() {
    return RefreshIndicator(
      onRefresh: atualizar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),

          Icon(Icons.restaurant_outlined, size: 65, color: AppColors.mutedText),

          SizedBox(height: 14),

          Text(
            'Nenhum produto encontrado',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.darkGreen,
            ),
          ),

          SizedBox(height: 6),

          Text(
            'Tente selecionar outra categoria.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.mutedText),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// BOTÃO DO CABEÇALHO
// ================================================================

class _HeaderButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  const _HeaderButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(13),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        constraints: const BoxConstraints(minWidth: 42, minHeight: 42),
        padding: const EdgeInsets.all(9),
        icon: Icon(icon, color: Colors.white, size: 21),
      ),
    );
  }
}

// ================================================================
// CARD DO PRODUTO
// ================================================================

class _ProdutoCard extends StatelessWidget {
  final Produto produto;
  final VoidCallback onTap;

  const _ProdutoCard({required this.produto, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Image.network(
                  produto.imagem,
                  width: 88,
                  height: 88,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) {
                    return Container(
                      width: 88,
                      height: 88,
                      color: AppColors.softGreen,
                      child: const Icon(
                        Icons.fastfood,
                        color: AppColors.green,
                        size: 36,
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            produto.nome,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.darkGreen,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),

                        if (produto.destaque)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.softGreen,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.star_rounded,
                              color: AppColors.green,
                              size: 16,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 5),

                    Text(
                      produto.descricao,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            Formatters.money(produto.preco),
                            style: const TextStyle(
                              color: AppColors.green,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),

                        Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: AppColors.softGreen,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.add,
                            color: AppColors.green,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
