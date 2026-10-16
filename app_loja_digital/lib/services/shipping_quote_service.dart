import 'dart:convert';
import 'dart:math' as math;

import 'package:app_loja_digital/helpers/br_format.dart';
import 'package:app_loja_digital/models/store.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Estimativas de frete.
///
/// - **Motoboy (Uber)**: a API de cotação do Uber Direct exige conta
///   empresarial de cada loja. Até lá: saída + R$/km (configurável pela
///   loja) × distância entre os CEPs (coordenadas da BrasilAPI; fator 1,3
///   para virar distância de rua). Sem coordenadas, cai no valor fixo.
/// - **Correios**: cotação real via Melhor Envio (gratuito, Correios/Jadlog/
///   Loggi...) exige token secreto → Cloud Function `quoteShipping` (Fase
///   B), usando peso e medidas do produto. Até lá, valor fixo da unidade.
class ShippingQuoteService {
  ShippingQuoteService._();

  static const double roadFactor = 1.3;
  static final Map<String, ({double lat, double lng})?> _coords = {};

  /// Coordenadas do CEP (BrasilAPI v2). Nem todo CEP tem — retorna null.
  static Future<({double lat, double lng})?> coordinates(String cep) async {
    final digits = Br.digits(cep);
    if (digits.length != 8) return null;
    if (_coords.containsKey(digits)) return _coords[digits];
    ({double lat, double lng})? result;
    try {
      final res = await http
          .get(Uri.parse('https://brasilapi.com.br/api/cep/v2/$digits'))
          .timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final c = ((jsonDecode(res.body) as Map)['location'] as Map?)?[
            'coordinates'] as Map?;
        final lat = double.tryParse('${c?['latitude']}');
        final lng = double.tryParse('${c?['longitude']}');
        if (lat != null && lng != null) result = (lat: lat, lng: lng);
      }
    } catch (e) {
      debugPrint('Sem coordenadas para o CEP $digits: $e');
    }
    _coords[digits] = result;
    return result;
  }

  /// Distância em linha reta (km) — fórmula de Haversine.
  static double distanceKm(
      ({double lat, double lng}) a, ({double lat, double lng}) b) {
    const r = 6371.0;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(b.lat - a.lat);
    final dLng = rad(b.lng - a.lng);
    final h = math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(a.lat)) * math.cos(rad(b.lat)) *
            math.pow(math.sin(dLng / 2), 2);
    return 2 * r * math.asin(math.sqrt(h));
  }

  static num uberFromDistance(Store location, double straightKm) {
    final km = straightKm * roadFactor;
    final value = location.uberBaseFee + location.uberPerKm * km;
    return (value * 100).round() / 100;
  }

  /// Estimativa da corrida da unidade até o CEP do cliente.
  static Future<num> estimateUber(Store location, String customerCep) async {
    if (location.uberPerKm <= 0) return location.uberFee;
    final from = await coordinates(location.zipCode);
    final to = await coordinates(customerCep);
    if (from == null || to == null) return location.uberFee;
    return uberFromDistance(location, distanceKm(from, to));
  }
}
