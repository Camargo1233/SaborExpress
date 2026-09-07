import 'package:flutter/material.dart';

import 'utils/app_theme.dart';
import 'Telas/splash_tela.dart';
import 'Telas/login_tela.dart';
import 'Telas/cadastro_tela.dart';

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
      title: "Sabor Express",
      theme: AppTheme.light,
      initialRoute: '/',
      routes: {
        // =========================
        // TELAS INICIAIS
        // =========================
        '/': (context) => const SplashTela(),

        '/login': (context) => const LoginTela(),

        '/cadastro': (context) => const CadastroTela(),

        // =========================
        // CLIENTE
        // =========================
        '/cliente/home': (context) => const HomeTela(),

        '/cliente/carrinho': (context) => const CarrinhoTela(),

        '/cliente/sacola': (context) => const SacolaTela(),

        '/cliente/endereco': (context) => const EnderecoTela(),

        '/cliente/mesa': (context) => const MesaTela(),

        '/cliente/cartao': (context) => const CartaoTela(),

        '/cliente/cadastro-cartao': (context) => const CadastroCartaoTela(),

        '/cliente/pix': (context) => const PixTela(),

        '/cliente/pagamento-sucesso': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          final tipoPedido = args is Map<String, dynamic>
              ? args['tipoPedido']?.toString() ?? 'delivery'
              : 'delivery';
          return PagamentoSucessoTela(tipoPedido: tipoPedido);
        },

        '/cliente/status-pedido': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          final tipoPedido = args is Map<String, dynamic>
              ? args['tipoPedido']?.toString() ?? 'delivery'
              : 'delivery';
          return StatusPedidoTela(tipoPedido: tipoPedido);
        },

        // =========================
        // GARÇOM
        // =========================
        // GARÇOM
        '/garcom/mesa': (context) => const MesasGarcomTela(),

        '/garcom/pedido': (context) => const PedidoMesaGarcomTela(),

        '/garcom/cardapio': (context) => const CardapioGarcomTela(),

        '/garcom/finalizacao': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          final mesa = args is Map<String, dynamic>
              ? args
              : <String, dynamic>{'numero': 'Mesa'};
          return FinalizacaoGarcomTela(mesa: mesa);
        },

        // =========================
        // ADMINISTRADOR
        // =========================
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
