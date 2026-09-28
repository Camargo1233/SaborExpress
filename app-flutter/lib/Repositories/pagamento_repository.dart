import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class PagamentoRepository {
  static const String baseUrl =
      'http://localhost:3000/api/restaurantes/sabor-express';

  Future<String> _buscarToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null || token.isEmpty) {
      throw Exception('Usuário não autenticado.');
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
        if (dados['mensagem'] != null) {
          return dados['mensagem'].toString();
        }

        if (dados['message'] != null) {
          return dados['message'].toString();
        }

        if (dados['erro'] != null) {
          return dados['erro'].toString();
        }

        if (dados['error'] != null) {
          return dados['error'].toString();
        }
      }
    } catch (_) {}

    return response.body.isNotEmpty
        ? response.body
        : 'Erro ${response.statusCode}';
  }

  // ============================================================
  // LISTAR PAGAMENTOS DO PEDIDO
  // ============================================================

  Future<List<Map<String, dynamic>>> listarPagamentos(String pedidoId) async {
    final token = await _buscarToken();

    final response = await http.get(
      Uri.parse('$baseUrl/pedidos/$pedidoId/pagamentos'),
      headers: _headers(token),
    );

    if (response.statusCode != 200) {
      throw Exception(_mensagemErro(response));
    }

    final dynamic dados = jsonDecode(response.body);

    if (dados is List) {
      return dados.map((item) => Map<String, dynamic>.from(item)).toList();
    }

    if (dados is Map<String, dynamic> && dados['value'] is List) {
      return (dados['value'] as List)
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    return [];
  }

  // ============================================================
  // CRIAR PAGAMENTO
  // ============================================================

  Future<Map<String, dynamic>> criarPagamento({
    required String pedidoId,
    required String metodo,
    double? valor,
    double? trocoPara,
    String? idempotencyKey,
  }) async {
    final token = await _buscarToken();

    final body = <String, dynamic>{'metodo': metodo};

    if (valor != null) {
      body['valor'] = valor;
    }

    if (trocoPara != null) {
      body['trocoPara'] = trocoPara;
    }

    if (idempotencyKey != null && idempotencyKey.trim().isNotEmpty) {
      body['idempotencyKey'] = idempotencyKey.trim();
    }

    final response = await http.post(
      Uri.parse('$baseUrl/pedidos/$pedidoId/pagamentos'),
      headers: _headers(token),
      body: jsonEncode(body),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(_mensagemErro(response));
    }

    return Map<String, dynamic>.from(jsonDecode(response.body));
  }

  // ============================================================
  // CONFIRMAR PAGAMENTO
  // ============================================================

  Future<Map<String, dynamic>> confirmarPagamento(String pagamentoId) async {
    final token = await _buscarToken();

    final response = await http.post(
      Uri.parse('$baseUrl/pagamentos/$pagamentoId/confirmar'),
      headers: _headers(token),
    );

    if (response.statusCode != 200) {
      throw Exception(_mensagemErro(response));
    }

    return Map<String, dynamic>.from(jsonDecode(response.body));
  }
}
