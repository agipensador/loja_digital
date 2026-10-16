import 'package:app_loja_digital/helpers/br_format.dart';
import 'package:app_loja_digital/models/plan.dart';
import 'package:app_loja_digital/models/store_account.dart';
import 'package:app_loja_digital/models/subscription.dart';
import 'package:app_loja_digital/services/usage_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Painel da plataforma: indicadores, lojas (plano, situação, uso), nova
/// loja, produtos de cada loja, usuários, encerramentos e avisos.
class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  static final _db = FirebaseFirestore.instance;
  static final _int = NumberFormat.decimalPattern('pt_BR');

  static void toast(BuildContext context, String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: error ? Colors.red : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Inforizz: painel da plataforma'),
          actions: <Widget>[
            IconButton(
              tooltip: 'Sair',
              icon: const Icon(Icons.logout),
              onPressed: FirebaseAuth.instance.signOut,
            ),
          ],
          bottom: const TabBar(isScrollable: true, tabs: [
            Tab(icon: Icon(Icons.dashboard), text: 'Lojas'),
            Tab(icon: Icon(Icons.people), text: 'Usuários'),
            Tab(icon: Icon(Icons.store_mall_directory), text: 'Encerramentos'),
            Tab(icon: Icon(Icons.campaign), text: 'Avisos'),
          ]),
        ),
        body: const TabBarView(children: [
          _StoresTab(),
          _UsersTab(),
          _ClosuresTab(),
          _AnnouncementsTab(),
        ]),
      ),
    );
  }
}

// =========================== Lojas ===========================

