import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class PagamentoRepository {
  static const String baseUrl =
      'http://localhost:3000/api/restaurantes/sabor-express';

  // ============================================================
  // AUTENTICACAO
  // ============================================================

  Future<String> _buscarToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null || token.trim().isEmpty) {
      throw Exception('Usuário não autenticado. Faça login novamente.');
    }

    return token;
  }

  Map<String, String> _headers(String token) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ============================================================
  // TRATAMENTO DE ERROS
  // ============================================================

  String _mensagemErro(http.Response response) {
    try {
      final dados = jsonDecode(response.body);

      if (dados is Map) {
        for (final campo in ['mensagem', 'message', 'erro', 'error']) {
          final valor = dados[campo];

          if (valor != null && valor.toString().trim().isNotEmpty) {
            return valor.toString();
          }
        }
      }
    } catch (_) {}

    return response.body.isNotEmpty
        ? response.body
        : 'Erro HTTP ${response.statusCode}';
  }

  Map<String, dynamic> _converterMapa(http.Response response) {
    final dynamic dados = jsonDecode(response.body);

    if (dados is! Map) {
      throw Exception('O servidor retornou uma resposta inválida.');
    }

    return Map<String, dynamic>.from(dados);
  }

  String _validarId(String id, String descricao) {
    final valor = id.trim();

    if (valor.isEmpty) {
      throw Exception('$descricao inválido.');
    }

    return Uri.encodeComponent(valor);
  }

  // ============================================================
  // LISTAR PAGAMENTOS
  // ============================================================

  Future<List<Map<String, dynamic>>> listarPagamentos(String pedidoId) async {
    final token = await _buscarToken();
    final id = _validarId(pedidoId, 'Identificador do pedido');

    final response = await http.get(
      Uri.parse('$baseUrl/pedidos/$id/pagamentos'),
      headers: _headers(token),
    );

    if (response.statusCode != 200) {
      throw Exception(_mensagemErro(response));
    }

    final dynamic dados = jsonDecode(response.body);

    if (dados is List) {
      return dados.map((item) => Map<String, dynamic>.from(item)).toList();
    }

    if (dados is Map && dados['value'] is List) {
      return (dados['value'] as List)
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    return [];
  }

  // ============================================================
  // CRIAR PAGAMENTO DEMONSTRATIVO
  // ============================================================

  Future<Map<String, dynamic>> criarPagamento({
    required String pedidoId,
    required String metodo,
    double? valor,
    double? trocoPara,
    String? idempotencyKey,
  }) async {
    final token = await _buscarToken();
    final id = _validarId(pedidoId, 'Identificador do pedido');

    final body = <String, dynamic>{'metodo': metodo};

    if (valor != null) {
      if (valor <= 0) {
        throw Exception('O valor do pagamento deve ser positivo.');
      }

      body['valor'] = valor;
    }

    if (trocoPara != null) {
      body['trocoPara'] = trocoPara;
    }

    if (idempotencyKey != null && idempotencyKey.trim().isNotEmpty) {
      body['idempotencyKey'] = idempotencyKey.trim();
    }

    final response = await http.post(
      Uri.parse('$baseUrl/pedidos/$id/pagamentos'),
      headers: _headers(token),
      body: jsonEncode(body),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(_mensagemErro(response));
    }

    return _converterMapa(response);
  }

  // ============================================================
  // CRIAR PIX DEMONSTRATIVO
  // ============================================================

  Future<Map<String, dynamic>> criarPagamentoPix({
    required String pedidoId,
    String? idempotencyKey,
  }) async {
    return criarPagamento(
      pedidoId: pedidoId,
      metodo: 'pix',
      idempotencyKey: idempotencyKey ?? 'pix-$pedidoId',
    );
  }

  // ============================================================
  // CONSULTAR STATUS DO PIX DEMONSTRATIVO
  // ============================================================

  // Consulta o PostgreSQL por meio da API.
  // Nao acessa Asaas ou qualquer banco.

  Future<Map<String, dynamic>> consultarStatusPix(String pagamentoId) async {
    final token = await _buscarToken();
    final id = _validarId(pagamentoId, 'Identificador do pagamento Pix');

    final response = await http.get(
      Uri.parse('$baseUrl/pagamentos/$id/status-pix'),
      headers: _headers(token),
    );

    if (response.statusCode != 200) {
      throw Exception(_mensagemErro(response));
    }

    return _converterMapa(response);
  }

  // ============================================================
  // CONFIRMAR PAGAMENTO DEMONSTRATIVO
  // ============================================================

  // Esta acao simula a aprovacao do pagamento.
  // O backend valida o pagamento e atualiza
  // os registros no PostgreSQL.
  //
  // Nao movimenta dinheiro real.

  Future<Map<String, dynamic>> confirmarPagamento(String pagamentoId) async {
    final token = await _buscarToken();
    final id = _validarId(pagamentoId, 'Identificador do pagamento');

    final response = await http.post(
      Uri.parse('$baseUrl/pagamentos/$id/confirmar'),
      headers: _headers(token),
    );

    if (response.statusCode != 200) {
      throw Exception(_mensagemErro(response));
    }

    return _converterMapa(response);
  }
}
