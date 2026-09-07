import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_colors.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';

class LoginTela extends StatefulWidget {
  const LoginTela({super.key});

  @override
  State<LoginTela> createState() => _LoginTelaState();
}

class _LoginTelaState extends State<LoginTela> {
  final emailController = TextEditingController();
  final senhaController = TextEditingController();

  Future<void> realizarLogin() async {
    final email = emailController.text.trim();
    final senha = senhaController.text.trim();

    if (email.isEmpty || senha.isEmpty) {
      _mostrarMensagem('Preencha e-mail e senha');
      return;
    }

    if (email == 'admin@sabor.com' && senha == '123') {
      Navigator.pushReplacementNamed(context, '/adm/home');
      return;
    }

    if (email == 'garcom@sabor.com' && senha == '123') {
      Navigator.pushReplacementNamed(context, '/garcom/mesa');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final emailSalvo = prefs.getString('email');
    final senhaSalva = prefs.getString('senha');

    if (!mounted) return;

    final usuarioCadastrado = email == emailSalvo && senha == senhaSalva;
    final clienteMockado =
        email.contains('@') &&
        email != 'admin@sabor.com' &&
        email != 'garcom@sabor.com';

    if (usuarioCadastrado || clienteMockado) {
      Navigator.pushReplacementNamed(context, '/cliente/home');
      return;
    }

    _mostrarMensagem('Confira o e-mail e a senha');
  }

  void _mostrarMensagem(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  void dispose() {
    emailController.dispose();
    senhaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.yellow,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SizedBox(
              height: MediaQuery.of(context).size.height * .42,
              child: Image.asset('assets/images/login.jpg', fit: BoxFit.cover),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: MediaQuery.of(context).size.height * .64,
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Entrar',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Para testar: admin@sabor.com ou garcom@sabor.com com senha 123. Qualquer outro e-mail válido entra como cliente.',
                    style: TextStyle(color: AppColors.mutedText, height: 1.35),
                  ),
                  const SizedBox(height: 24),
                  CustomTextField(
                    hint: 'E-mail',                       
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    icon: Icons.email_outlined,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    hint: 'Senha',
                    obscure: true,
                    controller: senhaController,
                    icon: Icons.lock_outline,
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => _mostrarMensagem(
                        'Recuperação de senha será integrada ao backend.',
                      ),
                      child: const Text('Esqueceu sua senha?'),
                    ),
                  ),
                  const Spacer(),
                  CustomButton(
                    text: 'Entrar',
                    icon: Icons.login,
                    width: double.infinity,
                    onPressed: realizarLogin,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 45,
            left: 20,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                color: Colors.black,
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
