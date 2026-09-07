import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final senhaController = TextEditingController();
  final confirmarSenhaController = TextEditingController();

  Future<void> cadastrarUsuario() async {
    final nome = nomeController.text.trim();
    final email = emailController.text.trim();
    final senha = senhaController.text.trim();
    final confirmarSenha = confirmarSenhaController.text.trim();

    if (nome.isEmpty ||
        email.isEmpty ||
        senha.isEmpty ||
        confirmarSenha.isEmpty) {
      _mostrarMensagem('Preencha todos os campos');
      return;
    }

    if (!email.contains('@')) {
      _mostrarMensagem('Digite um e-mail válido');
      return;
    }

    if (senha.length < 6) {
      _mostrarMensagem('A senha deve conter pelo menos 6 dígitos');
      return;
    }

    if (senha != confirmarSenha) {
      _mostrarMensagem('As senhas não são iguais');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nome', nome);
    await prefs.setString('email', email);
    await prefs.setString('senha', senha);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cadastro realizado com sucesso!')),
    );
    Navigator.pop(context);
  }

  void _mostrarMensagem(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  void dispose() {
    nomeController.dispose();
    emailController.dispose();
    senhaController.dispose();
    confirmarSenhaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.wine,
      body: Stack(
        children: [
          Positioned(
            left: 0,
            bottom: 0,
            child: IgnorePointer(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(80),
                ),
                child: Image.asset(
                  'assets/images/cadastro.jpg',
                  width: MediaQuery.of(context).size.width,
                  height: 260,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height * .72,
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
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new),
                            onPressed: () => Navigator.pop(context),
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
                        'Crie uma conta de cliente para testar o fluxo de pedido.',
                        style: TextStyle(color: AppColors.mutedText),
                      ),
                      const SizedBox(height: 24),
                      CustomTextField(
                        hint: 'Nome',
                        controller: nomeController,
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: 14),
                      CustomTextField(
                        hint: 'E-mail',
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        icon: Icons.email_outlined,
                      ),
                      const SizedBox(height: 14),
                      CustomTextField(
                        hint: 'Senha',
                        obscure: true,
                        controller: senhaController,
                        icon: Icons.lock_outline,
                      ),
                      const SizedBox(height: 14),
                      CustomTextField(
                        hint: 'Confirmar senha',
                        obscure: true,
                        controller: confirmarSenhaController,
                        icon: Icons.verified_user_outlined,
                      ),
                      const SizedBox(height: 24),
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
