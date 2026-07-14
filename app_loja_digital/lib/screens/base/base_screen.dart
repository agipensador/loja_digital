import 'package:app_loja_digital/screens/products/products_screen.dart';
import 'package:app_loja_digital/screens/admin_orders/admin_orders_screen.dart';
import 'package:app_loja_digital/screens/home/home_screen.dart';
import 'package:app_loja_digital/screens/orders/orders_screen.dart';
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
        // 0 - Início
        const HomeScreen(),

        // 1 - Produtos
        const ProductsScreen(),

        // 2 - Meus Pedidos
        const OrdersScreen(),

        // 3 - Lojas
        Scaffold(
          drawer: const CustomDrawer(),
          appBar: AppBar(title: const Text('Lojas')),
          body: const Center(child: Text('Tela das Lojas')),
        ),

        // 4 - Pedidos (admin)
        const AdminOrdersScreen(),
      ],
    );
  }
}
