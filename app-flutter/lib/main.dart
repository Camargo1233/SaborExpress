import 'package:flutter/material.dart';

import 'utils/app_theme.dart';
import 'Telas/splash_tela.dart';
import 'Telas/login_tela.dart';
import 'Telas/cadastro_tela.dart';

// RECUPERAÇÃO DE SENHA
import 'Telas/esqueci_senha_tela.dart';
import 'Telas/redefinir_senha_tela.dart';

// CLIENTE
import 'Telas/home_tela.dart';
import 'Telas/carrinho_tela.dart';
import 'Telas/sacola_tela.dart';
import 'Telas/endereco_tela.dart';
import 'Telas/mesa_tela.dart';
import 'Telas/cartao_tela.dart';
import 'Telas/cadastro_cartao_tela.dart';
import 'Telas/pix_tela.dart';
import 'Telas/pagamento_sucesso_tela.dart';
import 'Telas/status_pedido_tela.dart';

// GARÇOM
import 'TelasGarcom/mesas_garcom_tela.dart';
import 'TelasGarcom/pedido_mesa_garcom_tela.dart';
import 'TelasGarcom/cardapio_garcom_tela.dart';
import 'TelasGarcom/finalizacao_garcom_tela.dart';

// ADMINISTRADOR
import 'TelasAdm/cardapio_gerente_tela.dart';
import 'TelasAdm/home_gerente_tela.dart';
import 'TelasAdm/pedidos_gerente_tela.dart';
import 'TelasAdm/relatorio_gerente_tela.dart';
import 'TelasAdm/produto_gerente_tela.dart';
import 'TelasAdm/adicionar_gerente_tela.dart';

void main() {
  runApp(const SaborExpressApp());
}

class SaborExpressApp extends StatelessWidget {
  const SaborExpressApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sabor Express',
      theme: AppTheme.light,
      initialRoute: '/',

      routes: {
        // ============================================================
        // TELAS INICIAIS
        // ============================================================
        '/': (context) => const SplashTela(),

        '/login': (context) => const LoginTela(),

        '/cadastro': (context) => const CadastroTela(),

        // ============================================================
        // RECUPERAÇÃO DE SENHA
        // ============================================================
        '/esqueci-senha': (context) => const EsqueciSenhaTela(),

        '/redefinir-senha': (context) {
          // Token enviado pelo link de recuperação.
          //
          // Exemplo Flutter Web:
          // http://localhost:8080/#/redefinir-senha?token=ABC

          final uri = Uri.base;

          String? tokenRecuperacao = uri.queryParameters['token'];

          // O Flutter Web utiliza o fragmento (#)
          // para representar rotas.
          if (tokenRecuperacao == null || tokenRecuperacao.isEmpty) {
            final fragmento = uri.fragment;

            if (fragmento.isNotEmpty) {
              tokenRecuperacao = Uri.tryParse(
                fragmento,
              )?.queryParameters['token'];
            }
          }

          // Também aceita token enviado como argumento
          // durante uma navegação interna.
          if (tokenRecuperacao == null || tokenRecuperacao.isEmpty) {
            final args = ModalRoute.of(context)?.settings.arguments;

            if (args is Map) {
              tokenRecuperacao =
                  args['tokenRecuperacao']?.toString() ??
                  args['token']?.toString();
            }
          }

          return RedefinirSenhaTela(tokenRecuperacao: tokenRecuperacao ?? '');
        },

        // ============================================================
        // CLIENTE
        // ============================================================
        '/cliente/home': (context) => const HomeTela(),

        '/cliente/carrinho': (context) => const CarrinhoTela(),

        '/cliente/sacola': (context) => const SacolaTela(),

        '/cliente/endereco': (context) => const EnderecoTela(),

        '/cliente/mesa': (context) => const MesaTela(),

        '/cliente/cartao': (context) => const CartaoTela(),

        '/cliente/cadastro-cartao': (context) => const CadastroCartaoTela(),

        '/cliente/pix': (context) => const PixTela(),

        // ============================================================
        // PAGAMENTO SUCESSO
        // ============================================================
        '/cliente/pagamento-sucesso': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;

          String tipoPedido = 'delivery';
          String? pedidoId;

          if (args is Map) {
            tipoPedido = args['tipoPedido']?.toString() ?? 'delivery';

            pedidoId =
                args['pedidoId']?.toString() ?? args['pedido_id']?.toString();
          }

          if (pedidoId == null || pedidoId.isEmpty) {
            return const Scaffold(
              body: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Não foi possível identificar o pedido. '
                    'Verifique se ele foi registrado.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }

          return PagamentoSucessoTela(
            tipoPedido: tipoPedido,
            pedidoId: pedidoId,
          );
        },

        // ============================================================
        // STATUS DO PEDIDO
        // ============================================================
        '/cliente/status-pedido': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;

          String tipoPedido = 'delivery';
          String? pedidoId;

          if (args is Map) {
            tipoPedido = args['tipoPedido']?.toString() ?? 'delivery';

            pedidoId =
                args['pedidoId']?.toString() ?? args['pedido_id']?.toString();
          }

          if (pedidoId == null || pedidoId.isEmpty) {
            return const Scaffold(
              body: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Pedido não encontrado. '
                    'Não foi possível carregar o status.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }

          return StatusPedidoTela(tipoPedido: tipoPedido, pedidoId: pedidoId);
        },

        // ============================================================
        // GARÇOM
        // ============================================================
        '/garcom/mesa': (context) => const MesasGarcomTela(),

        '/garcom/pedido': (context) => const PedidoMesaGarcomTela(),

        '/garcom/cardapio': (context) => const CardapioGarcomTela(),

        '/garcom/finalizacao': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;

          final Map<String, dynamic> mesa;

          if (args is Map<String, dynamic>) {
            mesa = args;
          } else if (args is Map) {
            mesa = Map<String, dynamic>.from(args);
          } else {
            mesa = <String, dynamic>{'numero': 'Mesa'};
          }

          return FinalizacaoGarcomTela(mesa: mesa);
        },

        // ============================================================
        // ADMINISTRADOR
        // ============================================================
        '/adm/home': (context) => const HomeGerenteTela(),

        '/adm/cardapio': (context) => const CardapioGerenteTela(),

        '/adm/pedidos': (context) => const PedidosGerenteTela(),

        '/adm/relatorios': (context) => const RelatorioGerenteTela(),

        '/adm/produto': (context) => const ProdutoGerenteTela(),

        '/adm/adicionar-produto': (context) => const AdicionarGerenteTela(),
      },
    );
  }
}
