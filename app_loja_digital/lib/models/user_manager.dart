import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:app_loja_digital/models/user.dart' as app;
import 'package:firebase_auth/firebase_auth.dart' as fb;

class UserManager extends ChangeNotifier {
  UserManager() {
    _loadCurrentUser();
    _loadAdmins();
  }

  final fb.FirebaseAuth auth = fb.FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  app.User? user;

  bool _loading = false;
  bool get loading => _loading;

  bool get isLoggedIn => user != null;

  fb.User? _firebaseUser;
  fb.User? get firebaseUser => _firebaseUser;

  final List<String> admins = [];

  bool get adminEnabled => user != null && admins.contains(user!.id);

  set loading(bool value) {
    _loading = value;
    notifyListeners();
  }

  Future<void> signIn(
    app.User user, {
    required Function(String) onFail,
    required Function(String?) onSuccess,
  }) async {
    loading = true;
    try {
      final fb.UserCredential result =
          await auth.signInWithEmailAndPassword(email: user.email, password: user.password);

      user.id = result.user!.uid;
      this.user = user;
      _firebaseUser = result.user;
      user.admin = admins.contains(user.id);

      await user.saveData();

      onSuccess(result.user?.uid);
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

  Future<void> _loadCurrentUser({fb.User? firebaseUser}) async {
    final fb.User? currentUser = firebaseUser ?? auth.currentUser;
    if (currentUser != null) {
      final DocumentSnapshot<Map<String, dynamic>> docUser =
          await firestore.collection('users').doc(currentUser.uid).get();
      user = app.User.fromDocument(docUser);
      _firebaseUser = currentUser;

      // marca admin caso o UID esteja na lista já carregada
      user!.admin = admins.contains(user!.id);

      notifyListeners();
    }
  }

  Future<void> _loadAdmins() async {
    admins.clear();
    final QuerySnapshot<Map<String, dynamic>> snapAdmins =
        await firestore.collection('admins').get();
    for (final doc in snapAdmins.docs) {
      admins.add(doc.id);
    }
    if (user != null) {
      user!.admin = admins.contains(user!.id);
    }
    notifyListeners();
  }
}
