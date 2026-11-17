import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../api_config.dart';
import '../utils/app_colors.dart';

class RedefinirSenhaTela extends StatefulWidget {
  final String tokenRecuperacao;

  const RedefinirSenhaTela({super.key, required this.tokenRecuperacao});

  @override
  State<RedefinirSenhaTela> createState() => _RedefinirSenhaTelaState();
}

class _RedefinirSenhaTelaState extends State<RedefinirSenhaTela> {
  final _formKey = GlobalKey<FormState>();

  final _senhaController = TextEditingController();
  final _confirmarController = TextEditingController();

  bool _carregando = false;
  bool _senhaAlterada = false;
  bool _mostrarSenha = false;
  bool _mostrarConfirmacao = false;

  String get _token => widget.tokenRecuperacao.trim();

  @override
  void dispose() {
    _senhaController.dispose();
    _confirmarController.dispose();
    super.dispose();
  }

  String? _validarSenha(String? valor) {
    final senha = valor ?? '';

    if (senha.isEmpty) {
      return 'Informe uma nova senha.';
    }

    if (senha.length < 8) {
      return 'A senha deve ter pelo menos 8 caracteres.';
    }

    if (senha.length > 72) {
      return 'A senha deve ter no máximo 72 caracteres.';
    }

    if (!RegExp(r'[A-Za-z]').hasMatch(senha) ||
        !RegExp(r'[0-9]').hasMatch(senha)) {
      return 'Use pelo menos uma letra e um número.';
    }

    return null;
  }

  String? _validarConfirmacao(String? valor) {
    if (valor == null || valor.isEmpty) {
      return 'Confirme a nova senha.';
    }

    if (valor != _senhaController.text) {
      return 'As senhas não coincidem.';
    }

    return null;
  }

