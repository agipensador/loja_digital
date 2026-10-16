import 'package:app_loja_digital/models/campaign.dart';
import 'package:app_loja_digital/models/staff_member.dart';
import 'package:app_loja_digital/models/tenant_manager.dart';
import 'package:app_loja_digital/models/user_manager.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Sugestão de aviso aos clientes depois de uma ação da equipe
/// (produto novo, produto de volta ao estoque, nova unidade, nova área de
/// entrega, app atualizado...). "Sim" envia na hora, dentro da cota do
/// plano; "Editar" abre a tela de aviso com o texto pronto.
class NotifyPrompt {
  NotifyPrompt._();

  /// Mostra só para quem tem a permissão de enviar avisos.
  static Future<void> ask(
    BuildContext context, {
    required String question,
    required String title,
    required String body,
  }) async {
    final user = context.read<UserManager>();
    if (!user.can(Perm.notifications)) return;
    final quota = context.read<TenantManager>().store?.plan.maxCampaigns ?? 0;
    int used;
    try {
      used = await Campaign.countThisMonth();
    } catch (_) {
      used = 0;
    }
    if (!context.mounted) return;
    final left = quota - used;

    final choice = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        icon: const Icon(Icons.campaign),
        title: Text(question),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Card(
              child: ListTile(
                leading: const Icon(Icons.notifications),
                title: Text(title),
                subtitle: Text(body),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              left > 0
                  ? 'Restam $left de $quota avisos este mês.'
                  : 'A cota de avisos deste mês acabou ($quota).',
              style: TextStyle(
                  fontSize: 12, color: left > 0 ? Colors.grey : Colors.red),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialog, 'no'),
            child: const Text('Não'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, 'edit'),
            child: const Text('Editar'),
          ),
          FilledButton(
            onPressed: left > 0 ? () => Navigator.pop(dialog, 'yes') : null,
            child: const Text('Sim, enviar'),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    if (choice == 'edit') {
      await Navigator.of(context).pushNamed('/compose_campaign',
          arguments: Campaign(title: title, body: body));
    } else if (choice == 'yes') {
      await Campaign(title: title, body: body).send(user.user?.id ?? '');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Aviso enviado aos clientes!'),
        backgroundColor: Colors.green,
      ));
    }
  }
}
