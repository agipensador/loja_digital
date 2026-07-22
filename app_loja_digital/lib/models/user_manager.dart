import 'dart:async';

import 'package:app_loja_digital/core/tenant.dart';
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

  /// Papéis da LOJA atual (stores/{storeId}.masters/admins) — não globais.
  List<String> _masters = [];
  List<String> _admins = [];
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _rolesSub;

  /// Admin-master: tudo (inclui equipe e assinatura). Até 3 por loja.
  bool get masterEnabled => user != null && _masters.contains(user!.id);

  /// Equipe da loja (master OU admin): produtos, home, pedidos.
  bool get adminEnabled =>
      user != null &&
      (_masters.contains(user!.id) || _admins.contains(user!.id));

  set loading(bool value) {
    _loading = value;
    notifyListeners();
  }

  void _listenToStoreRoles() {
    _rolesSub = Tenant.storeRef.snapshots().listen((snap) {
      final data = snap.data() ?? <String, dynamic>{};
      _masters = List<String>.from(data['masters'] as List<dynamic>? ?? []);
      _admins = List<String>.from(data['admins'] as List<dynamic>? ?? []);
      user?.admin = adminEnabled;
      notifyListeners();
    }, onError: (Object e) {
      debugPrint('Erro ao ouvir papéis da loja: $e');
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
    notifyListeners();
  }

  Future<app.User?> _loadCurrentUser({fb.User? firebaseUser}) async {
    final fb.User? currentUser = firebaseUser ?? auth.currentUser;
    if (currentUser == null) return null;

    final DocumentSnapshot<Map<String, dynamic>> docUser =
        await firestore.collection('users').doc(currentUser.uid).get();
    user = app.User.fromDocument(docUser);
    _firebaseUser = currentUser;
    user!.admin = adminEnabled;

    notifyListeners();
    return user;
  }

  /// BOOTSTRAP (dev/demo): torna o usuário atual admin-master da loja.
  /// Se a loja ainda não existe, cria com ele como dono (trial de 60 dias)
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
        'admins': <String>[],
        'plan': 'mensal_app',
        'subscription': {
          'startedAt': Timestamp.now(),
          'trialEndsAt': Timestamp.fromDate(
              DateTime.now().add(const Duration(days: 60))),
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
    super.dispose();
  }
}
