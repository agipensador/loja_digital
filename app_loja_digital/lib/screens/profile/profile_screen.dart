import 'package:app_loja_digital/models/product_manager.dart';
import 'package:app_loja_digital/models/stores_manager.dart';
import 'package:app_loja_digital/models/staff_member.dart';
import 'package:app_loja_digital/models/tenant_manager.dart';
import 'package:app_loja_digital/common/custom_drawer/custom_drawer.dart';
import 'package:app_loja_digital/models/user_manager.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      drawer: const CustomDrawer(),
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Perfil'), centerTitle: true),
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
              if (!userManager.emailVerified)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withAlpha(120)),
                    ),
                    child: Row(
                      children: <Widget>[
                        const Icon(Icons.warning_amber,
                            color: Colors.orange),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text('E-mail não verificado',
                              style: TextStyle(fontSize: 13)),
                        ),
                        TextButton(
                          onPressed: userManager.reloadEmailVerification,
                          child: const Text('Já verifiquei'),
                        ),
                        TextButton(
                          onPressed: () async {
                            await userManager.sendEmailVerification();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'E-mail de verificação reenviado.'),
                                ),
                              );
                            }
                          },
                          child: const Text('Reenviar'),
                        ),
                      ],
                    ),
                  ),
                ),
              if (userManager.adminEnabled)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Chip(
                      label: Text(userManager.masterEnabled
                          ? 'Administrador'
                          : userManager.staffRoleLabel),
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
              if (userManager.adminEnabled) ...[
                const Divider(),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text('Administração',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.grey)),
                ),
                if (userManager.can(Perm.appearance))
                  ListTile(
                    leading: Icon(Icons.palette, color: primaryColor),
                    title: const Text('Aparência do app'),
                    subtitle: const Text('Cores, nome e visual da loja'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        Navigator.of(context).pushNamed('/appearance'),
                  ),
                if (userManager.can(Perm.productsCreate))
                  ListTile(
                    leading: Icon(Icons.upload_file, color: primaryColor),
                    title: const Text('Importar catálogo'),
                    subtitle: const Text(
                        'Planilha CSV da Shopify, Nuvemshop ou modelo'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        Navigator.of(context).pushNamed('/import_catalog'),
                  ),
                if (userManager.can(Perm.stock)) ...[
                  const _StockAlerts(),
                  ListTile(
                    leading: Icon(Icons.inventory_2, color: primaryColor),
                    title: const Text('Controle de estoque'),
                    subtitle: const Text('Estoque por unidade e alertas'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).pushNamed('/stock'),
                  ),
                  ListTile(
                    leading: Icon(Icons.contacts, color: primaryColor),
                    title: const Text('Fornecedores'),
                    subtitle: const Text('Pedido de reposição pelo WhatsApp'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        Navigator.of(context).pushNamed('/suppliers'),
                  ),
                ],
                if (userManager.can(Perm.deliveryZones))
                  ListTile(
                    leading: Icon(Icons.local_shipping, color: primaryColor),
                    title: const Text('Zonas de entrega'),
                    subtitle: const Text(
                        'Áreas, dias e valores da sua entrega'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        Navigator.of(context).pushNamed('/delivery_zones'),
                  ),
              ],
              if (userManager.masterEnabled) ...[
                ListTile(
                  leading: Icon(Icons.favorite_border, color: primaryColor),
                  title: const Text('Publicar no A2'),
                  subtitle: const Text('Enviar até 10 produtos ao app A2'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      Navigator.of(context).pushNamed('/a2_publish'),
                ),
                ListTile(
                  leading: Icon(Icons.group, color: primaryColor),
                  title: const Text('Equipe da loja'),
                  subtitle: const Text(
                      'Sócios e funcionários, permissões e unidades'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).pushNamed('/team'),
                ),
                ListTile(
                  leading: Icon(Icons.workspace_premium, color: primaryColor),
                  title: const Text('Assinatura'),
                  subtitle: const Text('Plano, pagamento e período gratuito'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      Navigator.of(context).pushNamed('/subscription'),
                ),
                ListTile(
                  leading: Icon(Icons.bar_chart, color: primaryColor),
                  title: const Text('Relatório financeiro'),
                  subtitle: const Text('Receita e pedidos por mês'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).pushNamed('/reports'),
                ),
                ListTile(
                  leading: Icon(Icons.account_balance, color: primaryColor),
                  title: const Text('Mercado Pago'),
                  subtitle: const Text('Conectar conta para receber pedidos'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).pushNamed('/mp_connect'),
                ),
              ],
              const Divider(),
              ListTile(
                leading: Icon(Icons.description_outlined, color: primaryColor),
                title: const Text('Termos de Uso'),
                onTap: () => Navigator.of(context).pushNamed('/terms'),
              ),
              ListTile(
                leading: Icon(Icons.privacy_tip_outlined, color: primaryColor),
                title: const Text('Política de Privacidade'),
                onTap: () => Navigator.of(context).pushNamed('/privacy'),
              ),
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
              if (userManager.masterEnabled)
                _CloseStoreTile()
              else
                ListTile(
                  leading:
                      const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text('Excluir conta',
                      style: TextStyle(color: Colors.red)),
                  onTap: () => _confirmDeleteAccount(context, userManager),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmDeleteAccount(
      BuildContext context, UserManager userManager) async {
    final passwordController = TextEditingController();
    final String? password = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir conta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
                'Esta ação é irreversível. Sua conta, endereços, cartões e '
                'favoritos serão apagados. Pedidos já realizados continuam '
                'no histórico da loja.\n\nDigite sua senha para confirmar:'),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(hintText: 'Senha'),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(passwordController.text),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    passwordController.dispose();

    if (password == null || password.isEmpty) return;

    await userManager.deleteAccount(
      password: password,
      onSuccess: () {
        if (context.mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
      onFail: (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Não foi possível excluir: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );
  }
}

/// Dono não exclui a conta: pede o encerramento da loja à plataforma, que
/// decide e pode recuperar/reatribuir a loja (ver TenantManager).
class _CloseStoreTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tenant = context.watch<TenantManager>();
    final requested = tenant.store?.closureRequested ?? false;

    if (!tenant.isOwner) return const SizedBox.shrink();
    if (requested) {
      return const ListTile(
        leading: Icon(Icons.hourglass_top, color: Colors.orange),
        title: Text('Encerramento solicitado'),
        subtitle: Text('A plataforma vai entrar em contato com você.'),
      );
    }
    return ListTile(
      leading: const Icon(Icons.store_mall_directory, color: Colors.red),
      title: const Text('Encerrar loja', style: TextStyle(color: Colors.red)),
      subtitle: const Text('Pede à plataforma o encerramento do app e do site'),
      onTap: () => _confirm(context, tenant),
    );
  }

  Future<void> _confirm(BuildContext context, TenantManager tenant) async {
    final reasonController = TextEditingController();
    final String? reason = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Encerrar a loja?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('O pedido vai para a equipe da plataforma, que '
                'confirma com você antes de tirar a loja do ar. Seus dados '
                'e pedidos não são apagados na hora.'),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(hintText: 'Motivo (opcional)'),
              maxLines: 2,
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(c, reasonController.text.trim()),
              child: const Text('Solicitar encerramento',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    reasonController.dispose();
    if (reason == null) return;
    await tenant.requestStoreClosure(reason);
  }
}

/// Alerta de estoque baixo/esgotado por unidade (dono vê todas; equipe só
/// as suas). Toque abre o painel daquela unidade, com o pedido de reposição.
class _StockAlerts extends StatelessWidget {
  const _StockAlerts();

  @override
  Widget build(BuildContext context) {
    final products = context.watch<ProductManager>().allProducts;
    final stores = context.watch<StoresManager>();
    final locations = context.watch<UserManager>().allowedLocations(stores);

    final alerts = <Widget>[];
    for (final l in locations) {
      final count = products.where((p) => p.needsRestockAt(l.id!)).length;
      if (count == 0) continue;
      alerts.add(ListTile(
        dense: true,
        leading: const Icon(Icons.warning_amber, color: Colors.orange),
        title: Text('$count produto(s) com estoque baixo'
            '${stores.isMultiLocation ? ' · ${l.name}' : ''}'),
        subtitle: const Text('Toque para ver e pedir reposição'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).pushNamed('/stock', arguments: l.id),
      ));
    }
    if (alerts.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(children: alerts),
    );
  }
}