class _StoresTab extends StatelessWidget {
  const _StoresTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_business),
        label: const Text('Nova loja'),
        onPressed: () => showDialog<void>(
            context: context, builder: (_) => const _NewStoreDialog()),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: AdminDashboard._db.collection('stores').snapshots(),
        builder: (_, snap) {
          if (snap.hasError) {
            return Center(child: Text('Erro ao ler as lojas: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final stores = snap.data!.docs.map(StoreAccount.fromDocument).toList()
            ..sort((a, b) => a.name.compareTo(b.name));
          int count(SubscriptionStatus s) =>
              stores.where((x) => x.active && x.subscription.status == s).length;
          final mrr = stores
              .where((s) =>
                  s.active && s.subscription.status == SubscriptionStatus.active)
              .fold<num>(0, (t, s) => t + s.plan.price);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            children: <Widget>[
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  _Kpi('Lojas', '${stores.length}', Icons.storefront),
                  _Kpi('Período grátis', '${count(SubscriptionStatus.trial)}',
                      Icons.card_giftcard),
                  _Kpi('Pagantes', '${count(SubscriptionStatus.active)}',
                      Icons.verified),
                  _Kpi('Em atraso', '${count(SubscriptionStatus.overdue)}',
                      Icons.warning_amber),
                  _Kpi('Suspensas', '${count(SubscriptionStatus.suspended)}',
                      Icons.block),
                  _Kpi('Desativadas', '${stores.where((s) => !s.active).length}',
                      Icons.power_settings_new),
                  _Kpi('Receita mensal (pagantes)', Br.money(mrr),
                      Icons.payments),
                ],
              ),
              const SizedBox(height: 24),
              Card(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Loja')),
                      DataColumn(label: Text('Plano')),
                      DataColumn(label: Text('Situação')),
                      DataColumn(label: Text('Vence em')),
                      DataColumn(label: Text('Visitas (mês)')),
                      DataColumn(label: Text('Produtos')),
                      DataColumn(label: Text('Ações')),
                    ],
                    rows: [for (final s in stores) _row(context, s)],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  DataRow _row(BuildContext context, StoreAccount s) {
    final ref = AdminDashboard._db.collection('stores').doc(s.id);
    final sub = s.subscription;
    final pendingOwner = s.masters.isEmpty;
    return DataRow(cells: [
      DataCell(Text('${s.name}\n${s.id}${pendingOwner ? ' · aguardando dono' : ''}')),
      DataCell(Text(s.plan.name)),
      DataCell(Text(s.active
          ? Subscription.statusLabel(sub.status)
          : 'Desativada')),
      DataCell(Text(DateFormat('dd/MM/yyyy').format(sub.coveredUntil))),
      DataCell(FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: ref
            .collection('stats')
            .doc(UsageService.monthKey(DateTime.now()))
            .get(),
        builder: (_, v) => Text(AdminDashboard._int
            .format(((v.data?.data()?['visits'] ?? 0) as num).toInt())),
      )),
      DataCell(FutureBuilder<AggregateQuerySnapshot>(
        future: ref
            .collection('products')
            .where('deleted', isEqualTo: false)
            .count()
            .get(),
        builder: (_, c) => Text('${c.data?.count ?? '…'}'),
      )),
      DataCell(Row(children: [
        IconButton(
          tooltip: 'Produtos da loja',
          icon: const Icon(Icons.inventory_2_outlined),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => _StoreProductsPage(s.id, s.name))),
        ),
        PopupMenuButton<String>(
          tooltip: 'Mais ações',
          onSelected: (action) => _act(context, s, action),
          itemBuilder: (_) => [
            for (final p in PlanCatalog.all)
              if (p.id != s.planId)
                PopupMenuItem(
                    value: 'plan:${p.id}',
                    child: Text('Mudar para ${p.name}')),
            const PopupMenuItem(
                value: 'trial30', child: Text('Estender grátis +30 dias')),
            const PopupMenuItem(
                value: 'paid30', child: Text('Registrar pagamento (+1 mês)')),
            PopupMenuItem(
                value: 'toggle',
                child: Text(s.active ? 'Desativar loja' : 'Reativar loja')),
          ],
        ),
      ])),
    ]);
  }

  Future<void> _act(
      BuildContext context, StoreAccount s, String action) async {
    final ref = AdminDashboard._db.collection('stores').doc(s.id);
    try {
      if (action.startsWith('plan:')) {
        await ref.update({'plan': action.substring(5)});
      } else if (action == 'trial30') {
        final ends = s.subscription.trialEndsAt.add(const Duration(days: 30));
        await ref
            .update({'subscription.trialEndsAt': Timestamp.fromDate(ends)});
      } else if (action == 'paid30') {
        // Pagamento recebido fora do app (Pix pelo WhatsApp).
        s.subscription.registerPayment(s.plan, 'pix');
        await ref.update({'subscription': s.subscription.toMap()});
      } else if (action == 'toggle') {
        await ref.update({'active': !s.active});
      }
      if (context.mounted) {
        AdminDashboard.toast(context, '${s.name}: alteração salva.');
      }
    } catch (e) {
      if (context.mounted) {
        AdminDashboard.toast(context, 'Falha: $e', error: true);
      }
    }
  }
}

/// Cria a loja como o tool/provision_store.js: 3 meses grátis e o dono
/// assume ao entrar no app com o e-mail informado.
class _NewStoreDialog extends StatefulWidget {
  const _NewStoreDialog();

  @override
  State<_NewStoreDialog> createState() => _NewStoreDialogState();
}

class _NewStoreDialogState extends State<_NewStoreDialog> {
  final _id = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  String _plan = PlanCatalog.unica.id;
  String? _error;
  bool _saving = false;

