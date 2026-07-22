import 'package:app_loja_digital/models/plan.dart';
import 'package:app_loja_digital/models/subscription.dart';
import 'package:app_loja_digital/models/tenant_manager.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Assinatura da loja (somente admin-master): plano atual, período gratuito,
/// troca de plano e pagamento (simulado por enquanto — Mercado Pago depois).
class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  Color _statusColor(SubscriptionStatus s) {
    switch (s) {
      case SubscriptionStatus.trial:
        return Colors.blue;
      case SubscriptionStatus.active:
        return Colors.green;
      case SubscriptionStatus.overdue:
        return Colors.orange;
      case SubscriptionStatus.suspended:
        return Colors.red;
    }
  }

  Future<void> _pay(BuildContext context, String method) async {
    final tenant = context.read<TenantManager>();
    final result = await tenant.paySubscription(method);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.approved
            ? 'Pagamento aprovado! Assinatura renovada.'
            : 'Pagamento não aprovado: ${result.message ?? ''}'),
        backgroundColor: result.approved ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(title: const Text('Assinatura'), centerTitle: true),
      body: Consumer<TenantManager>(
        builder: (_, tenant, __) {
          final store = tenant.store;
          if (store == null) {
            return const Center(
                child: Text('Loja ainda não configurada neste ambiente.'));
          }
          if (!tenant.isMaster) {
            return const Center(
                child: Text('Somente o admin-master vê a assinatura.'));
          }

          final sub = store.subscription;
          final status = sub.status;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              // ---- Situação atual ----
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(Icons.workspace_premium, color: primaryColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(store.plan.name,
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                          ),
                          Chip(
                            label: Text(
                              Subscription.statusLabel(status),
                              style: const TextStyle(color: Colors.white),
                            ),
                            backgroundColor: _statusColor(status),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(store.plan.priceLabel,
                          style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      if (status == SubscriptionStatus.trial)
                        Text('Período gratuito: faltam ${sub.daysLeft} dias. '
                            'Depois disso a mensalidade passa a ser cobrada.')
                      else if (status == SubscriptionStatus.active)
                        Text('Assinatura em dia. Cobertura até '
                            '${_fmt(sub.coveredUntil)}.')
                      else if (status == SubscriptionStatus.overdue)
                        Text('Pagamento pendente! A loja sai do ar em até '
                            '${PlatformBilling.graceDays} dias após o '
                            'vencimento (${_fmt(sub.coveredUntil)}).')
                      else
                        const Text(
                            'Assinatura vencida: a loja está suspensa. '
                            'Pague para reativar imediatamente.'),
                    ],
                  ),
                ),
              ),

              // ---- Pagar ----
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.pix),
                      label: const Text('Pagar com Pix'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      onPressed:
                          tenant.loading ? null : () => _pay(context, 'pix'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.credit_card),
                      label: const Text('Pagar no crédito'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: tenant.loading
                          ? null
                          : () => _pay(context, 'credit'),
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Pagamento simulado nesta fase — o Mercado Pago (Pix e '
                  'cartão de verdade) entra com o backend.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),

              // ---- Planos ----
              const SizedBox(height: 8),
              const Text('Planos disponíveis',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              for (final plan in PlanCatalog.all)
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: plan.id == store.planId
                        ? BorderSide(color: primaryColor, width: 2)
                        : BorderSide.none,
                  ),
                  child: ListTile(
                    leading: Icon(
                      plan.includesApp
                          ? Icons.smartphone
                          : Icons.language,
                      color: primaryColor,
                    ),
                    title: Row(
                      children: <Widget>[
                        Flexible(child: Text(plan.name)),
                        if (plan.promo) ...[
                          const SizedBox(width: 6),
                          const Chip(
                            label: Text('PROMO',
                                style: TextStyle(
                                    fontSize: 10, color: Colors.white)),
                            backgroundColor: Colors.deepOrange,
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text('${plan.priceLabel}\n${plan.description}'),
                    isThreeLine: true,
                    trailing: plan.id == store.planId
                        ? Icon(Icons.check_circle, color: primaryColor)
                        : TextButton(
                            onPressed: () async {
                              await tenant.changePlan(plan.id);
                            },
                            child: const Text('Escolher'),
                          ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
}
