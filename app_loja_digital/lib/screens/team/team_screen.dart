import 'package:app_loja_digital/models/staff_member.dart';
import 'package:app_loja_digital/models/store_account.dart';
import 'package:app_loja_digital/models/stores_manager.dart';
import 'package:app_loja_digital/models/tenant_manager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Equipe (somente donos): sócios com acesso total e funcionários com
/// permissões ligadas/desligadas por toggle e vínculo a unidades físicas.
class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  final _emailController = TextEditingController();

  /// 'admin' (sócio, acesso total), 'manager' ou 'employee'.
  String _role = 'employee';
  bool _busy = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _snack(String? error, String ok) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? ok),
        backgroundColor: error == null ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _add() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    setState(() => _busy = true);
    final error = await context.read<TenantManager>().addMemberByEmail(
          email,
          asMaster: _role == 'admin',
          role: _role == 'manager' ? StaffRole.manager : StaffRole.employee,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (error == null) _emailController.clear();
    _snack(error, _role == 'admin'
        ? 'Administrador adicionado!'
        : 'Adicionado! Toque na pessoa para ajustar permissões e unidades.');
  }

  Future<void> _remove(String uid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Remover da equipe?'),
        content: const Text('A pessoa continua com a conta de cliente, mas '
            'perde o acesso à administração.'),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child:
                  const Text('Remover', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final error = await context.read<TenantManager>().removeMember(uid);
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) _snack(error, '');
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
                child: Text('Somente o dono da loja gerencia a equipe.'));
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
                      const Text('Adicionar à equipe',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text(
                        'A pessoa precisa primeiro criar uma conta na loja '
                        'com este e-mail.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                            hintText: 'E-mail do funcionário'),
                        enabled: !_busy,
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: _role,
                        decoration: const InputDecoration(labelText: 'Papel'),
                        items: const [
                          DropdownMenuItem(
                              value: 'employee', child: Text('Funcionário')),
                          DropdownMenuItem(
                              value: 'manager', child: Text('Gerente')),
                          DropdownMenuItem(
                              value: 'admin',
                              child: Text('Administrador (sócio, acesso total)')),
                        ],
                        onChanged: (v) =>
                            setState(() => _role = v ?? 'employee'),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _busy ? null : _add,
                          child: const Text('Adicionar'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                  'Administradores (${store.masters.length}/'
                  '${StoreAccount.maxMasters})',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              for (final uid in store.masters)
                _MasterTile(
                  uid: uid,
                  isOwner: store.isOwner(uid),
                  onRemove: _busy ? null : () => _remove(uid),
                ),
              const SizedBox(height: 16),
              Text(
                  'Gerentes e funcionários (${tenant.staff.length}/'
                  '${store.plan.maxStaff})',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              if (tenant.staff.isEmpty)
                const Card(child: ListTile(title: Text('Nenhum funcionário.'))),
              for (final member in tenant.staff)
                Card(
                  child: ListTile(
                    leading: Icon(Icons.badge, color: primaryColor),
                    title: Text(member.name.isEmpty ? member.email : member.name),
                    subtitle: Text(_summary(context, member)),
                    isThreeLine: true,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => _StaffEditScreen(member))),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: _busy ? null : () => _remove(member.uid),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  String _summary(BuildContext context, StaffMember m) {
    final stores = context.read<StoresManager>();
    final where = m.locationIds.isEmpty
        ? 'Todas as unidades'
        : m.locationIds.map(stores.nameOf).join(', ');
    return '${m.role.label} · ${m.email}\n'
        '${m.perms.length} permissões · $where';
  }
}

class _MasterTile extends StatelessWidget {
  const _MasterTile(
      {required this.uid, required this.isOwner, required this.onRemove});

  final String uid;
  final bool isOwner;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
        builder: (_, snap) {
          final data = snap.data?.data();
          return ListTile(
            leading: Icon(Icons.admin_panel_settings,
                color: Theme.of(context).primaryColor),
            title: Text((data?['name'] ?? '...') as String),
            subtitle: Text(
                '${data?['email'] ?? ''}${isOwner ? '\nDono da loja' : ''}'),
            trailing: isOwner
                ? null
                : IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: onRemove,
                  ),
          );
        },
      ),
    );
  }
}

/// Toggles de permissão + unidades em que o funcionário trabalha.
class _StaffEditScreen extends StatefulWidget {
  const _StaffEditScreen(this.member);
  final StaffMember member;

  @override
  State<_StaffEditScreen> createState() => _StaffEditScreenState();
}

class _StaffEditScreenState extends State<_StaffEditScreen> {
  late final Set<Perm> _perms = Set.of(widget.member.perms);
  late final Set<String> _locations = Set.of(widget.member.locationIds);
  late StaffRole _role = widget.member.role;
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    final m = widget.member
      ..role = _role
      ..perms = _perms
      ..locationIds = _locations.toList();
    await context.read<TenantManager>().updateStaff(m);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final stores = context.watch<StoresManager>();
    final allLocations = _locations.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.member.name.isEmpty
            ? widget.member.email
            : widget.member.name),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: ListView(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: SegmentedButton<StaffRole>(
              segments: StaffRole.values
                  .map((r) => ButtonSegment(value: r, label: Text(r.label)))
                  .toList(),
              selected: {_role},
              onSelectionChanged: (s) => setState(() => _role = s.first),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('O que pode fazer',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          for (final p in Perm.values)
            SwitchListTile(
              title: Text(p.label),
              value: _perms.contains(p),
              onChanged: (v) =>
                  setState(() => v ? _perms.add(p) : _perms.remove(p)),
            ),
          if (stores.isMultiLocation) ...[
            const Divider(),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text('Unidades em que trabalha',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            CheckboxListTile(
              title: const Text('Todas as unidades'),
              value: allLocations,
              onChanged: (v) {
                if (v == true) setState(_locations.clear);
              },
            ),
            for (final l in stores.locations)
              CheckboxListTile(
                title: Text(l.name),
                subtitle: Text('${l.city}/${l.state}'),
                value: !allLocations && _locations.contains(l.id),
                onChanged: (v) => setState(
                    () => v == true ? _locations.add(l.id!) : _locations.remove(l.id)),
              ),
          ],
        ],
      ),
    );
  }
}
