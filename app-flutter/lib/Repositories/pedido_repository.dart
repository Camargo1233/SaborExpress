import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class PedidoRepository {
  static const String baseUrl =
      'http://localhost:3000/api/restaurantes/sabor-express';

  Future<String> _buscarToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null || token.isEmpty) {
      throw Exception('Sessão não encontrada. Faça login novamente.');
    }

    return token;
  }

  Map<String, String> _headers(String token) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

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

        if (dados['mensagem'] != null) {
          return dados['mensagem'].toString();
        }
      }
    } catch (_) {}

    return 'Erro ${response.statusCode}';
  }

  // ============================================================
  // CRIAR PEDIDO DA MESA
  // ============================================================

  Future<Map<String, dynamic>> criarPedidoMesa({
    required String sessaoMesaId,
    String? observacao,
  }) async {
    final token = await _buscarToken();

    final body = <String, dynamic>{
      'tipo': 'mesa',
      'sessaoMesaId': sessaoMesaId,
    };

    if (observacao != null && observacao.trim().isNotEmpty) {
      body['observacao'] = observacao.trim();
    }

    final response = await http.post(
      Uri.parse('$baseUrl/pedidos'),
      headers: _headers(token),
      body: jsonEncode(body),
    );

    if (response.statusCode != 201) {
      throw Exception(
        'Não foi possível criar o pedido: ${_mensagemErro(response)}',
      );
    }

    return Map<String, dynamic>.from(jsonDecode(response.body));
  }

  // ============================================================
  // LISTAR PEDIDOS
  // ============================================================

  Future<List<Map<String, dynamic>>> listarPedidos({
    String? status,
    String? tipo,
    bool? apenasAtivos,
  }) async {
    final token = await _buscarToken();

    final parametros = <String, String>{};

    if (status != null) {
      parametros['status'] = status;
    }

    if (tipo != null) {
      parametros['tipo'] = tipo;
    }

    if (apenasAtivos != null) {
      parametros['apenasAtivos'] = apenasAtivos.toString();
    }

    final uri = Uri.parse(
      '$baseUrl/pedidos',
    ).replace(queryParameters: parametros);

    final response = await http.get(uri, headers: _headers(token));

    if (response.statusCode != 200) {
      throw Exception(
        'Não foi possível carregar os pedidos: '
        '${_mensagemErro(response)}',
      );
    }

    final dynamic dados = jsonDecode(response.body);

    if (dados is Map<String, dynamic> && dados['value'] is List) {
      final lista = dados['value'] as List;

      return lista.map((pedido) => Map<String, dynamic>.from(pedido)).toList();
    }

    if (dados is List) {
      return dados.map((pedido) => Map<String, dynamic>.from(pedido)).toList();
    }

    throw Exception('Formato da lista de pedidos inválido.');
  }

  // ============================================================
  // DETALHAR PEDIDO
  // ============================================================

  Future<Map<String, dynamic>> detalharPedido(String pedidoId) async {
    final token = await _buscarToken();

    final response = await http.get(
      Uri.parse('$baseUrl/pedidos/$pedidoId'),
      headers: _headers(token),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Não foi possível carregar o pedido: '
        '${_mensagemErro(response)}',
      );
    }

    return Map<String, dynamic>.from(jsonDecode(response.body));
  }

  // ============================================================
  // ADICIONAR ITEM
  // ============================================================

  Future<Map<String, dynamic>> adicionarItem({
    required String pedidoId,
    required String produtoId,
    required int quantidade,
    String? observacao,
  }) async {
    final token = await _buscarToken();

    final body = <String, dynamic>{
      'produtoId': produtoId,
      'quantidade': quantidade,
    };

    if (observacao != null && observacao.trim().isNotEmpty) {
      body['observacao'] = observacao.trim();
    }

    final response = await http.post(
      Uri.parse('$baseUrl/pedidos/$pedidoId/itens'),
      headers: _headers(token),
      body: jsonEncode(body),
    );

    if (response.statusCode != 201) {
      throw Exception(
        'Não foi possível adicionar o produto: '
        '${_mensagemErro(response)}',
      );
    }

    return Map<String, dynamic>.from(jsonDecode(response.body));
  }

  // ============================================================
  // ALTERAR QUANTIDADE DO ITEM
  // ============================================================

  Future<Map<String, dynamic>> atualizarItem({
    required String pedidoId,
    required String itemId,
    int? quantidade,
    String? observacao,
  }) async {
    final token = await _buscarToken();

    final body = <String, dynamic>{};

    if (quantidade != null) {
      body['quantidade'] = quantidade;
    }

    if (observacao != null) {
      body['observacao'] = observacao.trim();
    }

    final response = await http.patch(
      Uri.parse('$baseUrl/pedidos/$pedidoId/itens/$itemId'),
      headers: _headers(token),
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Não foi possível atualizar o item: '
        '${_mensagemErro(response)}',
      );
    }

    return Map<String, dynamic>.from(jsonDecode(response.body));
  }

  // ============================================================
  // REMOVER ITEM
  // ============================================================

  Future<Map<String, dynamic>> removerItem({
    required String pedidoId,
    required String itemId,
    String motivo = 'Removido pelo garçom',
  }) async {
    final token = await _buscarToken();

    final response = await http.delete(
      Uri.parse('$baseUrl/pedidos/$pedidoId/itens/$itemId'),
      headers: _headers(token),
      body: jsonEncode({'motivo': motivo}),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Não foi possível remover o item: '
        '${_mensagemErro(response)}',
      );
    }

    return Map<String, dynamic>.from(jsonDecode(response.body));
  }

  // ============================================================
  // CONFIRMAR PEDIDO
  // ============================================================

  Future<Map<String, dynamic>> confirmarPedido(String pedidoId) async {
    final token = await _buscarToken();

    final response = await http.post(
      Uri.parse('$baseUrl/pedidos/$pedidoId/confirmar'),
      headers: _headers(token),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Não foi possível confirmar o pedido: '
        '${_mensagemErro(response)}',
      );
    }

    return Map<String, dynamic>.from(jsonDecode(response.body));
  }

  // ============================================================
  // ALTERAR STATUS
  // ============================================================

  Future<Map<String, dynamic>> alterarStatus({
    required String pedidoId,
    required String status,
    String? motivo,
  }) async {
    final token = await _buscarToken();

    final body = <String, dynamic>{'status': status};

    if (motivo != null && motivo.trim().isNotEmpty) {
      body['motivo'] = motivo.trim();
    }

    final response = await http.patch(
      Uri.parse('$baseUrl/pedidos/$pedidoId/status'),
      headers: _headers(token),
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Não foi possível alterar o status do pedido: '
        '${_mensagemErro(response)}',
      );
    }

    return Map<String, dynamic>.from(jsonDecode(response.body));
  }
}
