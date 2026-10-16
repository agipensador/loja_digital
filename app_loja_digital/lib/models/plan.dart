/// Planos da plataforma e valores de cobrança.
///
/// Hoje o catálogo é código (mock); quando o backend entrar (Fase 3) ele
/// passa a viver em platform/plans no Firestore, e o pagamento real será
/// via Mercado Pago (assinatura Pix/cartão). Ver ARQUITETURA_SAAS.md §2.2.
library;

import 'package:app_loja_digital/helpers/br_format.dart';

/// Valores fixos da plataforma.
class PlatformBilling {
  PlatformBilling._();

  /// Taxa de serviço padrão por pedido (receita da plataforma, retida no
  /// split do Mercado Pago). Quem paga — loja ou consumidor — é configurado
  /// por loja em `stores/{id}.serviceFee` (ver [ServiceFeeConfig]).
  static const num serviceFee = 0.99;

  /// Toda loja nova ganha 3 meses grátis a partir da criação (atração);
  /// a 1ª cobrança (Pix) vai no fim do período.
  static const int trialDays = 90;

  /// Dias de carência após vencer antes de suspender a loja.
  static const int graceDays = 5;
}

enum PlanCycle { monthly, yearly }

/// Degrau de preço: a partir do ciclo pago [fromCycle] (0 = 1º mês).
class PriceStep {
  const PriceStep(this.fromCycle, this.price);
  final int fromCycle;
  final num price;
}

class Plan {
  const Plan({
    required this.id,
    required this.name,
    required this.steps,
    required this.description,
    this.cycle = PlanCycle.monthly,
    this.maxLocations = 1,
    this.maxStaff = 5,
    this.maxVisits = 10000,
    this.maxProducts = 500,
    this.maxStorageGb = 2,
    this.maxCampaigns = 8,
  });

  /// Notificações (campanhas) que a loja pode enviar aos clientes por mês.
  final int maxCampaigns;

  /// Uso incluído no plano (acima disso: cobrança extra, ver [UsageReport]).
  final int maxVisits;
  final int maxProducts;
  final num maxStorageGb;

  final String id;
  final String name;

  /// Preço sobe com o tempo de casa (ex.: 6 meses a R$ 9,90, depois...).
  /// Ordenado por [PriceStep.fromCycle], começando em 0.
  final List<PriceStep> steps;
  final PlanCycle cycle;
  final String description;

  /// Quantas unidades físicas (lojas) a empresa pode ter neste plano.
  final int maxLocations;
  final int maxStaff;

  /// Preço cheio (último degrau).
  num get price => steps.last.price;

  /// Preço do próximo ciclo, dado quantos ciclos já foram pagos.
  num priceForCycle(int paidCycles) {
    num value = steps.first.price;
    for (final s in steps) {
      if (paidCycles >= s.fromCycle) value = s.price;
    }
    return value;
  }

  bool get hasIntro => steps.length > 1;

  String get cycleLabel => cycle == PlanCycle.monthly ? 'mês' : 'ano';

  static String money(num v) => Br.money(v);

  String get priceLabel => '${money(price)}/$cycleLabel';

  /// "R$ 9,90 nos meses 1–6 · R$ 29,90 nos meses 7–12 · R$ 59,90 depois"
  String get introLabel {
    if (!hasIntro) return priceLabel;
    final parts = <String>[];
    for (var i = 0; i < steps.length; i++) {
      final s = steps[i];
      final isLast = i == steps.length - 1;
      parts.add(isLast
          ? '${money(s.price)}/$cycleLabel a partir do mês ${s.fromCycle + 1}'
          : '${money(s.price)} nos meses ${s.fromCycle + 1}–'
              '${steps[i + 1].fromCycle}');
    }
    return parts.join(' · ');
  }

  /// Quanto um pagamento estende a assinatura.
  Duration get cycleDuration =>
      cycle == PlanCycle.monthly ? const Duration(days: 30) : const Duration(days: 365);
}

class PlanCatalog {
  PlanCatalog._();

  // Preços (proposta 2026-10-04, ver docs/MERCADO_E_PRECOS.md): custo médio
  // da loja ≈ 1/4 do preço; 3 meses grátis; extra por uso acima do limite.
  static const Plan unica = Plan(
    id: 'unica',
    name: 'Loja única',
    steps: [PriceStep(0, 29.90)],
    maxLocations: 1,
    description: 'Sua loja com app e site próprios, 1 unidade física.',
  );

  static const Plan multilojas = Plan(
    id: 'multilojas',
    name: 'Multilojas',
    steps: [PriceStep(0, 59.90)],
    maxLocations: 2,
    maxStaff: 15,
    maxCampaigns: 20,
    maxVisits: 25000,
    maxProducts: 1500,
    maxStorageGb: 5,
    description: 'Até 2 unidades físicas, estoque e equipe por unidade.',
  );

  static const Plan multilojasPlus = Plan(
    id: 'multilojas_plus',
    name: 'Multilojas Plus',
    steps: [PriceStep(0, 119.90)],
    maxLocations: 5,
    maxStaff: 30,
    maxCampaigns: 60,
    maxVisits: 60000,
    maxProducts: 3000,
    maxStorageGb: 10,
    description: 'De 3 a 5 unidades físicas (limite da plataforma).',
  );

  static const List<Plan> all = [unica, multilojas, multilojasPlus];

