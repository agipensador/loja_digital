import 'dart:async';

import 'package:app_loja_digital/core/tenant.dart';
import 'package:app_loja_digital/models/plan.dart';
import 'package:app_loja_digital/models/staff_member.dart';
import 'package:app_loja_digital/models/store.dart';
import 'package:app_loja_digital/models/stores_manager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:app_loja_digital/models/user.dart' as app;
import 'package:firebase_auth/firebase_auth.dart' as fb;

class UserManager extends ChangeNotifier {
  UserManager() {
    _loadCurrentUser();
    _listenToStoreRoles();
  }

  final fb.FirebaseAuth auth = fb.FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  app.User? user;

  bool _loading = false;
  bool get loading => _loading;

  bool get isLoggedIn => user != null;

  fb.User? _firebaseUser;
  fb.User? get firebaseUser => _firebaseUser;

  /// Donos da LOJA atual (stores/{storeId}.masters) — não globais.
  List<String> _masters = [];
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _rolesSub;

  /// Registro de funcionário do usuário logado (stores/{id}/staff/{uid}).
  StaffMember? _staff;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _staffSub;

  /// Admin-master (dono/sócio): tudo, inclui equipe e assinatura.
  bool get masterEnabled => user != null && _masters.contains(user!.id);

  /// Faz parte da equipe (dono ou funcionário): vê a área administrativa.
  bool get adminEnabled => masterEnabled || (user != null && _staff != null);

  /// O dono pode tudo; o funcionário, só o que foi ligado para ele.
  bool can(Perm perm) => masterEnabled || (_staff?.can(perm) ?? false);

  /// Unidades em que o usuário pode atuar (dono: todas).
  List<Store> allowedLocations(StoresManager stores) {
    if (masterEnabled) return stores.locations;
    final staff = _staff;
    if (staff == null) return [];
    return stores.locations.where((l) => staff.worksAt(l.id!)).toList();
  }

  bool worksAt(String locationId) =>
      masterEnabled || (_staff?.worksAt(locationId) ?? false);

  /// "Gerente" / "Funcionário" (vazio para quem não é da equipe).
  String get staffRoleLabel => _staff?.role.label ?? '';

  /// Unidades a que o funcionário está restrito; null = todas (ou dono).
  List<String>? get restrictedLocationIds {
    if (masterEnabled) return null;
    final ids = _staff?.locationIds ?? const [];
    return ids.isEmpty ? null : ids;
  }

  set loading(bool value) {
    _loading = value;
    notifyListeners();
  }

  void _listenToStoreRoles() {
    _rolesSub = Tenant.storeRef.snapshots().listen((snap) {
      final data = snap.data() ?? <String, dynamic>{};
      _masters = List<String>.from(data['masters'] as List<dynamic>? ?? []);
      user?.admin = adminEnabled;
      notifyListeners();
    }, onError: (Object e) {
      debugPrint('Erro ao ouvir papéis da loja: $e');
    });
  }

  void _listenToStaff(String? uid) {
    _staffSub?.cancel();
    _staff = null;
    if (uid == null) return;
    _staffSub = Tenant.col('staff').doc(uid).snapshots().listen((snap) {
      _staff = snap.exists ? StaffMember.fromDocument(snap) : null;
      user?.admin = adminEnabled;
      notifyListeners();
    }, onError: (Object e) {
      debugPrint('Erro ao ouvir permissões: $e');
    });
  }

