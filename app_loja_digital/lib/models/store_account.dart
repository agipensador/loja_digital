import 'package:app_loja_digital/models/plan.dart';
import 'package:app_loja_digital/models/subscription.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// O TENANT: o documento raiz stores/{storeId} — a conta da empresa na
/// plataforma (donos, plano, assinatura, taxa, ativa/suspensa).
/// Não confundir com Store (unidade física, em locations/). Funcionários
/// ficam em stores/{storeId}/staff (ver StaffMember).
class StoreAccount {
  StoreAccount({
    required this.id,
    this.name = '',
    this.slug = '',
    this.active = true,
    this.ownerUid = '',
    List<String>? masters,
    String? planId,
    Subscription? subscription,
    this.serviceFee = const ServiceFeeConfig(),
    this.mpConnected = false,
    this.closureRequested = false,
  })  : masters = masters ?? [],
        planId = planId ?? PlanCatalog.unica.id,
        subscription = subscription ?? Subscription.startTrial();

  factory StoreAccount.fromDocument(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return StoreAccount(
      id: doc.id,
      name: (data['name'] ?? '') as String,
      slug: (data['slug'] ?? doc.id) as String,
      active: (data['active'] ?? true) as bool,
      ownerUid: (data['ownerUid'] ?? '') as String,
      masters: List<String>.from(data['masters'] as List<dynamic>? ?? []),
      planId: (data['plan'] ?? PlanCatalog.unica.id) as String,
      subscription: Subscription.fromMap(
          Map<String, dynamic>.from(data['subscription'] as Map? ?? {})),
      serviceFee: ServiceFeeConfig.fromMap(
          (data['serviceFee'] as Map?)?.cast<String, dynamic>()),
      mpConnected: (data['mpConnected'] ?? false) as bool,
      closureRequested: (data['closureRequested'] ?? false) as bool,
    );
  }

  /// Donos/sócios (admin-master): tudo, inclui equipe, plano e encerramento.
  static const int maxMasters = 3;

  final String id;
  String name;
  String slug;

  /// Chave de suspensão automática: quando false, site e app saem do ar.
  bool active;

  /// Dono principal (quem criou a loja). Não pode sair nem excluir a conta.
  String ownerUid;

  List<String> masters;

  String planId;
  Subscription subscription;
  ServiceFeeConfig serviceFee;

  /// A conta Mercado Pago da empresa está conectada (gravado pelo backend).
  bool mpConnected;

  /// O dono pediu o encerramento — aguardando a plataforma.
  bool closureRequested;

  Plan get plan => PlanCatalog.byId(planId);

  bool isMaster(String? uid) => uid != null && masters.contains(uid);
  bool isOwner(String? uid) => uid != null && uid == ownerUid;

  bool get canAddMaster => masters.length < maxMasters;

  /// A loja pode vender? (ativa e assinatura não suspensa)
  bool get canSell =>
      active && subscription.status != SubscriptionStatus.suspended;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'slug': slug,
      'active': active,
      'ownerUid': ownerUid,
      'masters': masters,
      'plan': planId,
      'subscription': subscription.toMap(),
      'serviceFee': serviceFee.toMap(),
    };
  }
}