  Future<void> _create() async {
    final id = _id.text.trim();
    final name = _name.text.trim();
    final email = _email.text.trim().toLowerCase();
    if (!RegExp(r'^[a-z][a-z0-9_]{2,30}$').hasMatch(id)) {
      setState(() => _error =
          'Id: letras minúsculas, números e _ (ex.: loja_da_ju).');
      return;
    }
    if (name.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Informe o nome e o e-mail do dono.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final ref = AdminDashboard._db.collection('stores').doc(id);
    try {
      if ((await ref.get()).exists) {
        setState(() {
          _saving = false;
          _error = 'Já existe uma loja com o id $id.';
        });
        return;
      }
      final now = DateTime.now();
      await ref.set({
        'name': name,
        'slug': id,
        'active': true,
        'ownerUid': '',
        'masters': <String>[],
        'pendingOwnerEmail': email,
        'plan': _plan,
        'subscription': {
          'startedAt': Timestamp.fromDate(now),
          'trialEndsAt': Timestamp.fromDate(
              now.add(const Duration(days: PlatformBilling.trialDays))),
          'paidUntil': null,
          'lastPaymentAt': null,
          'lastPaymentMethod': '',
          'paidCycles': 0,
        },
        'serviceFee': {'amount': PlatformBilling.serviceFee, 'paidBy': 'store'},
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      Navigator.pop(context);
      AdminDashboard.toast(context,
          'Loja $name criada. O dono entra no app com $email para assumir.');
    } catch (e) {
      setState(() {
        _saving = false;
        _error = 'Falha: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nova loja'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nome da loja'),
              onChanged: (v) {
                if (_id.text.isEmpty || _id.text == _slug(v.substring(0, v.isEmpty ? 0 : v.length - 1))) {
                  _id.text = _slug(v);
                }
              },
            ),
            TextField(
              controller: _id,
              decoration: const InputDecoration(
                  labelText: 'Id da loja (STORE_ID do app)',
                  hintText: 'loja_da_ju'),
            ),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration:
                  const InputDecoration(labelText: 'E-mail do dono'),
            ),
            DropdownButtonFormField<String>(
              initialValue: _plan,
              decoration: const InputDecoration(labelText: 'Plano'),
              items: [
                for (final p in PlanCatalog.all)
                  DropdownMenuItem(
                      value: p.id,
                      child: Text('${p.name} (${Br.money(p.price)})')),
              ],
              onChanged: (v) => setState(() => _plan = v!),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        FilledButton(
            onPressed: _saving ? null : _create,
            child: Text(_saving ? 'Criando...' : 'Criar loja')),
      ],
    );
  }

  static String _slug(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[áàâã]'), 'a')
      .replaceAll(RegExp('[éê]'), 'e')
      .replaceAll('í', 'i')
      .replaceAll(RegExp('[óôõ]'), 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp('[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
}

/// Produtos de uma loja: busca, editar nome/preço/estoque, ocultar.
class _StoreProductsPage extends StatefulWidget {
  const _StoreProductsPage(this.storeId, this.storeName);
  final String storeId;
  final String storeName;

  @override
  State<_StoreProductsPage> createState() => _StoreProductsPageState();
}

class _StoreProductsPageState extends State<_StoreProductsPage> {
  String _query = '';
  bool _showHidden = false;

  CollectionReference<Map<String, dynamic>> get _col => AdminDashboard._db
      .collection('stores')
      .doc(widget.storeId)
      .collection('products');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Produtos: ${widget.storeName}')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Buscar por nome ou categoria'),
                  onChanged: (v) => setState(() => _query = v.toLowerCase()),
                ),
              ),
              const SizedBox(width: 12),
              FilterChip(
                label: const Text('Mostrar ocultos'),
                selected: _showHidden,
                onSelected: (v) => setState(() => _showHidden = v),
              ),
            ]),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _col.snapshots(),
              builder: (_, snap) {
                if (snap.hasError) {
                  return Center(child: Text('Erro: ${snap.error}'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data!.docs.where((d) {
                  final data = d.data();
                  if (!_showHidden && data['deleted'] == true) return false;
                  final text =
                      '${data['name'] ?? ''} ${data['category'] ?? ''}'.toLowerCase();
                  return text.contains(_query);
                }).toList()
                  ..sort((a, b) =>
                      '${a['name']}'.compareTo('${b['name']}'));
                if (docs.isEmpty) {
                  return const Center(child: Text('Nenhum produto.'));
                }
                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final d = docs[i];
                    final data = d.data();
                    final sizes = (data['sizes'] as List? ?? []).cast<Map>();
                    final stock = sizes.fold<int>(0, (t, s) {
                      final byLoc = (s['stockByLocation'] as Map?) ?? {};
                      return t +
                          byLoc.values.fold<int>(0, (a, b) => a + (b as num).toInt()) +
                          ((s['stock'] as num?)?.toInt() ?? 0);
                    });
                    final prices = sizes
                        .map((s) => Br.money((s['price'] as num?) ?? 0))
                        .toSet()
                        .join(' · ');
                    final hidden = data['deleted'] == true;
                    return ListTile(
                      leading: Icon(hidden
                          ? Icons.visibility_off
                          : Icons.inventory_2_outlined),
                      title: Text('${data['name']}'),
                      subtitle: Text(
                          '${data['category'] ?? ''} · $prices · estoque $stock'),
                      trailing: Wrap(children: [
                        IconButton(
                          tooltip: 'Editar',
                          icon: const Icon(Icons.edit),
                          onPressed: () => showDialog<void>(
                            context: context,
                            builder: (_) => _EditProductDialog(d.reference, data),
                          ),
                        ),
                        IconButton(
                          tooltip: hidden ? 'Mostrar na loja' : 'Ocultar da loja',
                          icon: Icon(hidden ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => d.reference.update({
                            'deleted': !hidden,
                            'updatedAt': FieldValue.serverTimestamp(),
                          }),
                        ),
                      ]),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EditProductDialog extends StatefulWidget {
  const _EditProductDialog(this.ref, this.data);
  final DocumentReference<Map<String, dynamic>> ref;
  final Map<String, dynamic> data;

  @override
  State<_EditProductDialog> createState() => _EditProductDialogState();
}

class _EditProductDialogState extends State<_EditProductDialog> {
  late final _name = TextEditingController(text: '${widget.data['name'] ?? ''}');
  late final List<Map<String, dynamic>> _sizes = [
    for (final s in (widget.data['sizes'] as List? ?? []))
      Map<String, dynamic>.from(s as Map),
  ];
  late final List<TextEditingController> _prices = [
    for (final s in _sizes)
      TextEditingController(
          text: Br.moneyInput((s['price'] as num?) ?? 0)),
  ];
  late final List<Map<String, TextEditingController>> _stocks = [
    for (final s in _sizes)
      {
        for (final e in ((s['stockByLocation'] as Map?) ??
                {'principal': s['stock'] ?? 0})
            .entries)
          '${e.key}': TextEditingController(text: '${e.value}'),
      },
  ];
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    for (var i = 0; i < _sizes.length; i++) {
      _sizes[i]['price'] = Br.parseMoney(_prices[i].text);
      _sizes[i]['stockByLocation'] = {
        for (final e in _stocks[i].entries)
          e.key: int.tryParse(Br.digits(e.value.text)) ?? 0,
      };
      _sizes[i].remove('stock');
    }
    try {
      await widget.ref.update({
        'name': _name.text.trim(),
        'sizes': _sizes,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) AdminDashboard.toast(context, 'Falha: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar produto'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Nome')),
              const SizedBox(height: 12),
              for (var i = 0; i < _sizes.length; i++) ...[
                Text('Variante: ${_sizes[i]['name']}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Wrap(spacing: 12, children: [
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: _prices[i],
                      decoration: const InputDecoration(labelText: 'Preço (R\$)'),
                    ),
                  ),
                  for (final e in _stocks[i].entries)
                    SizedBox(
                      width: 120,
                      child: TextField(
                        controller: e.value,
                        keyboardType: TextInputType.number,
                        decoration:
                            InputDecoration(labelText: 'Estoque ${e.key}'),
                      ),
                    ),
                ]),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        FilledButton(
            onPressed: _saving ? null : _save, child: const Text('Salvar')),
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 190,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, color: scheme.primary),
              const SizedBox(height: 8),
              Text(value,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold)),
              Text(label, style: TextStyle(color: scheme.outline)),
            ],
          ),
        ),
      ),
    );
  }
}

// =========================== Usuários ===========================

class _UsersTab extends StatefulWidget {
  const _UsersTab();

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  String _email = '';

