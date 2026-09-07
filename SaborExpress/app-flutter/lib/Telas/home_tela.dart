import 'package:flutter/material.dart';

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

  final categorias = const [
    'Mais Pedidos',
    'Pizzas',
    'Lanches',
    'Macarrão',
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

  Future<void> atualizar() async {
    setState(() {
      produtosFuture = repository.listarProdutos();
    });
  }

  List<Produto> _filtrarProdutos(List<Produto> produtos) {
    final termo = pesquisaController.text.trim().toLowerCase();

    return produtos.where((produto) {
      final combinaCategoria = categoriaSelecionada == 'Mais Pedidos'
          ? produto.destaque
          : produto.categoria == categoriaSelecionada;
      final combinaPesquisa =
          termo.isEmpty ||
          produto.nome.toLowerCase().contains(termo) ||
          produto.descricao.toLowerCase().contains(termo);

      return combinaCategoria && combinaPesquisa;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: const BoxDecoration(
                color: AppColors.green,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Menu',
                        icon: const Icon(Icons.menu, color: Colors.white),
                        onPressed: () => _mostrarPerfisTeste(context),
                      ),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sabor Express',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Cardápio mockado para testes',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Pesquisar',
                        icon: Icon(
                          pesquisando ? Icons.close : Icons.search,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          setState(() {
                            pesquisando = !pesquisando;
                            if (!pesquisando) pesquisaController.clear();
                          });
                        },
                      ),
                      IconButton(
                        tooltip: 'Carrinho',
                        icon: const Icon(
                          Icons.shopping_cart_outlined,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          Navigator.pushNamed(context, '/cliente/carrinho');
                        },
                      ),
                    ],
                  ),
                  if (pesquisando) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: pesquisaController,
                      autofocus: true,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Buscar por produto',
                        prefixIcon: Icon(Icons.search),
                        fillColor: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(
              height: 52,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  final categoria = categorias[index];
                  final selecionada = categoriaSelecionada == categoria;

                  return ChoiceChip(
                    label: Text(categoria),
                    selected: selecionada,
                    onSelected: (_) {
                      setState(() {
                        categoriaSelecionada = categoria;
                      });
                    },
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemCount: categorias.length,
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Produto>>(
                future: produtosFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: ElevatedButton.icon(
                        onPressed: atualizar,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tentar novamente'),
                      ),
                    );
                  }

                  final produtos = _filtrarProdutos(snapshot.data ?? []);

                  if (produtos.isEmpty) {
                    return const Center(
                      child: Text('Nenhum produto encontrado.'),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: atualizar,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                      itemBuilder: (context, index) {
                        final produto = produtos[index];
                        return _ProdutoCard(
                          produto: produto,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProdutoTela(produto: produto),
                              ),
                            );
                          },
                        );
                      },
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemCount: produtos.length,
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

  void _mostrarPerfisTeste(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Atalhos de teste',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.table_restaurant),
              title: const Text('Área do garçom'),
              onTap: () => Navigator.pushNamed(context, '/garcom/mesa'),
            ),
            ListTile(
              leading: const Icon(Icons.admin_panel_settings),
              title: const Text('Área do gerente'),
              onTap: () => Navigator.pushNamed(context, '/adm/home'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProdutoCard extends StatelessWidget {
  final Produto produto;
  final VoidCallback onTap;

  const _ProdutoCard({required this.produto, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
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
                      child: const Icon(Icons.fastfood, color: AppColors.green),
                    );
                  },
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      produto.nome,
                      style: const TextStyle(
                        color: AppColors.darkGreen,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      produto.descricao,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.mutedText),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      Formatters.money(produto.preco),
                      style: const TextStyle(
                        color: AppColors.green,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.mutedText),
            ],
          ),
        ),
      ),
    );
  }
}
