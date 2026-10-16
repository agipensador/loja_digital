import 'package:app_loja_digital/core/tenant.dart';
import 'package:app_loja_digital/models/item_size.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Área de entrega própria da loja: locais atendidos (cidades ou bairros,
/// ex.: "São Leopoldo"), dias da semana em que o lojista passa por lá e um
/// valor fixo. O checkout oferece ao cliente cujo endereço cai na área.
class DeliveryZone {
  DeliveryZone({
    this.id,
    this.name = '',
    this.locationId = kDefaultLocationId,
    this.fee = 0,
    List<String>? districts,
    List<int>? weekdays,
    this.active = true,
  }) {
    this.districts = districts ?? [];
    this.weekdays = weekdays ?? [];
  }

  DeliveryZone.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    id = doc.id;
    final data = doc.data()!;
    name = (data['name'] ?? '') as String;
    locationId = (data['locationId'] ?? kDefaultLocationId) as String;
    fee = (data['fee'] ?? 0) as num;
    districts = List<String>.from(data['districts'] as List<dynamic>? ?? []);
    weekdays = List<int>.from(data['weekdays'] as List<dynamic>? ?? []);
    active = (data['active'] ?? true) as bool;
  }

  String? id;
  late String name;

  /// Unidade física que faz esta rota (a entrega sai dela).
  String locationId = kDefaultLocationId;

  /// Valor fixo da entrega nesta área.
  num fee = 0;

  /// Locais atendidos: nomes de cidade OU de bairro (comparação sem acento
  /// e sem maiúsculas — ver [normalizeDistrict]).
  late List<String> districts;

  /// Dias da semana atendidos: 1 = segunda ... 7 = domingo (DateTime.weekday).
  late List<int> weekdays;
  bool active = true;

  DocumentReference<Map<String, dynamic>> get firestoreRef =>
      Tenant.col('deliveryZones').doc(id);

  /// Normaliza para comparar bairros ignorando acento/maiúsculas/espaços.
  static String normalizeDistrict(String value) {
    const withAccents = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
    const withoutAccents = 'aaaaaeeeeiiiiooooouuuucn';
    var result = value.trim().toLowerCase();
    for (var i = 0; i < withAccents.length; i++) {
      result = result.replaceAll(withAccents[i], withoutAccents[i]);
    }
    return result;
  }

  bool coversDistrict(String district) {
    final normalized = normalizeDistrict(district);
    return districts.any((d) => normalizeDistrict(d) == normalized);
  }

  /// O endereço cai na área se o bairro OU a cidade estiver na lista.
  bool covers({required String district, required String city}) =>
      (district.isNotEmpty && coversDistrict(district)) ||
      (city.isNotEmpty && coversDistrict(city));

  /// Próximas [count] datas (a partir de hoje, inclusive) em que esta zona
  /// atende, conforme [weekdays].
  List<DateTime> nextDates({int count = 4, DateTime? from}) {
    final List<DateTime> dates = [];
    if (weekdays.isEmpty) return dates;
    DateTime cursor = from ?? DateTime.now();
    cursor = DateTime(cursor.year, cursor.month, cursor.day);
    for (var i = 0; dates.length < count && i < 60; i++) {
      final day = cursor.add(Duration(days: i));
      if (weekdays.contains(day.weekday)) {
        dates.add(day);
      }
    }
    return dates;
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'locationId': locationId,
      'fee': fee,
      'districts': districts,
      'weekdays': weekdays,
      'active': active,
    };
  }

  Future<void> save() async {
    if (id == null) {
      final doc = await Tenant.col('deliveryZones').add(toMap());
      id = doc.id;
    } else {
      await firestoreRef.update(toMap());
    }
  }

  Future<void> delete() async {
    await firestoreRef.delete();
  }

  DeliveryZone clone() {
    return DeliveryZone(
      id: id,
      name: name,
      locationId: locationId,
      fee: fee,
      districts: List.from(districts),
      weekdays: List.from(weekdays),
      active: active,
    );
  }
}
