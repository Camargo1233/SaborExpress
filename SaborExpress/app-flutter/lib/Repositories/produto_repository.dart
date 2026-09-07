import '../Dados/produtos_mock.dart';
import '../models/produto.dart';

class ProdutoRepository {
  Future<List<Produto>> listarProdutos() async {
    await Future.delayed(const Duration(milliseconds: 450));

    return produtosMock;
  }
}
