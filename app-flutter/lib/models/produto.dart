class Produto {
  final String id;
  final String nome;
  final String descricao;
  final double preco;
  final String imagem;
  final String categoria;
  final String? categoriaId;
  final bool destaque;
  final bool disponivel;
  final bool ativo;
  final int tempoPreparoMin;

  Produto({
    required this.id,
    required this.nome,
    required this.descricao,
    required this.preco,
    required this.imagem,
    this.categoria = 'Mais Pedidos',
    this.categoriaId,
    this.destaque = false,
    this.disponivel = true,
    this.ativo = true,
    this.tempoPreparoMin = 0,
  });

  factory Produto.fromJson(Map<String, dynamic> json) {
    return Produto(
      id: json['id']?.toString() ?? '',

      nome: json['nome']?.toString() ?? '',

      descricao: json['descricao']?.toString() ?? '',

      preco: (json['preco'] as num?)?.toDouble() ?? 0.0,

      // O backend retorna imagem_url
      imagem:
          json['imagem_url']?.toString() ??
          json['imagemUrl']?.toString() ??
          json['imagem']?.toString() ??
          '',

      // O backend retorna categoria_nome
      categoria:
          json['categoria_nome']?.toString() ??
          json['categoria']?.toString() ??
          'Mais Pedidos',

      // O backend retorna categoria_id
      categoriaId:
          json['categoria_id']?.toString() ?? json['categoriaId']?.toString(),

      destaque: json['destaque'] == true,

      disponivel: json['disponivel'] ?? true,

      ativo: json['ativo'] ?? true,

      tempoPreparoMin:
          (json['tempo_preparo_min'] as num?)?.toInt() ??
          (json['tempoPreparoMin'] as num?)?.toInt() ??
          0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nome': nome,
      'descricao': descricao,
      'preco': preco,

      if (categoriaId != null && categoriaId!.isNotEmpty)
        'categoriaId': categoriaId,

      if (imagem.isNotEmpty) 'imagemUrl': imagem,

      'tempoPreparoMin': tempoPreparoMin,
      'destaque': destaque,
      'disponivel': disponivel,
    };
  }
}
