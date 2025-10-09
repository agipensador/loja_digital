import 'package:flutter/material.dart';
import 'package:app_loja_digital/common/custom_drawer/drawer_tile.dart';
import 'package:app_loja_digital/common/custom_drawer/custom_drawer_header.dart';

class CustomDrawer extends StatelessWidget {
  const CustomDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Stack(
        children: <Widget>[
          // Fundo gradiente
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color.fromARGB(255, 203, 236, 241),
                  Colors.white,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // Lista de opções
          ListView(
            children: const <Widget>[
              CustomDrawerHeader(),
              Divider(),
              DrawerTile(iconData: Icons.home, title: 'Início', page: 0),
              DrawerTile(iconData: Icons.list, title: 'Produtos', page: 1),
              DrawerTile(iconData: Icons.shopping_cart, title: 'Meus Pedidos', page: 2),
              DrawerTile(iconData: Icons.store, title: 'Lojas', page: 3),
            ],
          ),
        ],
      ),
    );
  }
}
