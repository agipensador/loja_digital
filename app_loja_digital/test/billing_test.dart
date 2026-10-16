import 'package:app_loja_digital/models/order.dart';
import 'package:app_loja_digital/models/plan.dart';
import 'package:app_loja_digital/models/subscription.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Subscription (trial 3 meses + carência 5d)', () {
    test('loja nova fica em trial por 90 dias', () {
      final sub = Subscription.startTrial();
      expect(sub.status, SubscriptionStatus.trial);
      expect(sub.daysLeft, inInclusiveRange(89, 90));
    });

    test('trial vencido sem pagamento entra em carência (overdue)', () {
      final start = DateTime.now().subtract(const Duration(days: 62));
      final sub = Subscription(
        startedAt: start,
        trialEndsAt: start.add(const Duration(days: 60)),
      );
      expect(sub.status, SubscriptionStatus.overdue);
    });

    test('após a carência de 5 dias, suspende', () {
      final start = DateTime.now().subtract(const Duration(days: 70));
      final sub = Subscription(
        startedAt: start,
        trialEndsAt: start.add(const Duration(days: 60)),
      );
      expect(sub.status, SubscriptionStatus.suspended);
    });

    test('pagamento mensal estende cobertura a partir do fim do trial', () {
      final sub = Subscription.startTrial();
      sub.registerPayment(PlanCatalog.unica, 'pix');
      expect(sub.status, SubscriptionStatus.active);
      // cobre o trial inteiro + 30 dias
      expect(
        sub.coveredUntil.difference(DateTime.now()).inDays,
        inInclusiveRange(118, 120),
      );
    });

    test('pagamento depois do trial vencido cobre a partir de hoje', () {
      final start = DateTime.now().subtract(const Duration(days: 61));
      final sub = Subscription(
        startedAt: start,
        trialEndsAt: start.add(const Duration(days: 60)),
      );
      sub.registerPayment(PlanCatalog.unica, 'credit');
      expect(sub.status, SubscriptionStatus.active);
      expect(
        sub.coveredUntil.difference(DateTime.now()).inDays,
        inInclusiveRange(28, 30),
      );
    });
  });

  group('Períodos e uso', () {
    test('semestral 10% e anual 15% sobre 29,90', () {
      const plan = PlanCatalog.unica;
      expect(plan.priceForPeriod(0, BillingPeriod.monthly), 29.90);
      // 6 × 29,90 = 179,40 × 0,9 = 161,46
      expect(plan.priceForPeriod(0, BillingPeriod.semester), 161.46);
      // 12 × 29,90 = 358,80 × 0,85 = 304,98
      expect(plan.priceForPeriod(0, BillingPeriod.annual), 304.98);
    });

    test('pagamento anual soma 12 meses pagos', () {
      final sub = Subscription.startTrial();
      sub.registerPayment(PlanCatalog.unica, 'pix',
          period: BillingPeriod.annual);
      expect(sub.paidCycles, 12);
    });

    test('extra: 5 reais por bloco acima do limite, teto de 50', () {
      const plan = PlanCatalog.unica;
      final dentro = UsageReport(
          plan: plan, visits: 9000, products: 400, storageBytes: 0);
      expect(dentro.extraCharge, 0);
      final acima = UsageReport(
          plan: plan, visits: 12500, products: 650, storageBytes: 0);
      // 3 blocos de visitas + 2 de produtos = 25
      expect(acima.extraCharge, 25);
      expect(acima.capReached, isFalse);
      final muito = UsageReport(
          plan: plan, visits: 40000, products: 500, storageBytes: 0);
      expect(muito.extraCharge, 50);
      expect(muito.capReached, isTrue);
    });
  });

  group('Planos', () {
    test('preços: 29,90 / 59,90 / 119,90 e campanhas por plano', () {
      expect(PlanCatalog.unica.priceForCycle(0), 29.90);
      expect(PlanCatalog.unica.priceForCycle(40), 29.90);
      expect(PlanCatalog.multilojas.price, 59.90);
      expect(PlanCatalog.multilojasPlus.price, 119.90);
      expect(PlanCatalog.unica.maxCampaigns, 8);
      expect(PlanCatalog.multilojasPlus.maxCampaigns, 60);
    });

    test('plano mínimo por número de lojas (máximo 5)', () {
      expect(PlanCatalog.forLocations(1)!.id, 'unica');
      expect(PlanCatalog.forLocations(2)!.id, 'multilojas');
      expect(PlanCatalog.forLocations(3)!.id, 'multilojas_plus');
      expect(PlanCatalog.forLocations(5)!.id, 'multilojas_plus');
      expect(PlanCatalog.forLocations(6), isNull);
      expect(PlanCatalog.byId('mensal_app').id, 'unica');
    });

    test('taxa de serviço: loja absorve por padrão; toggle repassa', () {
      const store = ServiceFeeConfig();
      expect(store.amount, 0.99);
      expect(store.chargedToCustomer, 0);
      final customer =
          ServiceFeeConfig.fromMap({'amount': 1.99, 'paidBy': 'customer'});
      expect(customer.chargedToCustomer, 1.99);
    });
  });

  group('OrderShipping', () {
    test('Correios gera link oficial de rastreio a partir do código', () {
      final s = OrderShipping(method: 'correios', trackingCode: 'BR123BR');
      expect(s.resolvedTrackingUrl, contains('rastreamento.correios.com.br'));
      expect(s.resolvedTrackingUrl, contains('BR123BR'));
    });

    test('link informado manualmente tem prioridade', () {
      final s = OrderShipping(
        method: 'motoboy',
        trackingUrl: 'https://moto.example/track/9',
      );
      expect(s.resolvedTrackingUrl, 'https://moto.example/track/9');
    });

    test('sem código nem link, não há rastreio', () {
      expect(OrderShipping(method: 'retirada').resolvedTrackingUrl, isNull);
    });
  });
}
