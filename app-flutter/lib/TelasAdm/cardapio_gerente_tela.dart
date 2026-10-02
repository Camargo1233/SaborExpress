import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../Repositories/produto_repository.dart';
import '../models/produto.dart';
import 'produto_gerente_tela.dart';
import 'adicionar_gerente_tela.dart';

class CardapioGerenteTela extends StatefulWidget {
  const CardapioGerenteTela({super.key});

  @override
  State<CardapioGerenteTela> createState() => _CardapioGerenteTelaState();
}

class _CardapioGerenteTelaState extends State<CardapioGerenteTela> {
  final ProdutoRepository repository = ProdutoRepository();

  int categoriaSelecionada = 0;
  bool carregando = true;
  String? erro;
  List<Produto> produtos = [];

  final categorias = ['Pizzas', 'Lanches', 'Massas', 'Bebidas', 'Sobremesas'];

  @override
  void initState() {
    super.initState();
    carregarProdutos();
  }

  Future<void> carregarProdutos() async {
    if (mounted) {
      setState(() {
        carregando = true;
        erro = null;
      });
    }

    try {
      final lista = await repository.listarProdutos();
      if (!mounted) return;

      setState(() {
        produtos = lista;
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

  Future<String?> _enviarImagemSeNecessario(Map<String, dynamic> dados) async {
    final bytes = dados['imagemBytes'];

    if (bytes is Uint8List && bytes.isNotEmpty) {
      final nomeArquivo =
          dados['imagemNome']?.toString().trim() ?? 'produto.jpg';

      return repository.uploadImagem(
        imagemBytes: bytes,
        nomeArquivo: nomeArquivo.isEmpty ? 'produto.jpg' : nomeArquivo,
      );
    }

    return _buscarImagem(dados);
  }

  Future<void> abrirAdicionar() async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdicionarGerenteTela()),
    );

    if (resultado == null) return;

    try {
      final dados = Map<String, dynamic>.from(resultado);

      final nome = dados['nome']?.toString().trim() ?? '';
      final descricao = dados['descricao']?.toString().trim() ?? '';
      final preco = dados['preco'] is num
          ? (dados['preco'] as num).toDouble()
          : double.tryParse(
                  dados['preco']?.toString().replaceAll(',', '.') ?? '',
                ) ??
                0.0;

      final categoriaId = dados['categoriaId']?.toString();

      if (nome.isEmpty || preco <= 0) {
        _mostrarMensagem('Informe um nome e um preço válido.', erro: true);
        return;
      }

      if (categoriaId == null || categoriaId.isEmpty) {
        _mostrarMensagem('Selecione uma categoria.', erro: true);
        return;
      }

      final imagemUrl = await _enviarImagemSeNecessario(dados);

      await repository.criarProduto(
        nome: nome,
        descricao: descricao,
        preco: preco,
        categoriaId: categoriaId,
        imagemUrl: imagemUrl,
        tempoPreparoMin: 0,
        destaque: false,
        disponivel: true,
      );

      if (!mounted) return;

      _mostrarMensagem('Produto adicionado com sucesso!');
      await carregarProdutos();
    } catch (e) {
      if (!mounted) return;
      _mostrarMensagem(_limparErro(e), erro: true);
    }
  }

  Future<void> abrirEditar(Produto produto) async {
    final produtoMap = <String, dynamic>{
      'id': produto.id,
      'nome': produto.nome,
      'descricao': produto.descricao,
      'preco': produto.preco,
      'categoria': produto.categoria,
      'categoriaId': produto.categoriaId,
      'imagem': produto.imagem,
      'destaque': produto.destaque,
      'disponivel': produto.disponivel,
      'tempoPreparoMin': produto.tempoPreparoMin,
    };

    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProdutoGerenteTela(produto: produtoMap),
      ),
    );

    if (resultado == null) return;

