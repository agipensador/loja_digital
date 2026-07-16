import 'package:app_loja_digital/screens/products/products_screen.dart';
import 'package:app_loja_digital/screens/admin_orders/admin_orders_screen.dart';
import 'package:app_loja_digital/screens/favorites/favorites_screen.dart';
import 'package:app_loja_digital/screens/home/home_screen.dart';
import 'package:app_loja_digital/screens/orders/orders_screen.dart';
import 'package:app_loja_digital/screens/profile/profile_screen.dart';
import 'package:app_loja_digital/screens/stores/stores_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class BaseScreen extends StatelessWidget {
  const BaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pageController = context.read<PageController>();

    // A ordem aqui deve bater com NavPages (usado pelo menu).
    return PageView(
      controller: pageController,
      physics: const NeverScrollableScrollPhysics(),
      children: const <Widget>[
        HomeScreen(), // 0 - Início
        ProductsScreen(), // 1 - Produtos
        FavoritesScreen(), // 2 - Favoritos
        ProfileScreen(), // 3 - Perfil
        OrdersScreen(), // 4 - Meus Pedidos
        StoresScreen(), // 5 - Lojas
        AdminOrdersScreen(), // 6 - Pedidos (admin)
      ],
    );
  }
}
