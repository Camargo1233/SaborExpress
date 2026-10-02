import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class PedidoRepository {
  static const String baseUrl =
      'http://localhost:3000/api/restaurantes/sabor-express';

  // ============================================================
  // TOKEN
  // ============================================================

  Future<String> _buscarToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null || token.isEmpty) {
      throw Exception('Sessão não encontrada. Faça login novamente.');
    }

    return token;
  }

  // ============================================================
  // HEADERS
  // ============================================================

  Map<String, String> _headers(String token) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ============================================================
  // MENSAGEM DE ERRO
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

        if (dados['mensagem'] != null) {
          return dados['mensagem'].toString();
        }
      }
    } catch (_) {}

    return 'Erro ${response.statusCode}';
  }

  // ============================================================
  // CRIAR PEDIDO DE RETIRADA
  // ============================================================

  Future<Map<String, dynamic>> criarPedidoRetirada({String? observacao}) async {
    final token = await _buscarToken();

    final body = <String, dynamic>{'tipo': 'retirada'};

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
        'Não foi possível criar o pedido de retirada: '
        '${_mensagemErro(response)}',
      );
    }

    final dynamic dados = jsonDecode(response.body);

    if (dados is! Map) {
      throw Exception('Resposta inválida ao criar o pedido de retirada.');
    }

    return Map<String, dynamic>.from(dados);
  }

  // ============================================================
  // CRIAR PEDIDO DELIVERY
  // ============================================================

  Future<Map<String, dynamic>> criarPedidoDelivery({
    required String enderecoId,
    String? observacao,
  }) async {
    if (enderecoId.trim().isEmpty) {
      throw Exception('Endereço de entrega não informado.');
    }

    final token = await _buscarToken();

    final body = <String, dynamic>{
      'tipo': 'delivery',
      'enderecoId': enderecoId.trim(),
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
        'Não foi possível criar o pedido de delivery: '
        '${_mensagemErro(response)}',
      );
    }

    final dynamic dados = jsonDecode(response.body);

    if (dados is! Map) {
      throw Exception('Resposta inválida ao criar o pedido de delivery.');
    }

    return Map<String, dynamic>.from(dados);
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
        'Não foi possível criar o pedido: '
        '${_mensagemErro(response)}',
      );
    }

    final dynamic dados = jsonDecode(response.body);

    if (dados is! Map) {
      throw Exception('Resposta inválida ao criar o pedido.');
    }

    return Map<String, dynamic>.from(dados);
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

    final dynamic dados = jsonDecode(response.body);

    if (dados is! Map) {
      throw Exception('Formato do pedido inválido.');
    }

    return Map<String, dynamic>.from(dados);
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

    final dynamic dados = jsonDecode(response.body);

    if (dados is! Map) {
      throw Exception('Resposta inválida ao adicionar o produto.');
    }

    return Map<String, dynamic>.from(dados);
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

    final dynamic dados = jsonDecode(response.body);

    if (dados is! Map) {
      throw Exception('Resposta inválida ao atualizar o item.');
    }

    return Map<String, dynamic>.from(dados);
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

    final dynamic dados = jsonDecode(response.body);

    if (dados is! Map) {
      throw Exception('Resposta inválida ao remover o item.');
    }

    return Map<String, dynamic>.from(dados);
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

    final dynamic dados = jsonDecode(response.body);

    if (dados is! Map) {
      throw Exception('Resposta inválida ao confirmar o pedido.');
    }

    return Map<String, dynamic>.from(dados);
  }

  // ============================================================
  // CRIAR PAGAMENTO
  // ============================================================
  //
  // Métodos aceitos pelo backend:
  //
  // pix
  // cartao_credito
  // cartao_debito
  // dinheiro
  // vale_refeicao
  // na_entrega
  // no_local
  //
  // Para o Pix vamos utilizar:
  //
  // metodo: pix
  //
  // O pagamento nasce como "pendente".
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

    // O backend pode retornar:
    //
    // 201 = pagamento criado
    // 200 = pagamento reaproveitado por idempotência
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'Não foi possível criar o pagamento: '
        '${_mensagemErro(response)}',
      );
    }

    final dynamic dados = jsonDecode(response.body);

    if (dados is! Map) {
      throw Exception('Resposta inválida ao criar o pagamento.');
    }

    return Map<String, dynamic>.from(dados);
  }

  // ============================================================
  // CRIAR PAGAMENTO PIX
  // ============================================================

  Future<Map<String, dynamic>> criarPagamentoPix({
    required String pedidoId,
    double? valor,
    String? idempotencyKey,
  }) {
    return criarPagamento(
      pedidoId: pedidoId,
      metodo: 'pix',
      valor: valor,
      idempotencyKey: idempotencyKey,
    );
  }

  // ============================================================
  // CONFIRMAR PAGAMENTO
  // ============================================================
  //
  // No projeto atual esta rota simula o webhook do provedor.
  //
  // IMPORTANTE:
  //
  // confirmar o pagamento NÃO altera pedidos.status para
  // "concluido".
  //
  // Ele altera o pagamento para "aprovado" e sincroniza
  // pedidos.status_pagamento.
  // ============================================================

  Future<Map<String, dynamic>> confirmarPagamento(String pagamentoId) async {
    final token = await _buscarToken();

    final response = await http.post(
      Uri.parse('$baseUrl/pagamentos/$pagamentoId/confirmar'),
      headers: _headers(token),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Não foi possível confirmar o pagamento: '
        '${_mensagemErro(response)}',
      );
    }

    final dynamic dados = jsonDecode(response.body);

    if (dados is! Map) {
      throw Exception('Resposta inválida ao confirmar o pagamento.');
    }

    return Map<String, dynamic>.from(dados);
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
      throw Exception(
        'Não foi possível carregar os pagamentos: '
        '${_mensagemErro(response)}',
      );
    }

    final dynamic dados = jsonDecode(response.body);

    if (dados is! List) {
      throw Exception('Formato da lista de pagamentos inválido.');
    }

    return dados
        .map((pagamento) => Map<String, dynamic>.from(pagamento))
        .toList();
  }

  // ============================================================
  // ALTERAR STATUS DO PEDIDO
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

    final dynamic dados = jsonDecode(response.body);

    if (dados is! Map) {
      throw Exception('Resposta inválida ao alterar o status do pedido.');
    }

    return Map<String, dynamic>.from(dados);
  }
}
