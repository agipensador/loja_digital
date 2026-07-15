import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_loja_digital/common/custom_drawer/drawer_tile.dart';
import 'package:app_loja_digital/common/custom_drawer/custom_drawer_header.dart';
import 'package:app_loja_digital/models/user_manager.dart';

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
                  ListTile(
                    leading: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.favorite,
                          size: 32, color: Colors.grey[700]),
                    ),
                    title: Text('Favoritos',
                        style: TextStyle(
                            fontSize: 16, color: Colors.grey[700])),
                    onTap: () {
                      Navigator.of(context)
                          .popUntil((route) => route.isFirst);
                      Navigator.of(context).pushNamed('/favorites');
                    },
                  ),
                  ListTile(
                    leading: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.credit_card,
                          size: 32, color: Colors.grey[700]),
                    ),
                    title: Text('Formas de pagamento',
                        style: TextStyle(
                            fontSize: 16, color: Colors.grey[700])),
                    onTap: () {
                      Navigator.of(context)
                          .popUntil((route) => route.isFirst);
                      Navigator.of(context).pushNamed('/payment_methods');
                    },
                  ),
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