  Future<void> signIn(
    app.User user, {
    required Function(String) onFail,
    required Function(String?) onSuccess,
  }) async {
    loading = true;
    try {
      final fb.UserCredential result = await auth.signInWithEmailAndPassword(
          email: user.email, password: user.password);

      // Carrega o perfil salvo (não sobrescreve o nome com o form de login).
      final loaded = await _loadCurrentUser(firebaseUser: result.user);

      // Conta bloqueada pelo painel da plataforma.
      final blocked = result.user != null &&
          (await firestore.doc('users/${result.user!.uid}').get())
                  .data()?['blocked'] ==
              true;
      if (blocked) {
        await auth.signOut();
        this.user = null;
        _firebaseUser = null;
        onFail('Esta conta está bloqueada. Fale com a loja.');
      } else
      // Cada cliente pertence SOMENTE à loja onde se cadastrou.
      if (loaded != null && loaded.storeId.isNotEmpty &&
          loaded.storeId != Tenant.storeId) {
        await auth.signOut();
        this.user = null;
        _firebaseUser = null;
        onFail('Esta conta pertence a outra loja.');
      } else {
        // Backfill de contas antigas (criadas antes do multi-tenant).
        if (loaded != null && loaded.storeId.isEmpty) {
          loaded.storeId = Tenant.storeId;
          await loaded.saveData();
        }
        onSuccess(result.user?.uid);
      }
    } on fb.FirebaseAuthException catch (e) {
      onFail(e.message ?? e.code);
    } catch (e) {
      onFail(e.toString());
    }
    loading = false;
  }

  Future<void> signUp({
    required app.User user,
    required Function(String) onFail,
    required Function() onSuccess,
  }) async {
    loading = true;
    try {
      final fb.UserCredential result = await auth.createUserWithEmailAndPassword(
        email: user.email,
        password: user.password,
      );

      user.id = result.user!.uid;
      user.storeId = Tenant.storeId; // cliente nasce vinculado a esta loja
      this.user = user;
      _firebaseUser = result.user;

      await user.saveData();
      // Só existe cadastro pela tela com o aceite obrigatório dos termos.
      await user.recordTermsAcceptance();
      await _claimPendingOwnership(result.user!);
      try {
        await result.user?.sendEmailVerification();
      } catch (e) {
        // A conta já foi criada; o reenvio fica disponível no Perfil.
        debugPrint('Falha ao enviar verificação de e-mail: $e');
      }

      onSuccess();
    } on fb.FirebaseAuthException catch (e) {
      onFail(e.message ?? e.code);
    } catch (e) {
      onFail(e.toString());
    }
    loading = false;
  }

  Future<void> signOut() async {
    await auth.signOut();
    user = null;
    _firebaseUser = null;
    _listenToStaff(null);
    notifyListeners();
  }

  bool get emailVerified => _firebaseUser?.emailVerified ?? false;

  Future<void> sendPasswordReset(
    String email, {
    required Function() onSuccess,
    required Function(String) onFail,
  }) async {
    try {
      await auth.sendPasswordResetEmail(email: email);
      onSuccess();
    } on fb.FirebaseAuthException catch (e) {
      onFail(e.message ?? e.code);
    } catch (e) {
      onFail(e.toString());
    }
  }

  Future<void> sendEmailVerification() async {
    await _firebaseUser?.sendEmailVerification();
  }

  /// O status de verificação fica em cache no token — recarrega do servidor.
  Future<void> reloadEmailVerification() async {
    await _firebaseUser?.reload();
    _firebaseUser = auth.currentUser;
    // Confirmou agora: o token precisa trazer email_verified para as rules,
    // e quem tem loja esperando por este e-mail assume.
    if (_firebaseUser?.emailVerified ?? false) {
      await _firebaseUser!.getIdToken(true);
      await _claimPendingOwnership(_firebaseUser!);
    }
    notifyListeners();
  }

