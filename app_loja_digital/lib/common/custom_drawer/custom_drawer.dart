import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_loja_digital/common/custom_drawer/drawer_tile.dart';
import 'package:app_loja_digital/common/custom_drawer/custom_drawer_header.dart';
import 'package:app_loja_digital/models/theme_manager.dart';
import 'package:app_loja_digital/models/user_manager.dart';

class CustomDrawer extends StatelessWidget {
  const CustomDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final menuColor = context.watch<ThemeManager>().menu;
    return Drawer(
      child: Stack(
        children: <Widget>[
          // Fundo do menu (cor personalizável pelo admin)
          Container(color: menuColor),
          // Lista de opções
          Consumer<UserManager>(
            builder: (_, userManager, __) {
              return ListView(
                children: <Widget>[
                  const CustomDrawerHeader(),
                  const Divider(),
                  const DrawerTile(
                      iconData: Icons.home, title: 'Início', page: 0),
                  const DrawerTile(
                      iconData: Icons.list, title: 'Produtos', page: 1),
                  const DrawerTile(
                      iconData: Icons.favorite,
                      title: 'Favoritos',
                      route: '/favorites'),
                  const DrawerTile(
                      iconData: Icons.person,
                      title: 'Meu perfil',
                      route: '/profile'),
                  const DrawerTile(
                      iconData: Icons.playlist_add_check,
                      title: 'Meus Pedidos',
                      page: 2),
                  const DrawerTile(
                      iconData: Icons.location_on, title: 'Lojas', page: 3),
                  if (userManager.adminEnabled) ...const <Widget>[
                    Divider(),
                    DrawerTile(
                        iconData: Icons.settings,
                        title: 'Pedidos',
                        page: 4),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
