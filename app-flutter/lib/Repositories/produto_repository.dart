import 'dart:convert';
import 'dart:typed_data';

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
      // Backend não retornou JSON.
    }

    return 'Erro ${response.statusCode}';
  }

  String _mensagemErroTexto({required int statusCode, required String body}) {
    try {
      final dados = jsonDecode(body);

      if (dados is Map<String, dynamic>) {
        if (dados['erro'] != null) {
          return dados['erro'].toString();
        }

        if (dados['message'] != null) {
          return dados['message'].toString();
        }
      }
    } catch (_) {
      // Backend não retornou JSON.
    }

    return 'Erro $statusCode';
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
  // UPLOAD DE IMAGEM
  // ============================================================
  //
  // Funciona com Flutter Web porque não utiliza dart:io nem File.
  //
  // Recebe os bytes vindos do ImagePicker e envia:
  //
  // multipart/form-data
  // campo: imagem
  //
  // para:
  //
  // POST /produtos/upload-imagem
  //
  // O backend responde:
  //
  // {
  //   "imagemUrl": "http://localhost:3000/uploads/produtos/..."
  // }
  // ============================================================

  Future<String> uploadImagem({
    required Uint8List imagemBytes,
    required String nomeArquivo,
  }) async {
    final token = await _buscarToken();

    if (token == null || token.isEmpty) {
      throw Exception('Sessão não encontrada. Faça login novamente.');
    }

    if (imagemBytes.isEmpty) {
      throw Exception('A imagem selecionada está vazia.');
    }

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload-imagem'),
      );

      request.headers['Authorization'] = 'Bearer $token';

      request.files.add(
        http.MultipartFile.fromBytes(
          'imagem',
          imagemBytes,
          filename: nomeArquivo.isNotEmpty ? nomeArquivo : 'produto.jpg',
        ),
      );

      final streamedResponse = await request.send();

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final dynamic dados = jsonDecode(response.body);

        if (dados is Map<String, dynamic>) {
          final imagemUrl = dados['imagemUrl']?.toString();

          if (imagemUrl != null && imagemUrl.trim().isNotEmpty) {
            return imagemUrl.trim();
          }
        }

        throw Exception('O backend não retornou a URL da imagem.');
      }

      throw Exception(
        _mensagemErroTexto(
          statusCode: response.statusCode,
          body: response.body,
        ),
      );
    } catch (erro) {
      throw Exception('Não foi possível enviar a imagem: $erro');
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
      'Não foi possível criar o produto: '
      '${_mensagemErro(response)}',
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
      'Não foi possível atualizar o produto: '
      '${_mensagemErro(response)}',
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
      'Não foi possível excluir o produto: '
      '${_mensagemErro(response)}',
    );
  }
}
