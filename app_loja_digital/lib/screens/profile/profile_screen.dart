import 'package:app_loja_digital/models/user_manager.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Meu perfil'), centerTitle: true),
      body: Consumer<UserManager>(
        builder: (_, userManager, __) {
          if (!userManager.isLoggedIn) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text('Você não está logado.'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () =>
                        Navigator.of(context).pushNamed('/login'),
                    child: const Text('Entrar'),
                  ),
                ],
              ),
            );
          }

          final user = userManager.user!;
          final initial =
              user.name.isNotEmpty ? user.name[0].toUpperCase() : '?';

          return ListView(
            children: <Widget>[
              const SizedBox(height: 16),
              Center(
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: primaryColor,
                  child: Text(initial,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 32)),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(user.name,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              Center(
                child: Text(user.email,
                    style: const TextStyle(color: Colors.grey)),
              ),
              if (userManager.adminEnabled)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Chip(
                      label: Text('Administrador'),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              const Divider(),
              ListTile(
                leading: Icon(Icons.location_on, color: primaryColor),
                title: const Text('Meus endereços'),
                subtitle: const Text('Até 5 endereços salvos'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).pushNamed('/addresses'),
              ),
              ListTile(
                leading: Icon(Icons.credit_card, color: primaryColor),
                title: const Text('Formas de pagamento'),
                subtitle: const Text('Cartões e Pix'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    Navigator.of(context).pushNamed('/payment_methods'),
              ),
              ListTile(
                leading: Icon(Icons.favorite, color: primaryColor),
                title: const Text('Favoritos'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).pushNamed('/favorites'),
              ),
              if (userManager.adminEnabled) ...[
                const Divider(),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text('Administração',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.grey)),
                ),
                ListTile(
                  leading: Icon(Icons.inventory_2, color: primaryColor),
                  title: const Text('Controle de estoque'),
                  subtitle: const Text('Estoque por item e alertas'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).pushNamed('/stock'),
                ),
                ListTile(
                  leading: Icon(Icons.favorite_border, color: primaryColor),
                  title: const Text('Publicar no A2'),
                  subtitle: const Text('Enviar até 10 produtos ao app A2'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      Navigator.of(context).pushNamed('/a2_publish'),
                ),
              ],
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Sair',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  userManager.signOut();
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
