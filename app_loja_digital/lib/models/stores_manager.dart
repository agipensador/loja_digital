import 'package:app_loja_digital/core/tenant.dart';
import 'package:app_loja_digital/models/store.dart';
import 'package:flutter/foundation.dart';

/// Unidades físicas da loja (stores/{storeId}/locations).
class StoresManager extends ChangeNotifier {
  StoresManager() {
    _loadStores();
  }

  List<Store> stores = [];

  Future<void> _loadStores() async {
    final snap = await Tenant.col('locations').get();
    stores = snap.docs.map((d) => Store.fromDocument(d)).toList();
    notifyListeners();
  }

  /// Insere/atualiza a loja na lista local após salvar no Firestore.
  void update(Store store) {
    stores.removeWhere((s) => s.id == store.id);
    stores.add(store);
    notifyListeners();
  }

  void delete(Store store) {
    store.delete();
    stores.removeWhere((s) => s.id == store.id);
    notifyListeners();
  }
}
