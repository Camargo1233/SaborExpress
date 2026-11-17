import '../api_config.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../utils/app_colors.dart';

class EsqueciSenhaTela extends StatefulWidget {
  const EsqueciSenhaTela({super.key});

  @override
  State<EsqueciSenhaTela> createState() => _EsqueciSenhaTelaState();
}

class _EsqueciSenhaTelaState extends State<EsqueciSenhaTela> {
  final emailController = TextEditingController();

  bool carregando = false;
  bool emailEnviado = false;

  // ============================================================
  // SOLICITAR RECUPERAÃ‡ÃƒO DE SENHA
  // ============================================================

  Future<void> enviarRecuperacao() async {
    if (carregando) return;

    final email = emailController.text.trim().toLowerCase();

    if (email.isEmpty || !email.contains('@')) {
      _mostrarMensagem('Informe um e-mail vÃ¡lido.');
      return;
    }

    setState(() {
      carregando = true;
    });

    try {
      final resposta = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/api/auth/esqueci-senha'),
            headers: {
              'Content-Type': 'application/json; charset=UTF-8',
              'Accept': 'application/json',
            },
            body: jsonEncode({'email': email}),
          )
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (resposta.statusCode >= 200 && resposta.statusCode < 300) {
        setState(() {
          emailEnviado = true;
        });
      } else if (resposta.statusCode == 429) {
        _mostrarMensagem('Muitas tentativas. Aguarde alguns minutos.');
      } else {
        _mostrarMensagem(
          'NÃ£o foi possÃ­vel processar a solicitaÃ§Ã£o. '
          'Tente novamente.',
        );
      }
    } catch (_) {
      if (!mounted) return;

      _mostrarMensagem(
        'NÃ£o foi possÃ­vel conectar ao servidor. '
        'Verifique se o backend estÃ¡ ligado.',
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
  // MENSAGEM
  // ============================================================

  void _mostrarMensagem(String mensagem) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensagem)));
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    emailController.dispose();
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
          onPressed: () => Navigator.pop(context),
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
              child: emailEnviado ? _conteudoEnviado() : _formulario(),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // FORMULÃRIO
  // ============================================================

  Widget _formulario() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.lock_reset_rounded, size: 70, color: AppColors.green),

        const SizedBox(height: 20),

        const Text(
          'Esqueceu sua senha?',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
          ),
        ),

        const SizedBox(height: 12),

        const Text(
          'Informe o e-mail cadastrado no SaborExpress. '
          'Enviaremos um link para vocÃª criar uma nova senha.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.mutedText, height: 1.5),
        ),

        const SizedBox(height: 28),

        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.email],
          onSubmitted: (_) => enviarRecuperacao(),
          decoration: InputDecoration(
            labelText: 'E-mail',
            hintText: 'exemplo@email.com',
            prefixIcon: const Icon(Icons.email_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),

        const SizedBox(height: 24),

        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: carregando ? null : enviarRecuperacao,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: carregando
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Enviar link de recuperaÃ§Ã£o',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),

        const SizedBox(height: 16),

        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Voltar para o login'),
        ),
      ],
    );
  }

  // ============================================================
  // CONFIRMAÃ‡ÃƒO
  // ============================================================

  Widget _conteudoEnviado() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.mark_email_read_outlined,
          size: 80,
          color: AppColors.green,
        ),

        const SizedBox(height: 20),

        const Text(
          'Verifique seu e-mail',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
          ),
        ),

        const SizedBox(height: 14),

        const Text(
          'Se o e-mail informado estiver cadastrado, '
          'vocÃª receberÃ¡ um link para redefinir sua senha.\n\n'
          'Verifique tambÃ©m a pasta de spam.',
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
              'Voltar para o login',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}
