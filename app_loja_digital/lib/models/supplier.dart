import 'dart:async';

import 'package:app_loja_digital/core/tenant.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Fornecedor/distribuidor: stores/{storeId}/suppliers/{id}. Produtos
/// apontam para ele (`Product.supplierId`) para o pedido de reposição.
class Supplier {
  Supplier({this.id, this.name = '', this.whatsapp = '', this.contact = ''});

  Supplier.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc)
      : id = doc.id,
        name = (doc.data()?['name'] ?? '') as String,
        whatsapp = (doc.data()?['whatsapp'] ?? '') as String,
        contact = (doc.data()?['contact'] ?? '') as String;

  String? id;
  String name;

  /// Só dígitos, com ou sem DDI.
  String whatsapp;

  /// Nome da pessoa de contato (usado na saudação da mensagem).
  String contact;

  /// Número no formato do wa.me: DDI 55 quando vier só DDD + número.
  String get waNumber {
    final digits = whatsapp.replaceAll(RegExp(r'\D'), '');
    return digits.length <= 11 ? '55$digits' : digits;
  }

  bool get hasWhatsapp => whatsapp.replaceAll(RegExp(r'\D'), '').length >= 10;

  Map<String, dynamic> toMap() =>
      {'name': name, 'whatsapp': whatsapp, 'contact': contact};

  Future<void> save() async {
    if (id == null) {
      id = (await Tenant.col('suppliers').add(toMap())).id;
    } else {
      await Tenant.col('suppliers').doc(id).update(toMap());
    }
  }

  Future<void> delete() => Tenant.col('suppliers').doc(id).delete();
}

/// Item de um pedido de reposição.
class RestockItem {
  RestockItem({required this.label, required this.quantity});
  final String label;
  int quantity;
}

/// Monta o link do WhatsApp com a mensagem de reposição já escrita.
class RestockMessage {
  RestockMessage._();

  static String text({
    required Supplier supplier,
    required String storeName,
    required String locationName,
    required List<RestockItem> items,
  }) {
    final greeting =
        supplier.contact.isNotEmpty ? 'Olá, ${supplier.contact}!' : 'Olá!';
    final lines = items
        .where((i) => i.quantity > 0)
        .map((i) => '• ${i.label}: ${i.quantity} un.')
        .join('\n');
    return '$greeting Aqui é da $storeName ($locationName).\n'
        'Gostaria de fazer um pedido de reposição:\n\n$lines\n\n'
        'Pode me confirmar disponibilidade, valor e prazo? Obrigado!';
  }

  static Uri link(Supplier supplier, String message) => Uri.parse(
      'https://wa.me/${supplier.waNumber}?text=${Uri.encodeComponent(message)}');
}

class SuppliersManager extends ChangeNotifier {
  SuppliersManager() {
    _sub = Tenant.col('suppliers').snapshots().listen((snap) {
      suppliers = snap.docs.map(Supplier.fromDocument).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      notifyListeners();
    }, onError: (Object e) => debugPrint('Erro ao ouvir fornecedores: $e'));
  }

  StreamSubscription<dynamic>? _sub;
  List<Supplier> suppliers = [];

  Supplier? byId(String? id) {
    for (final s in suppliers) {
      if (s.id == id) return s;
    }
    return null;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