  /// Plano mínimo para ter [locations] unidades (null = acima do limite).
  static Plan? forLocations(int locations) {
    for (final p in all) {
      if (locations <= p.maxLocations) return p;
    }
    return null;
  }

  /// Ids antigos (mensal_basico, essencial_mensal...) caem na Loja única.
  static Plan byId(String id) =>
      all.firstWhere((p) => p.id == id, orElse: () => unica);
}

/// Quem paga a taxa de serviço da plataforma em cada pedido.
enum ServiceFeePayer { store, customer }

/// `stores/{id}.serviceFee`: valor (definido pela plataforma) e quem paga
/// (toggle do dono). Em ambos os casos a plataforma recebe o valor via
/// `application_fee` do Mercado Pago; a diferença é se ele é somado ao
/// total do consumidor ou sai do repasse da loja.
class ServiceFeeConfig {
  const ServiceFeeConfig({
    this.amount = PlatformBilling.serviceFee,
    this.paidBy = ServiceFeePayer.store,
  });

  factory ServiceFeeConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const ServiceFeeConfig();
    return ServiceFeeConfig(
      amount: (map['amount'] ?? PlatformBilling.serviceFee) as num,
      paidBy: map['paidBy'] == 'customer'
          ? ServiceFeePayer.customer
          : ServiceFeePayer.store,
    );
  }

  final num amount;
  final ServiceFeePayer paidBy;

  /// Quanto o consumidor paga de taxa no checkout (0 quando a loja absorve).
  num get chargedToCustomer =>
      paidBy == ServiceFeePayer.customer ? amount : 0;

  Map<String, dynamic> toMap() => {
        'amount': amount,
        'paidBy': paidBy.name,
      };
}

/// Uso do mês comparado ao incluído no plano, e a cobrança extra.
///
/// Extra (estimativa de custo ×~5 de margem, ver docs/CUSTOS_E_PRECOS.md):
/// R$ 5 a cada 1.000 visitas, a cada 100 produtos ou a cada GB acima do
/// limite, com TETO de [maxExtraCharge] por mês. Ao bater o teto, novos
/// produtos e fotos ficam bloqueados (as vendas e visitas continuam) e a
/// loja é convidada a subir de plano.
class UsageReport {
  UsageReport({
    required this.plan,
    required this.visits,
    required this.products,
    required this.storageBytes,
  });

  static const num pricePerBlock = 5;
  static const num maxExtraCharge = 50;
  static const int bytesPerGb = 1024 * 1024 * 1024;

  /// Peso médio de uma foto já comprimida (versão grande + miniatura).
  static const int avgPhotoBytes = 300 * 1024;

  final Plan plan;
  final int visits;
  final int products;
  final int storageBytes;

  num get storageGb => storageBytes / bytesPerGb;

  /// Quantas fotos cabem no armazenamento do plano.
  int get photosIncluded =>
      (plan.maxStorageGb * bytesPerGb / avgPhotoBytes).floor();

  static int _blocksOver(num used, num limit, num blockSize) =>
      used <= limit ? 0 : ((used - limit) / blockSize).ceil();

  int get extraVisitBlocks => _blocksOver(visits, plan.maxVisits, 1000);
  int get extraProductBlocks => _blocksOver(products, plan.maxProducts, 100);
  int get extraStorageBlocks => _blocksOver(storageGb, plan.maxStorageGb, 1);

  num get rawExtraCharge =>
      (extraVisitBlocks + extraProductBlocks + extraStorageBlocks) *
      pricePerBlock;

  num get extraCharge =>
      rawExtraCharge > maxExtraCharge ? maxExtraCharge : rawExtraCharge;

  /// Bateu o teto: bloqueia novos produtos/fotos e sugere outro plano.
  bool get capReached => rawExtraCharge >= maxExtraCharge;

  bool get overLimit => rawExtraCharge > 0;

  double fraction(num used, num limit) =>
      limit <= 0 ? 0 : (used / limit).clamp(0, 1).toDouble();
}

/// Período pago de uma vez: mensal, semestral (-10%) ou anual (-15%).
enum BillingPeriod { monthly, semester, annual }

extension BillingPeriodInfo on BillingPeriod {
  int get months => switch (this) {
        BillingPeriod.monthly => 1,
        BillingPeriod.semester => 6,
        BillingPeriod.annual => 12,
      };

  num get discount => switch (this) {
        BillingPeriod.monthly => 0,
        BillingPeriod.semester => 0.10,
        BillingPeriod.annual => 0.15,
      };

  String get label => switch (this) {
        BillingPeriod.monthly => 'Mensal',
        BillingPeriod.semester => '6 meses (-10%)',
        BillingPeriod.annual => '12 meses (-15%)',
      };

  static BillingPeriod parse(String? name) => BillingPeriod.values.firstWhere(
      (p) => p.name == name,
      orElse: () => BillingPeriod.monthly);
}

extension PlanPeriodPrice on Plan {
  /// Valor do período: soma os meses (respeitando os degraus de preço a
  /// partir de [paidCycles]) e aplica o desconto do período.
  num priceForPeriod(int paidCycles, BillingPeriod period) {
    num total = 0;
    for (var i = 0; i < period.months; i++) {
      total += priceForCycle(paidCycles + i);
    }
    return ((total * (1 - period.discount)) * 100).round() / 100;
  }
}
