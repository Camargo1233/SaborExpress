import 'package:flutter/material.dart';
import '../widgets/custom_button.dart';

class SplashTela extends StatelessWidget {
  const SplashTela({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9EC),

      body: Stack(
        fit: StackFit.expand,
        children: [
          // ============================================================
          // IMAGEM DE FUNDO
          // Já contém o logo Sabor Express
          // ============================================================
          Positioned.fill(
            child: Image.asset(
              'assets/images/fundo_splash.png',
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),

          // ============================================================
          // BOTÕES
          // ============================================================
          SafeArea(
            child: Column(
              children: [
                // Empurra os botões para a região central/inferior
                const Spacer(flex: 6),

                // ======================================================
                // BOTÃO LOGAR
                // ======================================================
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 55),
                  child: SizedBox(
                    width: 300,
                    child: CustomButton(
                      text: 'Logar',
                      onPressed: () {
                        Navigator.pushNamed(context, '/login');
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ======================================================
                // BOTÃO CADASTRAR
                // ======================================================
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 55),
                  child: SizedBox(
                    width: 300,
                    child: CustomButton(
                      text: 'Cadastrar',
                      onPressed: () {
                        Navigator.pushNamed(context, '/cadastro');
                      },
                    ),
                  ),
                ),

                // Evita que os botões fiquem em cima
                // da parte vermelha e do prato
                const Spacer(flex: 3),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
