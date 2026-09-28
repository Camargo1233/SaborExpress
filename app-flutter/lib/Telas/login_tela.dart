import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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

  bool carregando = false;

  // ============================================================
  // LOGIN
  // ============================================================

  Future<void> realizarLogin() async {
    if (carregando) return;

    final email = emailController.text.trim().toLowerCase();

    // Não usar trim() na senha: espaços podem fazer parte dela.
    final senha = senhaController.text;

    if (email.isEmpty || senha.isEmpty) {
      _mostrarMensagem('Preencha e-mail e senha.');
      return;
    }

    setState(() {
      carregando = true;
    });

    try {
      final response = await http
          .post(
            Uri.parse('http://localhost:3000/api/auth/login'),
            headers: {
              'Content-Type': 'application/json; charset=UTF-8',
              'Accept': 'application/json',
            },
            body: jsonEncode({'email': email, 'senha': senha}),
          )
          .timeout(const Duration(seconds: 15));

      // Ajuda a identificar o erro sem mostrar a senha nem o token.
      debugPrint('LOGIN - HTTP ${response.statusCode}');

      dynamic dados;

      try {
        dados = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        throw Exception('O servidor retornou uma resposta inválida.');
      }

      // ========================================================
      // ERRO RETORNADO PELO BACKEND
      // ========================================================

      if (response.statusCode != 200) {
        String mensagem = 'Não foi possível entrar.';

        if (dados is Map<String, dynamic>) {
          final erro = dados['erro'] ?? dados['mensagem'] ?? dados['message'];

          if (erro != null && erro.toString().isNotEmpty) {
            mensagem = erro.toString();
          }
        }

        if (response.statusCode == 401) {
          mensagem = 'E-mail ou senha inválidos.';
        } else if (response.statusCode >= 500) {
          mensagem = 'Erro no servidor. Tente novamente.';
        }

        if (!mounted) return;
        _mostrarMensagem(mensagem);
        return;
      }

      // ========================================================
      // VALIDAR RESPOSTA
      // ========================================================

      if (dados is! Map<String, dynamic>) {
        throw Exception('Resposta inválida do servidor.');
      }

      final token = dados['token']?.toString();

      if (token == null || token.isEmpty) {
        throw Exception('O servidor não enviou o token de acesso.');
      }

      final usuario = dados['usuario'];

      final List<dynamic> vinculos = dados['vinculos'] is List
          ? dados['vinculos'] as List<dynamic>
          : [];

      // ========================================================
      // SALVAR SESSÃO
      // ========================================================

      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('token', token);
      await prefs.setString('email_login', email);

      // Limpa informações de um perfil anterior antes de
      // salvar a sessão do usuário atual.
      await prefs.remove('perfil');
      await prefs.remove('restaurante_slug');
      await prefs.remove('restaurante_id');

      if (usuario is Map<String, dynamic>) {
        if (usuario['id'] != null) {
          await prefs.setString('usuario_id', usuario['id'].toString());
        }

        if (usuario['nome'] != null) {
          await prefs.setString('usuario_nome', usuario['nome'].toString());
        }

        if (usuario['email'] != null) {
          await prefs.setString('usuario_email', usuario['email'].toString());
        }
      }

      // ========================================================
      // IDENTIFICAR PERFIL
      // ========================================================

      String rotaDestino = '/cliente/home';

      if (vinculos.isNotEmpty) {
        final vinculo = vinculos.first;

        if (vinculo is Map<String, dynamic>) {
          final perfil = vinculo['perfil']?.toString();
          final restauranteSlug = vinculo['slug']?.toString();
          final restauranteId = vinculo['restaurante_id']?.toString();

          if (perfil != null) {
            await prefs.setString('perfil', perfil);
          }

          if (restauranteSlug != null) {
            await prefs.setString('restaurante_slug', restauranteSlug);
          }

          if (restauranteId != null) {
            await prefs.setString('restaurante_id', restauranteId);
          }

          if (perfil == 'gerente') {
            rotaDestino = '/adm/home';
          } else if (perfil == 'garcom') {
            rotaDestino = '/garcom/mesa';
          }
        }
      }

      if (!mounted) return;

      Navigator.pushReplacementNamed(context, rotaDestino);
    } on http.ClientException catch (erro) {
      debugPrint('LOGIN - Falha de conexão: $erro');

      if (!mounted) return;

      _mostrarMensagem(
        'Não foi possível conectar ao servidor. '
        'Verifique se o backend está ligado.',
      );
    } catch (erro) {
      debugPrint('LOGIN - Erro: $erro');

      if (!mounted) return;

      _mostrarMensagem(erro.toString().replaceFirst('Exception: ', ''));
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
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    emailController.dispose();
    senhaController.dispose();
    super.dispose();
  }

  // ============================================================
  // TELA
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.yellow,
      body: Stack(
        children: [
          // IMAGEM
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SizedBox(
              height: MediaQuery.of(context).size.height * .42,
              child: Image.asset('assets/images/login1.png', fit: BoxFit.cover),
            ),
          ),

          // FORMULÁRIO
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
                    'Entre com seu e-mail e senha para acessar o Sabor Express.',
                    style: TextStyle(color: AppColors.mutedText, height: 1.35),
                  ),

                  const SizedBox(height: 24),

                  // E-MAIL
                  CustomTextField(
                    hint: 'E-mail',
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    icon: Icons.email_outlined,
                  ),

                  const SizedBox(height: 16),

                  // SENHA
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

                  // BOTÃO
                  if (carregando)
                    const Center(
                      child: CircularProgressIndicator(color: AppColors.green),
                    )
                  else
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

          // VOLTAR
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
