import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../utils/app_colors.dart';

class RedefinirSenhaTela extends StatefulWidget {
  final String tokenRecuperacao;

  const RedefinirSenhaTela({super.key, required this.tokenRecuperacao});

  @override
  State<RedefinirSenhaTela> createState() => _RedefinirSenhaTelaState();
}

class _RedefinirSenhaTelaState extends State<RedefinirSenhaTela> {
  final _formKey = GlobalKey<FormState>();

  final senhaController = TextEditingController();
  final confirmarSenhaController = TextEditingController();

  bool carregando = false;
  bool senhaAlterada = false;
  bool mostrarSenha = false;
  bool mostrarConfirmacao = false;

  // ============================================================
  // REDEFINIR SENHA
  // ============================================================

  Future<void> redefinirSenha() async {
    if (carregando) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (widget.tokenRecuperacao.isEmpty) {
      _mostrarMensagem('Link de recuperação inválido. Solicite um novo link.');
      return;
    }

    setState(() {
      carregando = true;
    });

    try {
      final resposta = await http
          .post(
            Uri.parse('http://localhost:3000/api/auth/redefinir-senha'),
            headers: {
              'Content-Type': 'application/json; charset=UTF-8',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'tokenRecuperacao': widget.tokenRecuperacao,
              'novaSenha': senhaController.text,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (resposta.statusCode >= 200 && resposta.statusCode < 300) {
        senhaController.clear();
        confirmarSenhaController.clear();

        setState(() {
          senhaAlterada = true;
        });
      } else if (resposta.statusCode == 401 || resposta.statusCode == 400) {
        _mostrarMensagem(
          'Não foi possível redefinir a senha. '
          'Verifique os requisitos ou solicite um novo link.',
        );
      } else if (resposta.statusCode == 429) {
        _mostrarMensagem('Muitas tentativas. Aguarde alguns minutos.');
      } else {
        _mostrarMensagem(
          'Ocorreu um erro ao redefinir sua senha. '
          'Tente novamente.',
        );
      }
    } catch (_) {
      if (!mounted) return;

      _mostrarMensagem(
        'Não foi possível conectar ao servidor. '
        'Verifique sua conexão e tente novamente.',
      );
    } finally {
      if (mounted) {
        setState(() {
          carregando = false;
        });
      }
    }
  }

  // ============================================================
  // VALIDAÇÃO DA SENHA
  // ============================================================

  String? validarSenha(String? valor) {
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

  String? validarConfirmacao(String? valor) {
    if (valor == null || valor.isEmpty) {
      return 'Confirme a nova senha.';
    }

    if (valor != senhaController.text) {
      return 'As senhas não coincidem.';
    }

    return null;
  }

  // ============================================================
  // MENSAGEM
  // ============================================================

  void _mostrarMensagem(String mensagem) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensagem)));
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    senhaController.dispose();
    confirmarSenhaController.dispose();
    super.dispose();
  }

  // ============================================================
  // INTERFACE
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.yellow,
      appBar: AppBar(
        backgroundColor: AppColors.yellow,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.text),
          onPressed: () {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/login',
              (route) => false,
            );
          },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
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
              child: senhaAlterada
                  ? _conteudoSucesso()
                  : widget.tokenRecuperacao.isEmpty
                  ? _conteudoLinkInvalido()
                  : _formulario(),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // FORMULÁRIO
  // ============================================================

  Widget _formulario() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.lock_reset_rounded,
            size: 70,
            color: AppColors.green,
          ),

          const SizedBox(height: 20),

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

          // NOVA SENHA
          TextFormField(
            controller: senhaController,
            obscureText: !mostrarSenha,
            enableSuggestions: false,
            autocorrect: false,
            validator: validarSenha,
            decoration: InputDecoration(
              labelText: 'Nova senha',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    mostrarSenha = !mostrarSenha;
                  });
                },
                icon: Icon(
                  mostrarSenha
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // CONFIRMAR SENHA
          TextFormField(
            controller: confirmarSenhaController,
            obscureText: !mostrarConfirmacao,
            enableSuggestions: false,
            autocorrect: false,
            validator: validarConfirmacao,
            onFieldSubmitted: (_) => redefinirSenha(),
            decoration: InputDecoration(
              labelText: 'Confirmar nova senha',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    mostrarConfirmacao = !mostrarConfirmacao;
                  });
                },
                icon: Icon(
                  mostrarConfirmacao
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),

          const SizedBox(height: 12),

          const Text(
            'A senha deve ter entre 8 e 72 caracteres, '
            'incluindo pelo menos uma letra e um número.',
            style: TextStyle(
              color: AppColors.mutedText,
              fontSize: 12,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: carregando ? null : redefinirSenha,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: carregando
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Salvar nova senha',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SENHA ALTERADA COM SUCESSO
  // ============================================================

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

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Ir para o login',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // LINK INVÁLIDO
  // ============================================================

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

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/esqueci-senha',
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Solicitar novo link'),
          ),
        ),
      ],
    );
  }
}
