import '../api_config.dart';

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class MesaRepository {
  static final String baseUrl =
      '${ApiConfig.baseUrl}/api/restaurantes/sabor-express';

  // ============================================================
  // TOKEN
  // ============================================================

  Future<String> _buscarToken() async {
    final prefs = await SharedPreferences.getInstance();

    final token = prefs.getString('token');

    if (token == null || token.isEmpty) {
      throw Exception('SessÃ£o nÃ£o encontrada. FaÃ§a login novamente.');
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
  // TRATAR ERROS
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
  // CLIENTE - LISTAR MESAS DISPONÃVEIS
  // ============================================================

  Future<List<Map<String, dynamic>>> listarMesasDisponiveis() async {
    final token = await _buscarToken();

    final response = await http.get(
      Uri.parse('$baseUrl/mesas/disponiveis'),
      headers: _headers(token),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'NÃ£o foi possÃ­vel carregar as mesas: '
        '${_mensagemErro(response)}',
      );
    }

    final dynamic dados = jsonDecode(response.body);

    if (dados is! List) {
      throw Exception('Formato de resposta das mesas invÃ¡lido.');
    }

    return dados.map((mesa) => Map<String, dynamic>.from(mesa)).toList();
  }

  // ============================================================
  // CLIENTE - RESERVAR MESA
  // ============================================================

  Future<Map<String, dynamic>> reservarMesa({
    required String mesaId,
    int? qtdPessoas,
  }) async {
    final token = await _buscarToken();

    final body = <String, dynamic>{};

    if (qtdPessoas != null) {
      body['qtdPessoas'] = qtdPessoas;
    }

    final response = await http.post(
      Uri.parse('$baseUrl/mesas/$mesaId/reservar'),
      headers: _headers(token),
      body: jsonEncode(body),
    );

    if (response.statusCode != 201) {
      throw Exception(
        'NÃ£o foi possÃ­vel reservar a mesa: '
        '${_mensagemErro(response)}',
      );
    }

    final dynamic dados = jsonDecode(response.body);

    if (dados is! Map<String, dynamic>) {
      throw Exception('Resposta invÃ¡lida ao reservar a mesa.');
    }

    return dados;
  }

  // ============================================================
  // EQUIPE - LISTAR TODAS AS MESAS
  // ============================================================

  Future<List<Map<String, dynamic>>> listarMesas() async {
    final token = await _buscarToken();

    final response = await http.get(
      Uri.parse('$baseUrl/mesas'),
      headers: _headers(token),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'NÃ£o foi possÃ­vel carregar as mesas: '
        '${_mensagemErro(response)}',
      );
    }

    final dynamic dados = jsonDecode(response.body);

    if (dados is! List) {
      throw Exception('Formato de resposta das mesas invÃ¡lido.');
    }

    return dados.map((mesa) => Map<String, dynamic>.from(mesa)).toList();
  }

  // ============================================================
  // EQUIPE - ABRIR COMANDA / OCUPAR MESA
  // ============================================================

  Future<Map<String, dynamic>> abrirSessao({
    required String mesaId,
    int? qtdPessoas,
  }) async {
    final token = await _buscarToken();

    final body = <String, dynamic>{};

    if (qtdPessoas != null) {
      body['qtdPessoas'] = qtdPessoas;
    }

    final response = await http.post(
      Uri.parse('$baseUrl/mesas/$mesaId/sessoes'),
      headers: _headers(token),
      body: jsonEncode(body),
    );

    if (response.statusCode != 201) {
      throw Exception(
        'NÃ£o foi possÃ­vel ocupar a mesa: '
        '${_mensagemErro(response)}',
      );
    }

    final dynamic dados = jsonDecode(response.body);

    if (dados is! Map<String, dynamic>) {
      throw Exception('Resposta invÃ¡lida ao abrir a mesa.');
    }

    return dados;
  }

  // ============================================================
  // DETALHAR COMANDA
  // ============================================================

  Future<Map<String, dynamic>> detalharSessao(String sessaoId) async {
    final token = await _buscarToken();

    final response = await http.get(
      Uri.parse('$baseUrl/sessoes/$sessaoId'),
      headers: _headers(token),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'NÃ£o foi possÃ­vel carregar a comanda: '
        '${_mensagemErro(response)}',
      );
    }

    final dynamic dados = jsonDecode(response.body);

    if (dados is! Map<String, dynamic>) {
      throw Exception('Resposta invÃ¡lida da comanda.');
    }

    return dados;
  }

  // ============================================================
  // TAXA DE SERVIÃ‡O
  // ============================================================

  Future<Map<String, dynamic>> definirServico({
    required String sessaoId,
    required bool aceito,
  }) async {
    final token = await _buscarToken();

    final response = await http.patch(
      Uri.parse('$baseUrl/sessoes/$sessaoId/servico'),
      headers: _headers(token),
      body: jsonEncode({'aceito': aceito}),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'NÃ£o foi possÃ­vel alterar a taxa de serviÃ§o: '
        '${_mensagemErro(response)}',
      );
    }

    final dynamic dados = jsonDecode(response.body);

    if (dados is! Map<String, dynamic>) {
      throw Exception('Resposta invÃ¡lida ao alterar a taxa de serviÃ§o.');
    }

    return dados;
  }

  // ============================================================
  // FECHAR COMANDA
  // ============================================================

  Future<Map<String, dynamic>> fecharSessao(String sessaoId) async {
    final token = await _buscarToken();

    final response = await http.post(
      Uri.parse('$baseUrl/sessoes/$sessaoId/fechar'),
      headers: _headers(token),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'NÃ£o foi possÃ­vel fechar a comanda: '
        '${_mensagemErro(response)}',
      );
    }

    final dynamic dados = jsonDecode(response.body);

    if (dados is! Map<String, dynamic>) {
      throw Exception('Resposta invÃ¡lida ao fechar a comanda.');
    }

    return dados;
  }
}
