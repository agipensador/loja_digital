import 'package:app_loja_digital/models/plan.dart';
import 'package:app_loja_digital/models/subscription.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// O TENANT: o documento raiz stores/{storeId} — a conta da loja na
/// plataforma (equipe, plano, assinatura, ativa/suspensa).
/// Não confundir com Store (unidade física, em locations/).
class StoreAccount {
  StoreAccount({
    required this.id,
    this.name = '',
    this.slug = '',
    this.active = true,
    this.ownerUid = '',
    List<String>? masters,
    List<String>? admins,
    String? planId,
    Subscription? subscription,
  })  : masters = masters ?? [],
        admins = admins ?? [],
        planId = planId ?? PlanCatalog.mensalBasico.id,
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
      admins: List<String>.from(data['admins'] as List<dynamic>? ?? []),
      planId: (data['plan'] ?? PlanCatalog.mensalBasico.id) as String,
      subscription: Subscription.fromMap(
          Map<String, dynamic>.from(data['subscription'] as Map? ?? {})),
    );
  }

  static const int maxMasters = 3;
  static const int maxAdmins = 5;

  final String id;
  String name;
  String slug;

  /// Chave de suspensão automática: quando false, site e app saem do ar.
  bool active;

  String ownerUid;

  /// Admins-master (até 3): tudo + equipe + assinatura.
  List<String> masters;

  /// Admins (até 5): produtos, home e pedidos. Sem equipe/assinatura.
  List<String> admins;

  String planId;
  Subscription subscription;

  Plan get plan => PlanCatalog.byId(planId);

  bool isMaster(String? uid) => uid != null && masters.contains(uid);
  bool isAdmin(String? uid) =>
      uid != null && (admins.contains(uid) || masters.contains(uid));

  bool get canAddMaster => masters.length < maxMasters;
  bool get canAddAdmin => admins.length < maxAdmins;

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
      'admins': admins,
      'plan': planId,
      'subscription': subscription.toMap(),
    };
  }
}
