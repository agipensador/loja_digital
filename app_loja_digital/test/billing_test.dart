import 'package:app_loja_digital/models/order.dart';
import 'package:app_loja_digital/models/plan.dart';
import 'package:app_loja_digital/models/subscription.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Subscription (trial 60d + carência 5d)', () {
    test('loja nova fica em trial por 60 dias', () {
      final sub = Subscription.startTrial();
      expect(sub.status, SubscriptionStatus.trial);
      expect(sub.daysLeft, inInclusiveRange(59, 60));
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
      sub.registerPayment(PlanCatalog.mensalBasico, 'pix');
      expect(sub.status, SubscriptionStatus.active);
      // cobre o trial inteiro + 30 dias
      expect(
        sub.coveredUntil.difference(DateTime.now()).inDays,
        inInclusiveRange(88, 90),
      );
    });

    test('pagamento anual cobre 365 dias', () {
      final start = DateTime.now().subtract(const Duration(days: 61));
      final sub = Subscription(
        startedAt: start,
        trialEndsAt: start.add(const Duration(days: 60)),
      );
      sub.registerPayment(PlanCatalog.anualApp, 'credit');
      expect(sub.status, SubscriptionStatus.active);
      expect(
        sub.coveredUntil.difference(DateTime.now()).inDays,
        inInclusiveRange(363, 365),
      );
    });
  });

  group('Planos', () {
    test('catálogo tem os 4 planos com os preços definidos', () {
      expect(PlanCatalog.all.length, 4);
      expect(PlanCatalog.byId('mensal_basico').price, 49.99);
      expect(PlanCatalog.byId('anual_basico').price, 499.99);
      expect(PlanCatalog.byId('mensal_app').price, 49.99);
      expect(PlanCatalog.byId('anual_app').price, 499.99);
    });

    test('planos APP são promo e incluem app; básicos não', () {
      expect(PlanCatalog.mensalApp.includesApp, isTrue);
      expect(PlanCatalog.mensalApp.promo, isTrue);
      expect(PlanCatalog.anualApp.includesApp, isTrue);
      expect(PlanCatalog.mensalBasico.includesApp, isFalse);
      expect(PlanCatalog.anualBasico.includesApp, isFalse);
    });

    test('taxa de serviço por pedido é R\$ 1,99', () {
      expect(PlatformBilling.serviceFee, 1.99);
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
