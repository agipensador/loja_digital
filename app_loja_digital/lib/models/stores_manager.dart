import 'dart:async';

import 'package:app_loja_digital/core/tenant.dart';
import 'package:app_loja_digital/models/address.dart';
import 'package:app_loja_digital/models/item_size.dart';
import 'package:app_loja_digital/models/store.dart';
import 'package:flutter/foundation.dart';

/// Unidades físicas da loja (stores/{storeId}/locations) e qual delas atende
/// o cliente atual (escolhida pela cidade/UF do endereço, com troca manual).
class StoresManager extends ChangeNotifier {
  StoresManager() {
    _sub = Tenant.col('locations').snapshots().listen((snap) {
      stores = snap.docs.map((d) => Store.fromDocument(d)).toList()
        ..sort((a, b) => a.id == kDefaultLocationId
            ? -1
            : b.id == kDefaultLocationId
                ? 1
                : a.name.compareTo(b.name));
      notifyListeners();
    }, onError: (Object e) => debugPrint('Erro ao ouvir unidades: $e'));
  }

  StreamSubscription<dynamic>? _sub;

  /// Unidades cadastradas.
  List<Store> stores = [];

  /// Unidades para fins de estoque/venda: as cadastradas, ou a unidade
  /// virtual padrão enquanto a loja não cadastrou nenhuma.
  List<Store> get locations => stores.isNotEmpty
      ? stores
      : [Store(id: kDefaultLocationId, name: 'Loja principal')];

  bool get isMultiLocation => stores.length > 1;

  String? _customerLocationId;

  /// Unidade que atende o cliente agora (padrão: a primeira).
  String get currentLocationId {
    final id = _customerLocationId;
    if (id != null && locations.any((l) => l.id == id)) return id;
    return locations.first.id!;
  }

  Store get currentLocation => locationById(currentLocationId)!;

  Store? locationById(String? id) {
    for (final l in locations) {
      if (l.id == id) return l;
    }
    return null;
  }

  String nameOf(String? id) => locationById(id)?.name ?? 'Loja';

  /// Escolhe automaticamente a unidade da cidade/UF do endereço. Sem
  /// unidade na cidade, mantém a atual (envio pelos Correios a partir dela).
  void selectForAddress(Address address) {
    for (final l in locations) {
      if (l.servesCity(address.city, address.state)) {
        selectLocation(l.id!);
        return;
      }
    }
  }

  void selectLocation(String id) {
    if (_customerLocationId == id) return;
    _customerLocationId = id;
    notifyListeners();
  }

  /// Unidade que deve atender o item: a do cliente se tiver estoque, senão
  /// a primeira que tiver.
  String fulfillingLocationFor(ItemSize size) {
    if (size.hasStockAt(currentLocationId)) return currentLocationId;
    for (final l in locations) {
      if (size.hasStockAt(l.id!)) return l.id!;
    }
    return currentLocationId;
  }

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

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