    try {
      final dados = Map<String, dynamic>.from(resultado);

      final nome = dados['nome']?.toString().trim() ?? '';
      final descricao = dados['descricao']?.toString().trim() ?? '';
      final preco = dados['preco'] is num
          ? (dados['preco'] as num).toDouble()
          : double.tryParse(
                  dados['preco']?.toString().replaceAll(',', '.') ?? '',
                ) ??
                0.0;

      if (nome.isEmpty || preco <= 0) {
        _mostrarMensagem('Informe um nome e um preço válido.', erro: true);
        return;
      }

      final categoriaId =
          dados['categoriaId']?.toString() ?? produto.categoriaId;

      final novaImagemUrl = await _enviarImagemSeNecessario(dados);

      final imagemUrl =
          novaImagemUrl ??
          (produto.imagem.trim().isNotEmpty ? produto.imagem.trim() : null);

      await repository.atualizarProduto(
        produtoId: produto.id,
        nome: nome,
        descricao: descricao,
        preco: preco,
        categoriaId: categoriaId,
        imagemUrl: imagemUrl,
        tempoPreparoMin: dados['tempoPreparoMin'] is num
            ? (dados['tempoPreparoMin'] as num).toInt()
            : produto.tempoPreparoMin,
        destaque: dados['destaque'] is bool
            ? dados['destaque'] as bool
            : produto.destaque,
        disponivel: dados['disponivel'] is bool
            ? dados['disponivel'] as bool
            : produto.disponivel,
      );

      if (!mounted) return;

      _mostrarMensagem('Produto atualizado com sucesso!');
      await carregarProdutos();
    } catch (e) {
      if (!mounted) return;
      _mostrarMensagem(_limparErro(e), erro: true);
    }
  }

  Future<void> removerProduto(Produto produto) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remover produto'),
          content: Text('Deseja realmente remover "${produto.nome}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remover', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirmar != true) return;

    try {
      await repository.excluirProduto(produto.id);

      if (!mounted) return;

      _mostrarMensagem('Produto removido com sucesso!');
      await carregarProdutos();
    } catch (e) {
      if (!mounted) return;
      _mostrarMensagem(_limparErro(e), erro: true);
    }
  }

  String? _buscarImagem(Map<String, dynamic> dados) {
    final imagem = dados['imagemUrl'] ?? dados['imagem_url'] ?? dados['imagem'];

    if (imagem == null) return null;

    final valor = imagem.toString().trim();

    if (valor.isEmpty) return null;

    if (!valor.startsWith('http://') && !valor.startsWith('https://')) {
      return null;
    }

    return valor;
  }

  String _limparErro(Object erro) {
    return erro.toString().replaceFirst('Exception: ', '');
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

  Widget _imagemProduto(Produto produto) {
    final imagem = produto.imagem.trim();

    if (imagem.isEmpty ||
        (!imagem.startsWith('http://') && !imagem.startsWith('https://'))) {
      return Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: Colors.green.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.fastfood, color: Colors.green, size: 32),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        imagem,
        width: 70,
        height: 70,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 70,
            height: 70,
            color: Colors.green.shade100,
            child: const Icon(Icons.broken_image_outlined, color: Colors.green),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriaAtual = categorias[categoriaSelecionada];

    final produtosCategoria = produtos.where((produto) {
      return produto.categoria.trim().toLowerCase() ==
          categoriaAtual.trim().toLowerCase();
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      drawer: Drawer(
        child: Column(
          children: [
            const UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: Colors.green),
              accountName: Text('Gerente'),
              accountEmail: Text('gerente@saborexpress.com'),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, color: Colors.green),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add_circle, color: Colors.green),
              title: const Text('Adicionar produto'),
              onTap: () {
                Navigator.pop(context);
                abrirAdicionar();
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long, color: Colors.green),
              title: const Text('Pedidos'),
              onTap: () {
                Navigator.pushNamed(context, '/adm/pedidos');
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        backgroundColor: Colors.green,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Cardápio',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Atualizar',
            onPressed: carregarProdutos,
          ),
          IconButton(
            icon: const Icon(Icons.add_circle, color: Colors.white),
            tooltip: 'Adicionar produto',
            onPressed: abrirAdicionar,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.green,
        onPressed: abrirAdicionar,
        icon: const Icon(Icons.add),
        label: const Text('Adicionar Produto'),
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          SizedBox(
            height: 45,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: categorias.length,
              itemBuilder: (context, index) {
                final selecionado = categoriaSelecionada == index;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      categoriaSelecionada = index;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: selecionado ? Colors.green : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Center(
                      child: Text(
                        categorias[index],
                        style: TextStyle(
                          color: selecionado ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(),
          Expanded(child: _construirConteudo(produtosCategoria)),
        ],
      ),
    );
  }

  Widget _construirConteudo(List<Produto> produtosCategoria) {
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
              const SizedBox(height: 12),
              Text(erro!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: carregarProdutos,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    if (produtosCategoria.isEmpty) {
      return Center(
        child: Text(
          'Nenhum produto em ${categorias[categoriaSelecionada]}',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: carregarProdutos,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: produtosCategoria.length,
        itemBuilder: (context, index) {
          final produto = produtosCategoria[index];

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: _imagemProduto(produto),
              title: Text(
                produto.nome,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.green,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(produto.descricao),
                    const SizedBox(height: 6),
                    Text(
                      'R\$ ${produto.preco.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (valor) {
                  if (valor == 'editar') {
                    abrirEditar(produto);
                  }

                  if (valor == 'remover') {
                    removerProduto(produto);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'editar',
                    child: Row(
                      children: [
                        Icon(Icons.edit, color: Colors.green),
                        SizedBox(width: 10),
                        Text('Editar'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'remover',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 10),
                        Text('Remover'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
