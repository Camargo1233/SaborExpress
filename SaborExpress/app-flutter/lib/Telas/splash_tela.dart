import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../widgets/custom_button.dart';

class SplashTela extends StatelessWidget {
  const SplashTela({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: 0,
            child: Container(
              width: MediaQuery.of(context).size.width,
              height: 160,
              decoration: const BoxDecoration(
                color: AppColors.yellow,
                borderRadius: BorderRadius.only(
                  bottomRight: Radius.circular(140),
                ),
              ),
            ),
          ),

          Positioned(
            bottom: 0,
            child: Container(
              width: MediaQuery.of(context).size.width,
              height: 220,
              decoration: const BoxDecoration(
                color: AppColors.red,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(150)),
              ),
            ),
          ),

          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/images/logo.png', width: 250),

                const SizedBox(height: 100),

                CustomButton(
                  text: 'Logar',
                  onPressed: () {
                    Navigator.pushNamed(context, '/login');
                  },
                ),

                const SizedBox(height: 20),

                CustomButton(
                  text: 'Cadastrar',
                  onPressed: () {
                    Navigator.pushNamed(context, '/cadastro');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
