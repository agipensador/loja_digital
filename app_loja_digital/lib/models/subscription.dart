import 'package:app_loja_digital/models/plan.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Situação da assinatura, SEMPRE calculada pelas datas — nunca gravada
/// "na mão". O job diário da Fase 3 apenas materializa `active=false`
/// quando o status calculado é suspended.
enum SubscriptionStatus { trial, active, overdue, suspended }

/// Assinatura da loja (campo `subscription` no doc stores/{storeId}).
class Subscription {
  Subscription({
    required this.startedAt,
    required this.trialEndsAt,
    this.paidUntil,
    this.lastPaymentAt,
    this.lastPaymentMethod = '',
  });

  /// Assinatura nova: começa hoje com 60 dias de trial.
  factory Subscription.startTrial() {
    final now = DateTime.now();
    return Subscription(
      startedAt: now,
      trialEndsAt: now.add(const Duration(days: PlatformBilling.trialDays)),
    );
  }

  factory Subscription.fromMap(Map<String, dynamic> map) {
    DateTime? date(dynamic v) => v is Timestamp ? v.toDate() : null;
    final started = date(map['startedAt']) ?? DateTime.now();
    return Subscription(
      startedAt: started,
      trialEndsAt: date(map['trialEndsAt']) ??
          started.add(const Duration(days: PlatformBilling.trialDays)),
      paidUntil: date(map['paidUntil']),
      lastPaymentAt: date(map['lastPaymentAt']),
      lastPaymentMethod: (map['lastPaymentMethod'] ?? '') as String,
    );
  }

  final DateTime startedAt;
  final DateTime trialEndsAt;
  DateTime? paidUntil;
  DateTime? lastPaymentAt;
  String lastPaymentMethod;

  /// Até quando a loja está coberta (trial ou pagamento).
  DateTime get coveredUntil {
    final paid = paidUntil;
    if (paid == null) return trialEndsAt;
    return paid.isAfter(trialEndsAt) ? paid : trialEndsAt;
  }

  SubscriptionStatus statusAt(DateTime now) {
    if (now.isBefore(trialEndsAt) &&
        (paidUntil == null || now.isAfter(paidUntil!))) {
      return SubscriptionStatus.trial;
    }
    if (now.isBefore(coveredUntil)) return SubscriptionStatus.active;
    final graceEnd =
        coveredUntil.add(const Duration(days: PlatformBilling.graceDays));
    if (now.isBefore(graceEnd)) return SubscriptionStatus.overdue;
    return SubscriptionStatus.suspended;
  }

  SubscriptionStatus get status => statusAt(DateTime.now());

  int get daysLeft {
    final diff = coveredUntil.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  /// Registra um pagamento (mock hoje; Mercado Pago depois): estende a
  /// cobertura a partir do fim atual (ou de hoje, se já venceu).
  void registerPayment(Plan plan, String method) {
    final now = DateTime.now();
    final base = coveredUntil.isAfter(now) ? coveredUntil : now;
    paidUntil = base.add(plan.cycleDuration);
    lastPaymentAt = now;
    lastPaymentMethod = method;
  }

  Map<String, dynamic> toMap() {
    return {
      'startedAt': Timestamp.fromDate(startedAt),
      'trialEndsAt': Timestamp.fromDate(trialEndsAt),
      'paidUntil': paidUntil == null ? null : Timestamp.fromDate(paidUntil!),
      'lastPaymentAt':
          lastPaymentAt == null ? null : Timestamp.fromDate(lastPaymentAt!),
      'lastPaymentMethod': lastPaymentMethod,
    };
  }

  static String statusLabel(SubscriptionStatus s) {
    switch (s) {
      case SubscriptionStatus.trial:
        return 'Período gratuito';
      case SubscriptionStatus.active:
        return 'Ativa';
      case SubscriptionStatus.overdue:
        return 'Pagamento pendente';
      case SubscriptionStatus.suspended:
        return 'Suspensa';
    }
  }
}
