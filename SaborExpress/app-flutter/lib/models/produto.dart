class Produto {
  final int id;
  final String nome;
  final String descricao;
  final double preco;
  final String imagem;
  final String categoria;
  final bool destaque;

  Produto({
    required this.id,
    required this.nome,
    required this.descricao,
    required this.preco,
    required this.imagem,
    this.categoria = 'Mais Pedidos',
    this.destaque = false,
  });

  factory Produto.fromJson(Map<String, dynamic> json) {
    return Produto(
      id: json['id'],
      nome: json['nome'],
      descricao: json['descricao'],
      preco: json['preco'].toDouble(),
      imagem: json['imagem'],
      categoria: json['categoria'] ?? 'Mais Pedidos',
      destaque: json['destaque'] ?? false,
    );
  }
}
