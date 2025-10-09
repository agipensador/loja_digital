import 'package:app_loja_digital/screens/base/login/login_screen.dart';
import 'package:app_loja_digital/models/products/components/products_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_loja_digital/common/custom_drawer/custom_drawer.dart';

class BaseScreen extends StatelessWidget {
  const BaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pageController = context.read<PageController>();

    return PageView(
      controller: pageController,
      physics: const NeverScrollableScrollPhysics(),
      children: <Widget>[
        // Página 0 - Home (exemplo)
        Scaffold(
          drawer: CustomDrawer(),
          appBar: AppBar(
            title: const Text('Início'),
          ),
          body: Center(child: Text('Tela Inicial')),
        ),

        // Página 1 - Login (se quiser mostrar a tela de login como página)
        Scaffold(
          drawer: CustomDrawer(),
          appBar: AppBar(
            title: const Text('Login'),
          ),
          body: LoginScreen(),
        ),

        // Página 2 - Produtos
        Scaffold(
          body: ProductsScreen(),
        ),

        // Página 3 - Pedidos
        Scaffold(
          drawer: CustomDrawer(),
          appBar: AppBar(
            title: const Text('Pedidos'),
          ),
          body: const Center(child: Text('Meus pedidos')),
        ),

        // Página 4 - Lojas
        Scaffold(
          drawer: CustomDrawer(),
          appBar: AppBar(
            title: const Text('Lojas'),
          ),
          body: const Center(child: Text('Tela das Lojas')),
        ),
      ],
    );
  }
}
