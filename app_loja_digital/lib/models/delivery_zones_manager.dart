import 'dart:async';

import 'package:app_loja_digital/core/tenant.dart';
import 'package:app_loja_digital/models/address.dart';
import 'package:app_loja_digital/models/delivery_zone.dart';
import 'package:app_loja_digital/models/stores_manager.dart';
import 'package:flutter/foundation.dart';

/// Zonas de entrega própria cadastradas pelo lojista (bairros + dias da
/// semana). Usado pelo admin para gerenciar e pelo checkout para sugerir
/// data de entrega ao cliente.
class DeliveryZonesManager extends ChangeNotifier {
  DeliveryZonesManager() {
    _listen();
  }

  final List<DeliveryZone> _zones = [];
  List<DeliveryZone> get zones => _zones;
  List<DeliveryZone> get activeZones =>
      _zones.where((z) => z.active).toList();

  StreamSubscription<dynamic>? _sub;

  void _listen() {
    _sub = Tenant.col('deliveryZones').snapshots().listen((snap) {
      _zones
        ..clear()
        ..addAll(snap.docs.map((d) => DeliveryZone.fromDocument(d)));
      notifyListeners();
    }, onError: (Object e) {
      debugPrint('Erro ao ouvir zonas de entrega: $e');
    });
  }

  /// Área ativa que atende o endereço: cidade ou bairro na lista E mesmo
  /// estado (UF) da unidade dona da rota — a loja de Curitiba pode entregar
  /// em São José dos Pinhais, mas nunca uma área cai em outro estado.
  /// Unidade sem UF cadastrada (formato antigo) não restringe.
  DeliveryZone? zoneFor(Address address, StoresManager stores,
      {String? locationId}) {
    for (final z in activeZones) {
      if (locationId != null && z.locationId != locationId) continue;
      if (!z.covers(district: address.district, city: address.city)) {
        continue;
      }
      final location = stores.locationById(z.locationId);
      if (location == null) continue;
      if (location.state.isNotEmpty &&
          location.state.toUpperCase() != address.state.trim().toUpperCase()) {
        continue;
      }
      return z;
    }
    return null;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
