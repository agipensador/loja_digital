import 'package:app_loja_digital/screens/products/products_screen.dart';
import 'package:app_loja_digital/screens/admin_orders/admin_orders_screen.dart';
import 'package:app_loja_digital/screens/home/home_screen.dart';
import 'package:app_loja_digital/screens/orders/orders_screen.dart';
import 'package:app_loja_digital/screens/stores/stores_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
        const StoresScreen(),

        // 4 - Pedidos (admin)
        const AdminOrdersScreen(),
      ],
    );
  }
}