  Query<Map<String, dynamic>> get _query {
    final col = AdminDashboard._db.collection('users');
    final q = _email.trim().toLowerCase();
    if (q.isEmpty) return col.orderBy('email').limit(100);
    return col
        .orderBy('email')
        .startAt([q])
        .endAt(['$q'])
        .limit(100);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Buscar pelo início do e-mail',
            ),
            onChanged: (v) => setState(() => _email = v),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _query.snapshots(),
            builder: (_, snap) {
              if (snap.hasError) {
                return Center(child: Text('Erro: ${snap.error}'));
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data!.docs;
              if (docs.isEmpty) {
                return const Center(child: Text('Nenhum usuário encontrado.'));
              }
              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final d = docs[i];
                  final data = d.data();
                  final blocked = data['blocked'] == true;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: blocked ? Colors.red.shade100 : null,
                      child: Icon(blocked ? Icons.block : Icons.person),
                    ),
                    title: Text('${data['name'] ?? '(sem nome)'}'),
                    subtitle: Text(
                        '${data['email'] ?? ''} · loja ${data['storeId'] ?? '—'}'),
                    trailing: TextButton.icon(
                      icon: Icon(blocked ? Icons.lock_open : Icons.block),
                      label: Text(blocked ? 'Desbloquear' : 'Bloquear'),
                      onPressed: () async {
                        try {
                          await d.reference.update({'blocked': !blocked});
                        } catch (e) {
                          if (context.mounted) {
                            AdminDashboard.toast(context, 'Falha: $e',
                                error: true);
                          }
                        }
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// =========================== Encerramentos ===========================

class _ClosuresTab extends StatelessWidget {
  const _ClosuresTab();

  @override
  Widget build(BuildContext context) {
    final col = AdminDashboard._db
        .collection('platform')
        .doc('closureRequests')
        .collection('requests');
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: col.where('status', isEqualTo: 'pending').snapshots(),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('Nenhum pedido de encerramento.'));
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final d in docs)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.store_mall_directory),
                  title: Text('${d['storeName']} (${d['storeId']})'),
                  subtitle: Text('Motivo: ${d.data()['reason'] ?? '—'}'),
                  trailing: Wrap(spacing: 8, children: [
                    OutlinedButton(
                      onPressed: () async {
                        await d.reference.update({'status': 'kept'});
                        await AdminDashboard._db
                            .collection('stores')
                            .doc(d['storeId'] as String)
                            .update({'closureRequested': false});
                      },
                      child: const Text('Recuperada'),
                    ),
                    FilledButton(
                      onPressed: () async {
                        await AdminDashboard._db
                            .collection('stores')
                            .doc(d['storeId'] as String)
                            .update({'active': false});
                        await d.reference.update({'status': 'closed'});
                      },
                      child: const Text('Encerrar'),
                    ),
                  ]),
                ),
              ),
          ],
        );
      },
    );
  }
}

