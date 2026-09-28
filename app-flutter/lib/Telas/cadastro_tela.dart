import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../utils/app_colors.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';

class CadastroTela extends StatefulWidget {
  const CadastroTela({super.key});

  @override
  State<CadastroTela> createState() => _CadastroTelaState();
}

class _CadastroTelaState extends State<CadastroTela> {
  final nomeController = TextEditingController();
  final emailController = TextEditingController();
  final telefoneController = TextEditingController();
  final senhaController = TextEditingController();
  final confirmarSenhaController = TextEditingController();

  bool carregando = false;

  // ============================================================
  // CADASTRO
  // ============================================================

  Future<void> cadastrarUsuario() async {
    if (carregando) return;

    final nome = nomeController.text.trim();
    final email = emailController.text.trim();
    final telefone = telefoneController.text.trim();
    final senha = senhaController.text;
    final confirmarSenha = confirmarSenhaController.text;

    // ==========================================================
    // VALIDAÇÕES
    // ==========================================================

    if (nome.isEmpty ||
        email.isEmpty ||
        senha.isEmpty ||
        confirmarSenha.isEmpty) {
      _mostrarMensagem('Preencha todos os campos obrigatórios.');
      return;
    }

    if (nome.length < 3) {
      _mostrarMensagem('Informe um nome válido.');
      return;
    }

    if (!email.contains('@') || !email.contains('.')) {
      _mostrarMensagem('Digite um e-mail válido.');
      return;
    }

    if (senha.length < 8) {
      _mostrarMensagem('A senha deve conter pelo menos 8 caracteres.');
      return;
    }

    if (!RegExp(r'[A-Za-z]').hasMatch(senha)) {
      _mostrarMensagem('A senha deve conter pelo menos uma letra.');
      return;
    }

    if (!RegExp(r'[0-9]').hasMatch(senha)) {
      _mostrarMensagem('A senha deve conter pelo menos um número.');
      return;
    }

    if (senha != confirmarSenha) {
      _mostrarMensagem('As senhas não são iguais.');
      return;
    }

    setState(() {
      carregando = true;
    });

    try {
      // ========================================================
      // ENVIA O CADASTRO PARA O BACKEND
      // ========================================================

      final body = <String, dynamic>{
        'nome': nome,
        'email': email,
        'senha': senha,
      };

      // Telefone é opcional no backend.
      if (telefone.isNotEmpty) {
        body['telefone'] = telefone;
      }

      final resposta = await http.post(
        Uri.parse('http://localhost:3000/api/auth/registrar'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      );

      // ========================================================
      // CADASTRO REALIZADO
      // ========================================================

      if (resposta.statusCode == 201) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cadastro realizado com sucesso! Agora faça o login.',
            ),
            backgroundColor: AppColors.green,
          ),
        );

        Navigator.pop(context);
        return;
      }

      // ========================================================
      // ERRO RETORNADO PELO BACKEND
      // ========================================================

      String mensagem = 'Não foi possível realizar o cadastro.';

      try {
        final dados = jsonDecode(resposta.body);

        if (dados is Map<String, dynamic>) {
          if (dados['erro'] != null) {
            mensagem = dados['erro'].toString();
          } else if (dados['message'] != null) {
            mensagem = dados['message'].toString();
          } else if (dados['mensagem'] != null) {
            mensagem = dados['mensagem'].toString();
          }
        }
      } catch (_) {
        // Mantém a mensagem padrão.
      }

      if (!mounted) return;

      _mostrarMensagem(mensagem);
    } catch (erro) {
      if (!mounted) return;

      _mostrarMensagem(
        'Não foi possível conectar ao servidor. '
        'Verifique se o backend está iniciado.',
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

  void _mostrarMensagem(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    nomeController.dispose();
    emailController.dispose();
    telefoneController.dispose();
    senhaController.dispose();
    confirmarSenhaController.dispose();
    super.dispose();
  }

  // ============================================================
  // TELA
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.wine,
      body: Stack(
        children: [
          // ====================================================
          // IMAGEM INFERIOR
          // ====================================================
          Positioned(
            left: 0,
            bottom: 0,
            child: IgnorePointer(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(80),
                ),
                child: Image.asset(
                  'assets/images/cadastro.png',
                  width: MediaQuery.of(context).size.width,
                  height: 260,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),

          // ====================================================
          // FORMULÁRIO
          // ====================================================
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height * .76,
              ),
              padding: const EdgeInsets.fromLTRB(24, 34, 24, 26),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(32),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ========================================
                      // TÍTULO
                      // ========================================
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new),
                            onPressed: carregando
                                ? null
                                : () => Navigator.pop(context),
                          ),
                          const Expanded(
                            child: Text(
                              'Cadastre-se',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),

                      const SizedBox(height: 6),

                      const Text(
                        'Crie sua conta para fazer pedidos no Sabor Express.',
                        style: TextStyle(color: AppColors.mutedText),
                      ),

                      const SizedBox(height: 24),

                      // ========================================
                      // NOME
                      // ========================================
                      CustomTextField(
                        hint: 'Nome completo',
                        controller: nomeController,
                        icon: Icons.person_outline,
                      ),

                      const SizedBox(height: 14),

                      // ========================================
                      // E-MAIL
                      // ========================================
                      CustomTextField(
                        hint: 'E-mail',
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        icon: Icons.email_outlined,
                      ),

                      const SizedBox(height: 14),

                      // ========================================
                      // TELEFONE
                      // ========================================
                      CustomTextField(
                        hint: 'Telefone (opcional)',
                        controller: telefoneController,
                        keyboardType: TextInputType.phone,
                        icon: Icons.phone_outlined,
                      ),

                      const SizedBox(height: 14),

                      // ========================================
                      // SENHA
                      // ========================================
                      CustomTextField(
                        hint: 'Senha',
                        obscure: true,
                        controller: senhaController,
                        icon: Icons.lock_outline,
                      ),

                      const SizedBox(height: 8),

                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Text(
                          'Mínimo de 8 caracteres, com letra e número.',
                          style: TextStyle(
                            color: AppColors.mutedText,
                            fontSize: 12,
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // ========================================
                      // CONFIRMAR SENHA
                      // ========================================
                      CustomTextField(
                        hint: 'Confirmar senha',
                        obscure: true,
                        controller: confirmarSenhaController,
                        icon: Icons.verified_user_outlined,
                      ),

                      const SizedBox(height: 24),

                      // ========================================
                      // BOTÃO
                      // ========================================
                      if (carregando)
                        const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.green,
                          ),
                        )
                      else
                        CustomButton(
                          text: 'Cadastrar',
                          icon: Icons.person_add_alt,
                          width: double.infinity,
                          onPressed: cadastrarUsuario,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
