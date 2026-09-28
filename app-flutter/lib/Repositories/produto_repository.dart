import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/produto.dart';

class ProdutoRepository {
  static const String baseUrl =
      'http://localhost:3000/api/restaurantes/sabor-express/produtos';

  // ============================================================
  // TOKEN
  // ============================================================

  Future<String?> _buscarToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // ============================================================
  // TRATAR ERROS DO BACKEND
  // ============================================================

  String _mensagemErro(http.Response response) {
    try {
      final dados = jsonDecode(response.body);

      if (dados is Map<String, dynamic>) {
        if (dados['erro'] != null) {
          return dados['erro'].toString();
        }

        if (dados['message'] != null) {
          return dados['message'].toString();
        }
      }
    } catch (_) {
      // Caso o backend não retorne JSON.
    }

    return 'Erro ${response.statusCode}';
  }

  // ============================================================
  // LISTAR PRODUTOS
  // ============================================================

  Future<List<Produto>> listarProdutos() async {
    try {
      final response = await http.get(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final dynamic dados = jsonDecode(response.body);

        if (dados is List) {
          return dados
              .map((json) => Produto.fromJson(Map<String, dynamic>.from(json)))
              .toList();
        }

        if (dados is Map<String, dynamic> && dados['produtos'] is List) {
          return (dados['produtos'] as List)
              .map((json) => Produto.fromJson(Map<String, dynamic>.from(json)))
              .toList();
        }

        throw Exception('Formato de resposta inválido.');
      }

      throw Exception(_mensagemErro(response));
    } catch (erro) {
      throw Exception('Não foi possível buscar os produtos: $erro');
    }
  }

  // ============================================================
  // CRIAR PRODUTO
  // ============================================================

  Future<Produto> criarProduto({
    required String nome,
    required String descricao,
    required double preco,
    String? categoriaId,
    String? imagemUrl,
    int tempoPreparoMin = 0,
    bool destaque = false,
    bool disponivel = true,
  }) async {
    final token = await _buscarToken();

    if (token == null || token.isEmpty) {
      throw Exception('Sessão não encontrada. Faça login novamente.');
    }

    final body = <String, dynamic>{
      'nome': nome.trim(),
      'descricao': descricao.trim(),
      'preco': preco,
      'tempoPreparoMin': tempoPreparoMin,
      'destaque': destaque,
      'disponivel': disponivel,
    };

    if (categoriaId != null && categoriaId.isNotEmpty) {
      body['categoriaId'] = categoriaId;
    }

    if (imagemUrl != null && imagemUrl.trim().isNotEmpty) {
      body['imagemUrl'] = imagemUrl.trim();
    }

    final response = await http.post(
      Uri.parse(baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final dados = jsonDecode(response.body);

      return Produto.fromJson(Map<String, dynamic>.from(dados));
    }

    throw Exception(
      'Não foi possível criar o produto: ${_mensagemErro(response)}',
    );
  }

  // ============================================================
  // EDITAR PRODUTO
  // ============================================================

  Future<Produto> atualizarProduto({
    required String produtoId,
    required String nome,
    required String descricao,
    required double preco,
    String? categoriaId,
    String? imagemUrl,
    int? tempoPreparoMin,
    bool? destaque,
    bool? disponivel,
  }) async {
    final token = await _buscarToken();

    if (token == null || token.isEmpty) {
      throw Exception('Sessão não encontrada. Faça login novamente.');
    }

    final body = <String, dynamic>{
      'nome': nome.trim(),
      'descricao': descricao.trim(),
      'preco': preco,
    };

    if (categoriaId != null && categoriaId.isNotEmpty) {
      body['categoriaId'] = categoriaId;
    }

    if (imagemUrl != null && imagemUrl.trim().isNotEmpty) {
      body['imagemUrl'] = imagemUrl.trim();
    }

    if (tempoPreparoMin != null) {
      body['tempoPreparoMin'] = tempoPreparoMin;
    }

    if (destaque != null) {
      body['destaque'] = destaque;
    }

    if (disponivel != null) {
      body['disponivel'] = disponivel;
    }

    final response = await http.patch(
      Uri.parse('$baseUrl/$produtoId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final dados = jsonDecode(response.body);

      return Produto.fromJson(Map<String, dynamic>.from(dados));
    }

    throw Exception(
      'Não foi possível atualizar o produto: ${_mensagemErro(response)}',
    );
  }

  // ============================================================
  // EXCLUIR PRODUTO
  // ============================================================

  Future<void> excluirProduto(String produtoId) async {
    final token = await _buscarToken();

    if (token == null || token.isEmpty) {
      throw Exception('Sessão não encontrada. Faça login novamente.');
    }

    final response = await http.delete(
      Uri.parse('$baseUrl/$produtoId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }

    throw Exception(
      'Não foi possível excluir o produto: ${_mensagemErro(response)}',
    );
  }
}
