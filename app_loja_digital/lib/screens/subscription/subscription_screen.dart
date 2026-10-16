import 'package:app_loja_digital/core/platform_contact.dart';
import 'package:app_loja_digital/screens/subscription/usage_card.dart';
import 'package:flutter/foundation.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_loja_digital/models/stores_manager.dart';
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
    final result =
        await tenant.paySubscription(method, period: tenant.selectedPeriod);
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
                      Text(
                          'Próxima mensalidade: '
                          '${Plan.money(sub.nextPrice(store.plan))}'
                          ' · ${store.plan.introLabel}',
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

              const SizedBox(height: 8),
              const UsageCard(),

              // ---- Pagar ----
              const SizedBox(height: 12),
              const Text('Como quer pagar',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              for (final period in BillingPeriod.values)
                RadioListTile<BillingPeriod>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: period,
                  groupValue: tenant.selectedPeriod,
                  onChanged: (p) => tenant.selectPeriod(p!),
                  title: Text(period.label),
                  secondary: Text(
                    Plan.money(sub.priceFor(store.plan, period)),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: period == BillingPeriod.monthly
                      ? null
                      : Text('${period.months} meses de uma vez'),
                ),
              const SizedBox(height: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  minimumSize: const Size.fromHeight(48),
                ),
                icon: const FaIcon(FontAwesomeIcons.whatsapp),
                label: Text('Quero o plano ${store.plan.name}: '
                    'falar com a Inforizz'),
                onPressed: () => launchUrl(
                  Uri.parse(PlatformContact.support(
                      'Olá, Inforizz! Quero este plano: *${store.plan.name}* '
                      '(${Plan.money(sub.priceFor(store.plan, tenant.selectedPeriod))}'
                      ' ${tenant.selectedPeriod.label.toLowerCase()}).\n'
                      'Loja: ${store.name} (${store.id})')),
                  mode: LaunchMode.externalApplication,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Enquanto o pagamento pelo app não é liberado, a assinatura '
                  'é feita pelo WhatsApp da Inforizz (Pix).',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
              if (kDebugMode)
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
              if (kDebugMode)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Pagamento simulado (só em desenvolvimento).',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),

              // ---- Taxa de serviço ----
              Card(
                child: SwitchListTile(
                  title: Text('Repassar a taxa de serviço '
                      '(${Plan.money(store.serviceFee.amount)}) ao cliente'),
                  subtitle: Text(
                    store.serviceFee.paidBy == ServiceFeePayer.customer
                        ? 'O cliente vê a taxa somada no total do pedido.'
                        : 'A loja absorve a taxa: ela é descontada do valor '
                            'que você recebe, junto com a tarifa do Mercado '
                            'Pago.',
                  ),
                  value: store.serviceFee.paidBy == ServiceFeePayer.customer,
                  onChanged: (v) => tenant.setServiceFeePayer(
                      v ? ServiceFeePayer.customer : ServiceFeePayer.store),
                ),
              ),

              TextButton.icon(
                icon: const Icon(Icons.description_outlined),
                label: const Text('Termos para Lojistas (planos, taxas e '
                    'limites de uso)'),
                onPressed: () =>
                    Navigator.of(context).pushNamed('/store_terms'),
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
                      plan.maxLocations > 1
                          ? Icons.store_mall_directory
                          : Icons.storefront,
                      color: primaryColor,
                    ),
                    title: Row(
                      children: <Widget>[
                        Flexible(child: Text(plan.name)),
                        if (plan.hasIntro) ...[
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
                    subtitle: Text('${plan.introLabel}\n${plan.description}'),
                    isThreeLine: true,
                    trailing: plan.id == store.planId
                        ? Icon(Icons.check_circle, color: primaryColor)
                        : TextButton(
                            // Não dá para cair num plano com menos lojas do
                            // que a empresa já tem cadastradas.
                            onPressed: context
                                        .watch<StoresManager>()
                                        .stores
                                        .length >
                                    plan.maxLocations
                                ? null
                                : () => tenant.changePlan(plan.id),
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
