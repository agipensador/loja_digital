/// Planos da plataforma e valores de cobrança.
///
/// Hoje o catálogo é código (mock); quando o backend entrar (Fase 3) ele
/// passa a viver em platform/plans no Firestore, e o pagamento real será
/// via Mercado Pago (assinatura Pix/cartão). Ver ARQUITETURA_SAAS.md §2.2.
library;

/// Valores fixos da plataforma.
class PlatformBilling {
  PlatformBilling._();

  /// Taxa de serviço por pedido, paga pelo CLIENTE final no checkout.
  /// Cobre os custos das transações de pagamento.
  static const num serviceFee = 1.99;

  /// Toda loja nova ganha 60 dias grátis a partir da criação.
  static const int trialDays = 60;

  /// Dias de carência após vencer antes de suspender a loja.
  static const int graceDays = 5;
}

enum PlanCycle { monthly, yearly }

class Plan {
  const Plan({
    required this.id,
    required this.name,
    required this.price,
    required this.cycle,
    required this.includesApp,
    this.promo = false,
    required this.description,
  });

  final String id;
  final String name;
  final num price;
  final PlanCycle cycle;

  /// Plano com app nativo próprio (Android/iOS) além do site.
  final bool includesApp;

  /// Em promoção (hoje: planos APP pelo mesmo preço do básico).
  final bool promo;

  final String description;

  String get cycleLabel => cycle == PlanCycle.monthly ? 'mês' : 'ano';

  String get priceLabel =>
      'R\$ ${price.toStringAsFixed(2).replaceAll('.', ',')}/$cycleLabel';

  /// Quanto um pagamento estende a assinatura.
  Duration get cycleDuration =>
      cycle == PlanCycle.monthly ? const Duration(days: 30) : const Duration(days: 365);
}

class PlanCatalog {
  PlanCatalog._();

  static const Plan mensalBasico = Plan(
    id: 'mensal_basico',
    name: 'Mensal Básico',
    price: 49.99,
    cycle: PlanCycle.monthly,
    includesApp: false,
    description: 'Sua loja completa no site inforizz.com.',
  );

  static const Plan anualBasico = Plan(
    id: 'anual_basico',
    name: 'Anual Básico',
    price: 499.99,
    cycle: PlanCycle.yearly,
    includesApp: false,
    description: 'Sua loja completa no site, pagando 1x ao ano '
        '(2 meses de economia).',
  );

  // Futuro (decisão 2026-07-17): teremos os níveis Básico, Médio e
  // Avançado, todos com ciclo mensal e anual. Hoje o "Avançado" é o nível
  // com app incluso, em promoção pelo preço do Básico.
  static const Plan mensalApp = Plan(
    id: 'mensal_app',
    name: 'Avançado Mensal (com App)',
    price: 49.99,
    cycle: PlanCycle.monthly,
    includesApp: true,
    promo: true,
    description: 'Site + aplicativo próprio da sua loja nas lojas '
        'Google e Apple. Promoção: pelo mesmo valor do Básico!',
  );

  static const Plan anualApp = Plan(
    id: 'anual_app',
    name: 'Avançado Anual (com App)',
    price: 499.99,
    cycle: PlanCycle.yearly,
    includesApp: true,
    promo: true,
    description: 'Site + aplicativo próprio, pagando 1x ao ano. '
        'Promoção: pelo mesmo valor do Básico!',
  );

  static const List<Plan> all = [mensalBasico, anualBasico, mensalApp, anualApp];

  static Plan byId(String id) =>
      all.firstWhere((p) => p.id == id, orElse: () => mensalBasico);
}
