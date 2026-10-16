import 'dart:async';

import 'package:app_loja_digital/core/tenant.dart';
import 'package:app_loja_digital/models/plan.dart';
import 'package:app_loja_digital/models/staff_member.dart';
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

  /// Período escolhido na tela de Assinatura (mensal / 6 / 12 meses).
  BillingPeriod selectedPeriod = BillingPeriod.monthly;

  void selectPeriod(BillingPeriod period) {
    selectedPeriod = period;
    notifyListeners();
  }

  /// Funcionários (stores/{id}/staff). Só o dono consegue ler a lista.
  List<StaffMember> staff = [];

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _staffSub;

  bool get exists => store != null;
  bool get isMaster => store?.isMaster(_currentUid) ?? false;
  bool get isOwner => store?.isOwner(_currentUid) ?? false;

  /// A loja pode vender agora? (bloqueia checkout quando suspensa)
  bool get canSell => store?.canSell ?? true;

  SubscriptionStatus? get subscriptionStatus => store?.subscription.status;

  TenantManager updateUser(UserManager userManager) {
    final uid = userManager.user?.id;
    final wasMaster = isMaster;
    _currentUid = uid;
    if (isMaster != wasMaster || (isMaster && _staffSub == null)) {
      _listenStaff();
    }
    notifyListeners();
    return this;
  }

  void _listenStaff() {
    _staffSub?.cancel();
    _staffSub = null;
    staff = [];
    if (!isMaster) return;
    _staffSub = Tenant.col('staff').snapshots().listen((snap) {
      staff = snap.docs.map(StaffMember.fromDocument).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      notifyListeners();
    }, onError: (Object e) => debugPrint('Erro ao ouvir equipe: $e'));
  }

  void _listen() {
    _sub = Tenant.storeRef.snapshots().listen((snap) {
      final wasMaster = isMaster;
      store = snap.exists ? StoreAccount.fromDocument(snap) : null;
      if (isMaster != wasMaster) _listenStaff();
      notifyListeners();
    }, onError: (Object e) {
      debugPrint('Erro ao carregar a loja ${Tenant.storeId}: $e');
    });
  }

  // ---------------------------------------------------------------------
  // Bootstrap: toda loja nasce com um admin-master (quem cria o cadastro).
  // ---------------------------------------------------------------------

  /// Cria a loja atual tendo o usuário logado como dono/admin-master,
  /// com o período grátis. Usado no primeiro acesso de uma loja nova.
  Future<void> claimStoreOwnership({
    required String uid,
    required String storeName,
    String planId = 'unica',
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

  /// Adiciona alguém à equipe pelo e-mail (a pessoa precisa já ter conta
  /// NESTA loja). [asMaster] = administrador (sócio) com acesso total; senão
  /// gerente/funcionário ([role]) nas unidades [locationIds] (vazio = todas).
  Future<String?> addMemberByEmail(
    String email, {
    bool asMaster = false,
    StaffRole role = StaffRole.employee,
    List<String> locationIds = const [],
  }) async {
    final s = store;
    if (s == null || !isMaster) return 'Apenas o dono pode alterar a equipe.';

    // O filtro por loja também é o que permite às rules autorizar a busca.
    final snap = await _firestore
        .collection('users')
        .where('storeId', isEqualTo: Tenant.storeId)
        .where('email', isEqualTo: email.trim().toLowerCase())
        .limit(1)
        .get();
    if (snap.docs.isEmpty) {
      return 'Nenhum cliente desta loja com este e-mail. A pessoa precisa '
          'criar conta na loja primeiro.';
    }
    final doc = snap.docs.first;
    final uid = doc.id;
    if (s.isMaster(uid) || staff.any((m) => m.uid == uid)) {
      return 'Este usuário já faz parte da equipe.';
    }

    if (asMaster) {
      if (!s.canAddMaster) {
        return 'Limite de ${StoreAccount.maxMasters} donos/sócios atingido.';
      }
      await Tenant.storeRef.update({
        'masters': FieldValue.arrayUnion([uid]),
      });
    } else {
      if (staff.length >= s.plan.maxStaff) {
        return 'Seu plano permite até ${s.plan.maxStaff} funcionários.';
      }
      final member = StaffMember(
        uid: uid,
        name: (doc.data()['name'] ?? '') as String,
        email: (doc.data()['email'] ?? '') as String,
        role: role,
        locationIds: locationIds,
      );
      await member.ref.set(member.toMap());
    }
    return null; // sucesso
  }

  Future<void> updateStaff(StaffMember member) async {
    if (!isMaster) return;
    await member.ref.update(member.toMap());
  }

  /// Remove sócio ou funcionário. O dono principal nunca sai.
  Future<String?> removeMember(String uid) async {
    final s = store;
    if (s == null || !isMaster) return 'Apenas o dono pode alterar a equipe.';
    if (s.isOwner(uid)) {
      return 'O dono da loja não pode ser removido. Para encerrar, use '
          '"Encerrar loja".';
    }
    if (s.isMaster(uid)) {
      await Tenant.storeRef.update({
        'masters': FieldValue.arrayRemove([uid]),
      });
    } else {
      await Tenant.col('staff').doc(uid).delete();
    }
    return null;
  }

  // ---------------------------------------------------------------------
  // Encerramento e taxa de serviço (somente dono)
  // ---------------------------------------------------------------------

  /// O dono não exclui a conta: pede o encerramento à plataforma
  /// (Giovanni), que decide e pode recuperar/reatribuir a loja.
  Future<void> requestStoreClosure(String reason) async {
    if (!isOwner) return;
    final batch = _firestore.batch();
    batch.set(_firestore.collection('platform').doc('closureRequests')
        .collection('requests').doc(Tenant.storeId), {
      'storeId': Tenant.storeId,
      'storeName': store?.name ?? '',
      'requestedBy': _currentUid,
      'reason': reason,
      'requestedAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
    batch.update(Tenant.storeRef, {'closureRequested': true});
    await batch.commit();
  }

  Future<void> setServiceFeePayer(ServiceFeePayer payer) async {
    if (!isMaster) return;
    await Tenant.storeRef.update({'serviceFee.paidBy': payer.name});
  }

  // ---------------------------------------------------------------------
  // Assinatura (somente admin-master) — MOCK hoje, Mercado Pago na Fase 3.
  // ---------------------------------------------------------------------

  Future<void> changePlan(String planId) async {
    if (!isMaster) return;
    await Tenant.storeRef.update({'plan': planId});
  }

  /// Paga a mensalidade/anuidade (simulado). method: 'pix' | 'credit'.
  Future<PaymentResult> paySubscription(String method,
      {BillingPeriod period = BillingPeriod.monthly}) async {
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
          amount: s.subscription.priceFor(plan, period),
          orderId: orderId,
          payerEmail: '',
        );
      } else {
        // Cartão real exigirá tokenização; no mock aprova direto.
        result = await _paymentService.payWithCard(
          cardToken: 'subscription_mock',
          amount: s.subscription.priceFor(plan, period),
          orderId: orderId,
        );
      }

      if (result.approved) {
        s.subscription.registerPayment(plan, method, period: period);
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
    _staffSub?.cancel();
    super.dispose();
  }
}
