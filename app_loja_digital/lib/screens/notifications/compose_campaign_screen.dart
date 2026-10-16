import 'package:app_loja_digital/models/campaign.dart';
import 'package:app_loja_digital/models/tenant_manager.dart';
import 'package:app_loja_digital/models/user_manager.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// A loja escreve um aviso para todos os clientes (promoção, novidade,
/// horário especial), dentro da cota mensal do plano.
class ComposeCampaignScreen extends StatefulWidget {
  const ComposeCampaignScreen({super.key, this.draft});

  /// Texto sugerido (ex.: "Novos produtos na loja").
  final Campaign? draft;

  @override
  State<ComposeCampaignScreen> createState() => _ComposeCampaignScreenState();
}

class _ComposeCampaignScreenState extends State<ComposeCampaignScreen> {
  late final _title = TextEditingController(text: widget.draft?.title);
  late final _body = TextEditingController(text: widget.draft?.body);
  late final Future<int> _used = Campaign.countThisMonth();
  bool _sending = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) return;
    setState(() => _sending = true);
    final uid = context.read<UserManager>().user?.id ?? '';
    await Campaign(title: _title.text.trim(), body: _body.text.trim())
        .send(uid);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Aviso enviado aos clientes!'),
        backgroundColor: Colors.green));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final quota = context.watch<TenantManager>().store?.plan.maxCampaigns ?? 0;
    final primary = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(title: const Text('Enviar aviso aos clientes')),
      body: FutureBuilder<int>(
        future: _used,
        builder: (_, snap) {
          final used = snap.data ?? 0;
          final left = quota - used;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Text(
                snap.hasData
                    ? 'Você usou $used de $quota avisos este mês.'
                    : 'Verificando sua cota...',
                style: TextStyle(
                    color: left > 0 ? Colors.grey : Colors.red,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _title,
                maxLength: 50,
                decoration: const InputDecoration(
                    labelText: 'Título', hintText: 'Ex.: Promoção de sábado'),
                onChanged: (_) => setState(() {}),
              ),
              TextField(
                controller: _body,
                maxLength: 180,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'Mensagem',
                    hintText: 'Ex.: 20% em todos os anéis até domingo!'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              const Text('Prévia', style: TextStyle(color: Colors.grey)),
              Card(
                child: ListTile(
                  leading: Icon(Icons.notifications, color: primary),
                  title: Text(_title.text.isEmpty ? 'Título' : _title.text),
                  subtitle:
                      Text(_body.text.isEmpty ? 'Mensagem' : _body.text),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: primary, foregroundColor: Colors.white),
                icon: const Icon(Icons.send),
                label: const Text('Enviar para todos os clientes'),
                onPressed: !snap.hasData || left <= 0 || _sending ? null : _send,
              ),
              if (snap.hasData && left <= 0)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Cota do mês esgotada. Ela renova no dia 1º, ou mude de '
                    'plano para enviar mais.',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(height: 12),
              const Text(
                'O aviso aparece em "Notificações" no app. A notificação no '
                'celular (push) é ativada junto com o backend da loja.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          );
        },
      ),
    );
  }
}
