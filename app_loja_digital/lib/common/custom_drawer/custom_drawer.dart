import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_loja_digital/common/custom_drawer/drawer_tile.dart';
import 'package:app_loja_digital/common/custom_drawer/custom_drawer_header.dart';
import 'package:app_loja_digital/common/nav_pages.dart';
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
                      iconData: Icons.home,
                      title: 'Início',
                      page: NavPages.inicio),
                  const DrawerTile(
                      iconData: Icons.list,
                      title: 'Produtos',
                      page: NavPages.produtos),
                  const DrawerTile(
                      iconData: Icons.favorite,
                      title: 'Favoritos',
                      page: NavPages.favoritos),
                  const DrawerTile(
                      iconData: Icons.person,
                      title: 'Perfil',
                      page: NavPages.perfil),
                  const DrawerTile(
                      iconData: Icons.playlist_add_check,
                      title: 'Meus Pedidos',
                      page: NavPages.pedidos),
                  const DrawerTile(
                      iconData: Icons.location_on,
                      title: 'Lojas',
                      page: NavPages.lojas),
                  if (userManager.adminEnabled) ...const <Widget>[
                    Divider(),
                    DrawerTile(
                        iconData: Icons.settings,
                        title: 'Pedidos',
                        page: NavPages.adminPedidos),
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
