import '../models/produto.dart';

class CarrinhoItem {
  final Produto produto;
  int quantidade;
  String observacao;

  CarrinhoItem({
    required this.produto,
    required this.quantidade,
    this.observacao = '',
  });

  double get total => produto.preco * quantidade;
}

class CarrinhoRepository {
  CarrinhoRepository._();

  static final CarrinhoRepository instance = CarrinhoRepository._();

  final List<CarrinhoItem> _itens = [];

  List<CarrinhoItem> get itens => List.unmodifiable(_itens);

  bool get vazio => _itens.isEmpty;

  int get quantidadeTotal {
    return _itens.fold(0, (total, item) => total + item.quantidade);
  }

  double get subtotal {
    return _itens.fold(0, (total, item) => total + item.total);
  }

  void adicionarProduto({
    required Produto produto,
    int quantidade = 1,
    String observacao = '',
  }) {
    final index = _itens.indexWhere(
      (item) =>
          item.produto.id == produto.id &&
          item.observacao.trim() == observacao.trim(),
    );

    if (index >= 0) {
      _itens[index].quantidade += quantidade;
      return;
    }

    _itens.add(
      CarrinhoItem(
        produto: produto,
        quantidade: quantidade,
        observacao: observacao.trim(),
      ),
    );
  }

  void aumentarQuantidade(int index) {
    if (index < 0 || index >= _itens.length) return;

    _itens[index].quantidade++;
  }

  void diminuirQuantidade(int index) {
    if (index < 0 || index >= _itens.length) return;

    if (_itens[index].quantidade <= 1) {
      _itens.removeAt(index);
      return;
    }

    _itens[index].quantidade--;
  }

  void removerItem(int index) {
    if (index < 0 || index >= _itens.length) return;

    _itens.removeAt(index);
  }

  void limpar() {
    _itens.clear();
  }
}
