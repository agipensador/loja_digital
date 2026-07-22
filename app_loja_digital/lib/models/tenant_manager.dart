import 'dart:async';

import 'package:app_loja_digital/core/tenant.dart';
import 'package:app_loja_digital/models/plan.dart';
import 'package:app_loja_digital/models/store_account.dart';
import 'package:app_loja_digital/models/subscription.dart';
import 'package:app_loja_digital/models/user_manager.dart';
import 'package:app_loja_digital/services/payment_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Gerencia a CONTA da loja atual (stores/{storeId}): equipe (masters/admins),
/// plano e assinatura. Escuta o doc em tempo real — mudar um papel ou pagar
/// reflete no app na hora.
class TenantManager extends ChangeNotifier {
  TenantManager(this._paymentService) {
    _listen();
  }

  final PaymentService _paymentService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StoreAccount? store;
  String? _currentUid;
  bool loading = false;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  bool get exists => store != null;
  bool get isMaster => store?.isMaster(_currentUid) ?? false;
  bool get isAdmin => store?.isAdmin(_currentUid) ?? false;

  /// A loja pode vender agora? (bloqueia checkout quando suspensa)
  bool get canSell => store?.canSell ?? true;

  SubscriptionStatus? get subscriptionStatus => store?.subscription.status;

  TenantManager updateUser(UserManager userManager) {
    _currentUid = userManager.user?.id;
    notifyListeners();
    return this;
  }

  void _listen() {
    _sub = Tenant.storeRef.snapshots().listen((snap) {
      store = snap.exists ? StoreAccount.fromDocument(snap) : null;
      notifyListeners();
    }, onError: (Object e) {
      debugPrint('Erro ao carregar a loja ${Tenant.storeId}: $e');
    });
  }

  // ---------------------------------------------------------------------
  // Bootstrap: toda loja nasce com um admin-master (quem cria o cadastro).
  // ---------------------------------------------------------------------

  /// Cria a loja atual tendo o usuário logado como dono/admin-master,
  /// com trial de 60 dias. Usado no primeiro acesso de uma loja nova.
  Future<void> claimStoreOwnership({
    required String uid,
    required String storeName,
    String planId = 'mensal_app',
  }) async {
    if (store != null && store!.masters.isNotEmpty) {
      throw StateError('Esta loja já tem um admin-master.');
    }
    final account = StoreAccount(
      id: Tenant.storeId,
      name: storeName,
      slug: Tenant.storeId,
      ownerUid: uid,
      masters: [uid],
      planId: planId,
    );
    await Tenant.storeRef.set({
      ...account.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------------------------------------------------------------------
  // Equipe (somente admin-master)
  // ---------------------------------------------------------------------

  /// Adiciona um membro pela conta de e-mail (o usuário precisa já ter se
  /// cadastrado NESTA loja). role: 'master' ou 'admin'.
  Future<String?> addMemberByEmail(String email, String role) async {
    final s = store;
    if (s == null || !isMaster) return 'Apenas admin-master pode alterar a equipe.';

    final snap = await _firestore
        .collection('users')
        .where('email', isEqualTo: email.trim().toLowerCase())
        .limit(1)
        .get();
    if (snap.docs.isEmpty) {
      return 'Nenhum usuário com este e-mail. A pessoa precisa criar conta na loja primeiro.';
    }
    final doc = snap.docs.first;
    final uid = doc.id;
    final userStore = (doc.data()['storeId'] ?? '') as String;
    if (userStore.isNotEmpty && userStore != Tenant.storeId) {
      return 'Este usuário pertence a outra loja.';
    }
    if (s.isMaster(uid) || s.admins.contains(uid)) {
      return 'Este usuário já faz parte da equipe.';
    }

    if (role == 'master') {
      if (!s.canAddMaster) return 'Limite de ${StoreAccount.maxMasters} admins-master atingido.';
      await Tenant.storeRef.update({
        'masters': FieldValue.arrayUnion([uid]),
      });
    } else {
      if (!s.canAddAdmin) return 'Limite de ${StoreAccount.maxAdmins} admins atingido.';
      await Tenant.storeRef.update({
        'admins': FieldValue.arrayUnion([uid]),
      });
    }
    return null; // sucesso
  }

  /// Remove um membro da equipe (master não remove o último master).
  Future<String?> removeMember(String uid) async {
    final s = store;
    if (s == null || !isMaster) return 'Apenas admin-master pode alterar a equipe.';
    if (s.isMaster(uid) && s.masters.length <= 1) {
      return 'A loja precisa de ao menos um admin-master.';
    }
    await Tenant.storeRef.update({
      'masters': FieldValue.arrayRemove([uid]),
      'admins': FieldValue.arrayRemove([uid]),
    });
    return null;
  }

  // ---------------------------------------------------------------------
  // Assinatura (somente admin-master) — MOCK hoje, Mercado Pago na Fase 3.
  // ---------------------------------------------------------------------

  Future<void> changePlan(String planId) async {
    if (!isMaster) return;
    await Tenant.storeRef.update({'plan': planId});
  }

  /// Paga a mensalidade/anuidade (simulado). method: 'pix' | 'credit'.
  Future<PaymentResult> paySubscription(String method) async {
    final s = store;
    if (s == null || !isMaster) {
      return PaymentResult(
          approved: false, message: 'Apenas admin-master pode pagar.');
    }
    loading = true;
    notifyListeners();
    try {
      final Plan plan = s.plan;
      final orderId = 'sub_${s.id}_${DateTime.now().millisecondsSinceEpoch}';

      final PaymentResult result;
      if (method == 'pix') {
        result = await _paymentService.payWithPix(
          amount: plan.price,
          orderId: orderId,
          payerEmail: '',
        );
      } else {
        // Cartão real exigirá tokenização; no mock aprova direto.
        result = await _paymentService.payWithCard(
          cardToken: 'subscription_mock',
          amount: plan.price,
          orderId: orderId,
        );
      }

      if (result.approved) {
        s.subscription.registerPayment(plan, method);
        await Tenant.storeRef.update({
          'subscription': s.subscription.toMap(),
          // Pagou → loja volta ao ar (na Fase 3 isso vira webhook+job).
          'active': true,
        });
      }
      return result;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
