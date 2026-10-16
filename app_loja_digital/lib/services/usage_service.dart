import 'package:app_loja_digital/core/tenant.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Medição de uso por loja (base do medidor do plano e da cobrança extra):
/// - visitas: `stores/{id}/stats/{aaaa-mm}.visits` (+1 por abertura do app
///   ou do site — 1 escrita por visita, custo desprezível);
/// - armazenamento: `stores/{id}/stats/usage.storageBytes` (somado no
///   upload, descontado ao apagar).
class UsageService {
  UsageService._();

  static bool _visitCounted = false;

  static String monthKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  static DocumentReference<Map<String, dynamic>> monthRef(DateTime d) =>
      Tenant.col('stats').doc(monthKey(d));

  static DocumentReference<Map<String, dynamic>> get usageRef =>
      Tenant.col('stats').doc('usage');

  /// Conta 1 visita por abertura do app/site (uma vez por execução).
  static Future<void> recordVisit() async {
    if (_visitCounted) return;
    _visitCounted = true;
    try {
      await monthRef(DateTime.now())
          .set({'visits': FieldValue.increment(1)}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Falha ao contar visita: $e');
    }
  }

  static Future<void> addStorageBytes(int delta) async {
    if (delta == 0) return;
    try {
      await usageRef.set(
          {'storageBytes': FieldValue.increment(delta)}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Falha ao registrar armazenamento: $e');
    }
  }

  static Stream<int> visitsThisMonth() => monthRef(DateTime.now())
      .snapshots()
      .map((s) => ((s.data()?['visits'] ?? 0) as num).toInt());

  static Stream<int> storageBytes() => usageRef
      .snapshots()
      .map((s) => ((s.data()?['storageBytes'] ?? 0) as num).toInt());
}
