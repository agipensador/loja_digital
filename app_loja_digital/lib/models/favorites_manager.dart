import 'package:app_loja_digital/models/user_manager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Gerencia os produtos favoritados pelo usuário (users/{uid}/favorites).
class FavoritesManager extends ChangeNotifier {
  FavoritesManager();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _userId;
  final Set<String> _ids = {};

  Set<String> get ids => Set.unmodifiable(_ids);
  bool get isLoggedIn => _userId != null;

  FavoritesManager updateUser(UserManager userManager) {
    _userId = userManager.user?.id;
    _ids.clear();
    if (_userId != null) {
      _load();
    } else {
      notifyListeners();
    }
    return this;
  }

  CollectionReference<Map<String, dynamic>> _ref() {
    return _firestore.collection('users').doc(_userId).collection('favorites');
  }

  Future<void> _load() async {
    try {
      final snap = await _ref().get();
      _ids
        ..clear()
        ..addAll(snap.docs.map((d) => d.id));
      notifyListeners();
    } catch (e) {
      debugPrint('Erro ao carregar favoritos: $e');
    }
  }

  bool isFavorite(String productId) => _ids.contains(productId);

  Future<void> toggle(String productId) async {
    if (_userId == null) return;
    if (_ids.contains(productId)) {
      _ids.remove(productId);
      notifyListeners();
      await _ref().doc(productId).delete();
    } else {
      _ids.add(productId);
      notifyListeners();
      await _ref().doc(productId).set({
        'pid': productId,
        'ts': FieldValue.serverTimestamp(),
      });
    }
  }
}