  void _mostrarMensagem(String mensagem) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(mensagem),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
  }

  String _mensagemServidor(http.Response resposta) {
    try {
      final body = jsonDecode(utf8.decode(resposta.bodyBytes));

      if (body is Map) {
        final mensagem =
            body['mensagem'] ??
            body['message'] ??
            body['erro'] ??
            body['error'];

        if (mensagem is String && mensagem.trim().isNotEmpty) {
          return mensagem;
        }
      }
    } catch (_) {
      // O servidor pode devolver uma resposta sem JSON.
    }

    switch (resposta.statusCode) {
      case 400:
        return 'Link inválido ou dados incorretos. '
            'Solicite um novo link de recuperação.';
      case 401:
      case 403:
        return 'O link de recuperação é inválido '
            'ou expirou. Solicite outro.';
      case 404:
        return 'Serviço de redefinição não encontrado. '
            'Verifique a configuração do servidor.';
      case 429:
        return 'Muitas tentativas. Aguarde alguns minutos.';
      default:
        return 'Não foi possível redefinir a senha. '
            'Erro ${resposta.statusCode}.';
    }
  }

  Future<void> _redefinirSenha() async {
    if (_carregando) return;

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (_token.isEmpty) {
      _mostrarMensagem(
        'Link de recuperação inválido. '
        'Solicite um novo link.',
      );
      return;
    }

    setState(() {
      _carregando = true;
    });

    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/auth/redefinir-senha');

      final resposta = await http
          .post(
            uri,
            headers: const {
              'Content-Type': 'application/json; charset=UTF-8',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'tokenRecuperacao': _token,
              'novaSenha': _senhaController.text,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (resposta.statusCode >= 200 && resposta.statusCode < 300) {
        _senhaController.clear();
        _confirmarController.clear();

        setState(() {
          _senhaAlterada = true;
        });
      } else {
        _mostrarMensagem(_mensagemServidor(resposta));
      }
    } on TimeoutException {
      _mostrarMensagem(
        'O servidor demorou para responder. '
        'Tente novamente.',
      );
    } catch (_) {
      _mostrarMensagem(
        'Não foi possível conectar ao servidor. '
        'Verifique sua conexão e tente novamente.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _carregando = false;
        });
      }
    }
  }

  void _irParaLogin() {
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  void _solicitarNovoLink() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/esqueci-senha',
      (route) => false,
    );
  }

  InputDecoration _decoracaoCampo({
    required String titulo,
    required bool visivel,
    required VoidCallback alternarVisibilidade,
  }) {
    return InputDecoration(
      labelText: titulo,
      prefixIcon: const Icon(Icons.lock_outline, color: AppColors.green),
      suffixIcon: IconButton(
        onPressed: alternarVisibilidade,
        icon: Icon(
          visivel ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        ),
      ),
      filled: true,
      fillColor: const Color(0xFFF8F9FA),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD9E3DA)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.green, width: 2),
      ),
    );
  }

  Widget _botaoPrincipal({
    required String texto,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.green,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _carregando
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                texto,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _formulario() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.lock_reset_rounded,
            color: AppColors.green,
            size: 72,
          ),
          const SizedBox(height: 18),
          const Text(
            'Criar nova senha',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Informe sua nova senha para voltar '
            'a acessar o SaborExpress.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.mutedText, height: 1.5),
          ),
          const SizedBox(height: 28),

          TextFormField(
            controller: _senhaController,
            obscureText: !_mostrarSenha,
            enableSuggestions: false,
            autocorrect: false,
            validator: _validarSenha,
            textInputAction: TextInputAction.next,
            decoration: _decoracaoCampo(
              titulo: 'Nova senha',
              visivel: _mostrarSenha,
              alternarVisibilidade: () {
                setState(() {
                  _mostrarSenha = !_mostrarSenha;
                });
              },
            ),
          ),

          const SizedBox(height: 16),

          TextFormField(
            controller: _confirmarController,
            obscureText: !_mostrarConfirmacao,
            enableSuggestions: false,
            autocorrect: false,
            validator: _validarConfirmacao,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) {
              if (!_carregando) {
                _redefinirSenha();
              }
            },
            decoration: _decoracaoCampo(
              titulo: 'Confirmar nova senha',
              visivel: _mostrarConfirmacao,
              alternarVisibilidade: () {
                setState(() {
                  _mostrarConfirmacao = !_mostrarConfirmacao;
                });
              },
            ),
          ),

          const SizedBox(height: 14),

          const Text(
            'A senha deve ter entre 8 e 72 caracteres, '
            'incluindo pelo menos uma letra e um número.',
            style: TextStyle(
              color: AppColors.mutedText,
              fontSize: 12,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 26),

          _botaoPrincipal(
            texto: 'Salvar nova senha',
            onPressed: _carregando ? null : _redefinirSenha,
          ),

          const SizedBox(height: 14),

          TextButton(
            onPressed: _carregando ? null : _irParaLogin,
            child: const Text(
              'Voltar para o login',
              style: TextStyle(color: AppColors.green),
            ),
          ),
        ],
      ),
    );
  }

  Widget _conteudoSucesso() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.check_circle_outline,
          size: 80,
          color: AppColors.green,
        ),
        const SizedBox(height: 20),
        const Text(
          'Senha alterada!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Sua senha foi atualizada com sucesso. '
          'Agora você pode entrar no SaborExpress '
          'utilizando sua nova senha.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.mutedText, height: 1.5),
        ),
        const SizedBox(height: 28),
        _botaoPrincipal(texto: 'Ir para o login', onPressed: _irParaLogin),
      ],
    );
  }

  Widget _conteudoLinkInvalido() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.link_off_rounded, size: 70, color: Colors.orange),
        const SizedBox(height: 20),
        const Text(
          'Link inválido',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Não encontramos um token de recuperação '
          'neste link. Solicite um novo e-mail.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.mutedText, height: 1.5),
        ),
        const SizedBox(height: 28),
        _botaoPrincipal(
          texto: 'Solicitar novo link',
          onPressed: _solicitarNovoLink,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.yellow,
      appBar: AppBar(
        backgroundColor: AppColors.yellow,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.text),
          onPressed: _irParaLogin,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: _senhaAlterada
                  ? _conteudoSucesso()
                  : _token.isEmpty
                  ? _conteudoLinkInvalido()
                  : _formulario(),
            ),
          ),
        ),
      ),
    );
  }
}
