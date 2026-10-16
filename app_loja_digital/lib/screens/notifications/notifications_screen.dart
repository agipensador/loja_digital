import 'package:app_loja_digital/models/campaign.dart';
import 'package:app_loja_digital/models/staff_member.dart';
import 'package:app_loja_digital/models/user_manager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Caixa de notificações: avisos da loja para todos e, para a equipe da
/// loja, também os avisos da plataforma (Inforizz).
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  static String _when(Timestamp? t) => t == null
      ? ''
      : DateFormat("dd/MM 'às' HH:mm", 'pt_BR').format(t.toDate());

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserManager>();
    final canSend = user.can(Perm.notifications);

    return DefaultTabController(
      length: user.adminEnabled ? 2 : 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Notificações'),
          bottom: user.adminEnabled
              ? const TabBar(
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  indicatorColor: Colors.white,
                  tabs: [
                  Tab(text: 'Da loja'),
                  Tab(text: 'Da plataforma'),
                ])
              : null,
        ),
        floatingActionButton: canSend
            ? FloatingActionButton.extended(
                icon: const Icon(Icons.campaign),
                label: const Text('Enviar aviso'),
                onPressed: () =>
                    Navigator.of(context).pushNamed('/compose_campaign'),
              )
            : null,
        body: TabBarView(
          children: <Widget>[
            StreamBuilder<List<Campaign>>(
              stream: Campaign.recent(),
              builder: (_, snap) => _List(
                empty: 'Nenhuma notificação da loja ainda.',
                items: [
                  for (final c in snap.data ?? const <Campaign>[])
                    (c.title, c.body, _when(c.createdAt), Icons.storefront),
                ],
              ),
            ),
            if (user.adminEnabled)
              StreamBuilder<List<PlatformAnnouncement>>(
                stream: PlatformAnnouncement.recent(),
                builder: (_, snap) => _List(
                  empty: 'Nenhum aviso da plataforma.',
                  items: [
                    for (final a in snap.data ?? const <PlatformAnnouncement>[])
                      (a.title, a.body, _when(a.createdAt), Icons.campaign),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.items, required this.empty});

  final List<(String, String, String, IconData)> items;
  final String empty;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return Center(child: Text(empty));
    final primary = Theme.of(context).primaryColor;
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final (title, body, sentAt, icon) = items[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: primary.withAlpha(30),
            child: Icon(icon, color: primary),
          ),
          title: Text(title,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('$body\n$sentAt'),
          isThreeLine: true,
        );
      },
    );
  }
}
