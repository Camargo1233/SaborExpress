import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class RelatorioRepository {
  static const String baseUrl =
      'http://localhost:3000/api/restaurantes/sabor-express/relatorios';

  static const String restauranteBaseUrl =
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
      final body = jsonDecode(utf8.decode(response.bodyBytes));

      if (body is Map) {
        if (body['mensagem'] != null) {
          return body['mensagem'].toString();
        }

        if (body['message'] != null) {
          return body['message'].toString();
        }

        if (body['erro'] != null) {
          return body['erro'].toString();
        }

        if (body['error'] != null) {
          return body['error'].toString();
        }
      }
    } catch (_) {
      // Se não conseguir interpretar o JSON,
      // retorna o status HTTP.
    }

    return 'Erro ${response.statusCode}';
  }

  // ============================================================
  // FORMATAR DATA
  // ============================================================

  String _formatarData(DateTime data) {
    final ano = data.year.toString().padLeft(4, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final dia = data.day.toString().padLeft(2, '0');

    return '$ano-$mes-$dia';
  }

  // ============================================================
  // RESUMO
  // ============================================================

  Future<Map<String, dynamic>> buscarResumo({
    required DateTime de,
    required DateTime ate,
  }) async {
    final token = await _buscarToken();

    final uri = Uri.parse('$baseUrl/resumo').replace(
      queryParameters: {'de': _formatarData(de), 'ate': _formatarData(ate)},
    );

    final response = await http
        .get(uri, headers: _headers(token))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(
        'Não foi possível carregar o resumo: '
        '${_mensagemErro(response)}',
      );
    }

    final body = jsonDecode(utf8.decode(response.bodyBytes));

    if (body is! Map) {
      throw Exception('Resposta inválida ao carregar o resumo.');
    }

    return Map<String, dynamic>.from(body);
  }

  // ============================================================
  // RESUMO DE HOJE
  // ============================================================

  Future<Map<String, dynamic>> buscarResumoHoje() async {
    final agora = DateTime.now();

    final hoje = DateTime(agora.year, agora.month, agora.day);

    return buscarResumo(de: hoje, ate: hoje);
  }

  // ============================================================
  // MAIS VENDIDOS
  // ============================================================

  Future<List<Map<String, dynamic>>> buscarMaisVendidos({
    required DateTime de,
    required DateTime ate,
  }) async {
    final token = await _buscarToken();

    final uri = Uri.parse('$baseUrl/mais-vendidos').replace(
      queryParameters: {'de': _formatarData(de), 'ate': _formatarData(ate)},
    );

    final response = await http
        .get(uri, headers: _headers(token))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(
        'Não foi possível carregar os produtos mais vendidos: '
        '${_mensagemErro(response)}',
      );
    }

    final body = jsonDecode(utf8.decode(response.bodyBytes));

    if (body is! List) {
      throw Exception(
        'Resposta inválida ao carregar os produtos mais vendidos.',
      );
    }

    return body
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  // ============================================================
  // MAIS VENDIDOS DA SEMANA
  // ============================================================

  Future<List<Map<String, dynamic>>> buscarMaisVendidosSemana() async {
    final agora = DateTime.now();

    final hoje = DateTime(agora.year, agora.month, agora.day);

    // Hoje + 6 dias anteriores = últimos 7 dias.
    final inicio = hoje.subtract(const Duration(days: 6));

    return buscarMaisVendidos(de: inicio, ate: hoje);
  }

  // ============================================================
  // PRODUTO MAIS VENDIDO DA SEMANA
  // ============================================================

  Future<Map<String, dynamic>?> buscarProdutoMaisVendidoSemana() async {
    final produtos = await buscarMaisVendidosSemana();

    if (produtos.isEmpty) {
      return null;
    }

    return produtos.first;
  }

  // ============================================================
  // MESAS OCUPADAS
  // ============================================================

  Future<Map<String, dynamic>> buscarMesasOcupadas() async {
    final token = await _buscarToken();

    final response = await http
        .get(Uri.parse('$baseUrl/mesas-ocupadas'), headers: _headers(token))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(
        'Não foi possível carregar as mesas ocupadas: '
        '${_mensagemErro(response)}',
      );
    }

    final body = jsonDecode(utf8.decode(response.bodyBytes));

    if (body is! Map) {
      throw Exception('Resposta inválida ao carregar as mesas ocupadas.');
    }

    return Map<String, dynamic>.from(body);
  }

  // ============================================================
  // ATIVIDADES RECENTES DAS MESAS
  // ============================================================

  Future<List<Map<String, dynamic>>> buscarAtividadesRecentes() async {
    final token = await _buscarToken();

    final response = await http
        .get(
          Uri.parse('$restauranteBaseUrl/atividades-recentes'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(
        'Não foi possível carregar as atividades recentes: '
        '${_mensagemErro(response)}',
      );
    }

    final body = jsonDecode(utf8.decode(response.bodyBytes));

    if (body is! List) {
      throw Exception('Resposta inválida ao carregar as atividades recentes.');
    }

    return body
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  // ============================================================
  // DASHBOARD
  // ============================================================

  Future<Map<String, dynamic>> buscarDashboard() async {
    final resultados = await Future.wait<dynamic>([
      buscarResumoHoje(),
      buscarProdutoMaisVendidoSemana(),
      buscarMesasOcupadas(),
    ]);

    final resumo = Map<String, dynamic>.from(resultados[0] as Map);

    final Map<String, dynamic>? maisVendido = resultados[1] == null
        ? null
        : Map<String, dynamic>.from(resultados[1] as Map);

    final mesas = Map<String, dynamic>.from(resultados[2] as Map);

    return {
      'pedidos_total': resumo['pedidos_total'] ?? 0,

      'pedidos_concluidos': resumo['pedidos_concluidos'] ?? 0,

      'pedidos_cancelados': resumo['pedidos_cancelados'] ?? 0,

      'pedidos_em_andamento': resumo['pedidos_em_andamento'] ?? 0,

      'faturamento': resumo['faturamento'] ?? 0,

      'ticket_medio': resumo['ticket_medio'] ?? 0,

      'mais_vendido': maisVendido,

      'mesas_ocupadas': mesas['mesas_ocupadas'] ?? 0,

      'total_mesas': mesas['total_mesas'] ?? 0,

      'mesas_livres': mesas['mesas_livres'] ?? 0,
    };
  }
}
