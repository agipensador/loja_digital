import 'package:app_loja_digital/models/saved_address.dart';
import 'package:app_loja_digital/models/user_manager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AddressManager extends ChangeNotifier {
  AddressManager();

  static const int maxAddresses = 5;

  /// Títulos fixos sugeridos; os demais são livres.
  static const List<String> fixedTitles = ['Casa', 'Trabalho'];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _userId;
  List<SavedAddress> addresses = [];
  String? selectedId;

  bool get isLoggedIn => _userId != null;
  bool get canAddMore => addresses.length < maxAddresses;

  AddressManager updateUser(UserManager userManager) {
    _userId = userManager.user?.id;
    addresses = [];
    selectedId = null;
    if (_userId != null) {
      _load();
    } else {
      notifyListeners();
    }
    return this;
  }

  CollectionReference<Map<String, dynamic>> _ref() {
    return _firestore.collection('users').doc(_userId).collection('addresses');
  }

  Future<void> _load() async {
    try {
      final snap = await _ref().get();
      addresses = snap.docs.map((d) => SavedAddress.fromDocument(d)).toList();
      if (addresses.isNotEmpty) selectedId = addresses.first.id;
      notifyListeners();
    } catch (e) {
      debugPrint('Erro ao carregar endereços: $e');
    }
  }

  SavedAddress? get selected {
    if (selectedId == null) return null;
    try {
      return addresses.firstWhere((a) => a.id == selectedId);
    } catch (_) {
      return null;
    }
  }

  void select(String id) {
    selectedId = id;
    notifyListeners();
  }

  /// Cria (se novo) ou atualiza um endereço salvo. Respeita o limite de 5.
  Future<void> save(SavedAddress address) async {
    if (_userId == null) return;
    if (address.id == null) {
      if (!canAddMore) return;
      final doc = await _ref().add(address.toMap());
      address.id = doc.id;
      addresses.add(address);
      selectedId = address.id;
    } else {
      await _ref().doc(address.id).set(address.toMap());
      final i = addresses.indexWhere((a) => a.id == address.id);
      if (i >= 0) addresses[i] = address;
    }
    notifyListeners();
  }

  Future<void> remove(SavedAddress address) async {
    addresses.removeWhere((a) => a.id == address.id);
    if (selectedId == address.id) {
      selectedId = addresses.isNotEmpty ? addresses.first.id : null;
    }
    notifyListeners();
    if (address.id != null) await _ref().doc(address.id).delete();
  }
}
