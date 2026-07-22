import 'package:app_loja_digital/models/store_account.dart';
import 'package:app_loja_digital/models/tenant_manager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Equipe da loja (somente admin-master): até 3 admins-master e 5 admins.
/// O membro precisa já ter conta criada NESTA loja (busca por e-mail).
class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  final _emailController = TextEditingController();
  String _role = 'admin';
  bool _busy = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    setState(() => _busy = true);
    final error = await context
        .read<TenantManager>()
        .addMemberByEmail(email, _role);
    if (!mounted) return;
    setState(() => _busy = false);
    if (error == null) _emailController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'Membro adicionado!'),
        backgroundColor: error == null ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _remove(String uid) async {
    setState(() => _busy = true);
    final error = await context.read<TenantManager>().removeMember(uid);
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(title: const Text('Equipe da loja'), centerTitle: true),
      body: Consumer<TenantManager>(
        builder: (_, tenant, __) {
          final store = tenant.store;
          if (store == null || !tenant.isMaster) {
            return const Center(
                child: Text('Somente o admin-master gerencia a equipe.'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text('Adicionar membro',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          hintText: 'E-mail do usuário (já cadastrado na loja)',
                        ),
                        enabled: !_busy,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: DropdownButton<String>(
                              value: _role,
                              isExpanded: true,
                              items: const [
                                DropdownMenuItem(
                                    value: 'admin',
                                    child: Text('Admin (produtos e home)')),
                                DropdownMenuItem(
                                    value: 'master',
                                    child: Text('Admin-master (tudo)')),
                              ],
                              onChanged: (v) =>
                                  setState(() => _role = v ?? 'admin'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _busy ? null : _add,
                            child: const Text('Adicionar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _MemberList(
                title:
                    'Admins-master (${store.masters.length}/${StoreAccount.maxMasters})',
                uids: store.masters,
                icon: Icons.admin_panel_settings,
                onRemove: _busy ? null : _remove,
              ),
              const SizedBox(height: 16),
              _MemberList(
                title:
                    'Admins (${store.admins.length}/${StoreAccount.maxAdmins})',
                uids: store.admins,
                icon: Icons.badge,
                onRemove: _busy ? null : _remove,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Lista membros resolvendo nome/e-mail em users/{uid}.
class _MemberList extends StatelessWidget {
  const _MemberList({
    required this.title,
    required this.uids,
    required this.icon,
    required this.onRemove,
  });

  final String title;
  final List<String> uids;
  final IconData icon;
  final Future<void> Function(String uid)? onRemove;

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        if (uids.isEmpty)
          const Card(
            child: ListTile(title: Text('Nenhum membro.')),
          ),
        for (final uid in uids)
          Card(
            child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .get(),
              builder: (_, snap) {
                final data = snap.data?.data();
                final name = (data?['name'] ?? '...') as String;
                final email = (data?['email'] ?? '') as String;
                return ListTile(
                  leading: Icon(icon, color: primaryColor),
                  title: Text(name),
                  subtitle: Text(email),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed:
                        onRemove == null ? null : () => onRemove!(uid),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