// =========================== Avisos ===========================

class _AnnouncementsTab extends StatefulWidget {
  const _AnnouncementsTab();

  @override
  State<_AnnouncementsTab> createState() => _AnnouncementsTabState();
}

class _AnnouncementsTabState extends State<_AnnouncementsTab> {
  final _title = TextEditingController();
  final _body = TextEditingController();

  CollectionReference<Map<String, dynamic>> get _col => AdminDashboard._db
      .collection('platform')
      .doc('announcements')
      .collection('items');

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    if (_title.text.trim().isEmpty) return;
    await _col.add({
      'title': _title.text.trim(),
      'body': _body.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    _title.clear();
    _body.clear();
    if (mounted) AdminDashboard.toast(context, 'Aviso publicado para os lojistas.');
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const Text('Aviso para todos os lojistas',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Título')),
        TextField(
            controller: _body,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Mensagem')),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            icon: const Icon(Icons.send),
            label: const Text('Publicar'),
            onPressed: _publish,
          ),
        ),
        const Divider(height: 32),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _col.orderBy('createdAt', descending: true).snapshots(),
          builder: (_, snap) => Column(children: [
            for (final d in snap.data?.docs ?? [])
              ListTile(
                leading: const Icon(Icons.campaign),
                title: Text('${d['title']}'),
                subtitle: Text('${d['body']}'),
              ),
          ]),
        ),
      ],
    );
  }
}
