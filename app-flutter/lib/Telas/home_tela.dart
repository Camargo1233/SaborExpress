import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';

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

class _HomeTelaState extends State<HomeTela> {
  final repository = ProdutoRepository();

  final pesquisaController = TextEditingController();

  late Future<List<Produto>> produtosFuture;

  String categoriaSelecionada = 'Mais Pedidos';

  bool pesquisando = false;

  // ============================================================

  // CATEGORIAS

  // ============================================================

  final categorias = const [
    'Mais Pedidos',

    'Pizzas',

    'Lanches',

    'Bebidas',

    'Sobremesas',
  ];

  @override
  void initState() {
    super.initState();

    produtosFuture = repository.listarProdutos();
  }

  @override
  void dispose() {
    pesquisaController.dispose();

    super.dispose();
  }

  // ============================================================

  // ATUALIZAR CARDÁPIO

  // ============================================================

  Future<void> atualizar() async {
    setState(() {
      produtosFuture = repository.listarProdutos();
    });

    await produtosFuture;
  }

  // ============================================================

  // FILTRAR PRODUTOS

  // ============================================================

  List<Produto> _filtrarProdutos(List<Produto> produtos) {
    final termo = pesquisaController.text.trim().toLowerCase();

    return produtos.where((produto) {
      final categoriaProduto = produto.categoria.trim().toLowerCase();

      final categoriaAtual = categoriaSelecionada.trim().toLowerCase();

      bool combinaCategoria;

      if (categoriaSelecionada == 'Mais Pedidos') {
        combinaCategoria = produto.destaque;
      } else {
        combinaCategoria = categoriaProduto == categoriaAtual;
      }

      final combinaPesquisa =
          termo.isEmpty ||
          produto.nome.toLowerCase().contains(termo) ||
          produto.descricao.toLowerCase().contains(termo);

      return combinaCategoria && combinaPesquisa;
    }).toList();
  }

  // ============================================================

  // PESQUISA

  // ============================================================

  void _abrirPesquisa() {
    setState(() {
      pesquisando = !pesquisando;

      if (!pesquisando) {
        pesquisaController.clear();
      }
    });
  }

  // ============================================================

  // PRODUTO

  // ============================================================

  void _abrirProduto(Produto produto) {
    Navigator.push(
      context,

      MaterialPageRoute(builder: (_) => ProdutoTela(produto: produto)),
    );
  }

  // ============================================================

  // CARRINHO

  // ============================================================

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

    if (confirmar != true) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    // Remove os dados da sessão atual.

    await prefs.remove('token');

    await prefs.remove('email_login');

    await prefs.remove('usuario_id');

    await prefs.remove('usuario_nome');

    await prefs.remove('usuario_email');

    await prefs.remove('perfil');

    await prefs.remove('restaurante_slug');

    await prefs.remove('restaurante_id');

    if (!mounted) return;

    // Volta para o login e remove todas as telas anteriores.

    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  // ============================================================

  // TELA

  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),

      body: SafeArea(
        child: Column(
          children: [
            _cabecalho(),

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
              // LOGO
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

              // TÍTULO
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

              // PESQUISA
              _HeaderButton(
                tooltip: 'Pesquisar',

                icon: pesquisando ? Icons.close : Icons.search_rounded,

                onPressed: _abrirPesquisa,
              ),

              const SizedBox(width: 5),

              // CARRINHO
              _HeaderButton(
                tooltip: 'Carrinho',

                icon: Icons.shopping_bag_outlined,

                onPressed: _abrirCarrinho,
              ),

              const SizedBox(width: 5),

              // SAIR
              _HeaderButton(
                tooltip: 'Sair',

                icon: Icons.logout_rounded,

                onPressed: _sair,
              ),
            ],
          ),

          // =====================================================

          // PESQUISA

          // =====================================================
          if (pesquisando) ...[
            const SizedBox(height: 14),

            TextField(
              controller: pesquisaController,

              autofocus: true,

              onChanged: (_) {
                setState(() {});
              },

              decoration: InputDecoration(
                hintText: 'O que você está procurando?',

                hintStyle: const TextStyle(color: AppColors.mutedText),

                prefixIcon: const Icon(Icons.search, color: AppColors.green),

                suffixIcon: pesquisaController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          pesquisaController.clear();

                          setState(() {});
                        },

                        icon: const Icon(Icons.close),
                      ),

                filled: true,

                fillColor: Colors.white,

                contentPadding: const EdgeInsets.symmetric(vertical: 14),

                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),

                  borderSide: BorderSide.none,
                ),

                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),

                  borderSide: BorderSide.none,
                ),

                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),

                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
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
            'Tente outra categoria ou pesquisa.',

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
              // IMAGEM
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

              // INFORMAÇÕES
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