  /// Apaga a conta de CLIENTE ou FUNCIONÁRIO: reautentica com a senha (o
  /// Firebase exige login recente), apaga os dados pessoais (`users/{uid}` +
  /// subcoleções) e por último a conta no Auth. Pedidos NÃO são apagados —
  /// são histórico da loja. Dono/sócio não se exclui: pede o encerramento
  /// da loja à plataforma (ver TenantManager.requestStoreClosure).
  Future<void> deleteAccount({
    required String password,
    required Function() onSuccess,
    required Function(String) onFail,
  }) async {
    final fb.User? current = _firebaseUser;
    if (current == null || current.email == null) return;
    if (masterEnabled) {
      onFail('Donos da loja não excluem a conta por aqui. Use '
          '"Encerrar loja" — a plataforma cuida do encerramento.');
      return;
    }
    try {
      await current.reauthenticateWithCredential(
        fb.EmailAuthProvider.credential(
            email: current.email!, password: password),
      );
      if (_staff != null) await _staff!.ref.delete();
      final userRef = firestore.collection('users').doc(current.uid);
      for (final sub in ['cart', 'addresses', 'cards', 'favorites']) {
        final snap = await userRef.collection(sub).get();
        for (final doc in snap.docs) {
          await doc.reference.delete();
        }
      }
      await userRef.delete();
      await current.delete();
      user = null;
      _firebaseUser = null;
      _listenToStaff(null);
      notifyListeners();
      onSuccess();
    } on fb.FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        onFail('Senha incorreta.');
      } else {
        onFail(e.message ?? e.code);
      }
    } catch (e) {
      onFail(e.toString());
    }
  }

  Future<app.User?> _loadCurrentUser({fb.User? firebaseUser}) async {
    final fb.User? currentUser = firebaseUser ?? auth.currentUser;
    if (currentUser == null) return null;

    final DocumentSnapshot<Map<String, dynamic>> docUser =
        await firestore.collection('users').doc(currentUser.uid).get();
    user = app.User.fromDocument(docUser);
    _firebaseUser = currentUser;
    _listenToStaff(currentUser.uid);
    await _claimPendingOwnership(currentUser);
    user!.admin = adminEnabled;

    notifyListeners();
    return user;
  }

  /// Loja criada pelo tool/new_flavor.sh nasce sem dono e com o e-mail
  /// esperado (`pendingOwnerEmail`): quem entrar com esse e-mail assume.
  Future<void> _claimPendingOwnership(fb.User current) async {
    try {
      final snap = await Tenant.storeRef.get();
      final data = snap.data();
      final pending = (data?['pendingOwnerEmail'] ?? '') as String;
      final masters = (data?['masters'] as List<dynamic>?) ?? const [];
      if (pending.isEmpty ||
          masters.isNotEmpty ||
          pending != (current.email ?? '').toLowerCase()) {
        return;
      }
      // Só com o e-mail confirmado: sem isso, qualquer pessoa poderia criar
      // uma conta com o e-mail do dono e assumir a loja.
      if (!current.emailVerified) return;
      await Tenant.storeRef.update({
        'masters': [current.uid],
        'ownerUid': current.uid,
        'pendingOwnerEmail': FieldValue.delete(),
      });
    } catch (e) {
      debugPrint('Não foi possível assumir a loja: $e');
    }
  }

  /// BOOTSTRAP (dev/demo): torna o usuário atual admin-master da loja.
  /// Se a loja ainda não existe, cria com ele como dono (período grátis)
  /// — é o "quem cria o cadastro vira admin-master".
  Future<void> makeCurrentUserAdmin() async {
    if (user == null) return;
    final snap = await Tenant.storeRef.get();
    final data = snap.data();
    final masters =
        List<String>.from(data?['masters'] as List<dynamic>? ?? []);

    if (!snap.exists || masters.isEmpty) {
      await Tenant.storeRef.set({
        'name': Tenant.storeId,
        'slug': Tenant.storeId,
        'active': true,
        'ownerUid': user!.id,
        'masters': [user!.id],
        'plan': PlanCatalog.unica.id,
        'subscription': {
          'startedAt': Timestamp.now(),
          'trialEndsAt': Timestamp.fromDate(
              DateTime.now().add(const Duration(days: PlatformBilling.trialDays))),
          'paidUntil': null,
          'lastPaymentAt': null,
          'lastPaymentMethod': '',
        },
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } else if (!masters.contains(user!.id) && masters.length < 3) {
      await Tenant.storeRef.update({
        'masters': FieldValue.arrayUnion([user!.id]),
      });
    }
  }

  @override
  void dispose() {
    _rolesSub?.cancel();
    _staffSub?.cancel();
    super.dispose();
  }
}
