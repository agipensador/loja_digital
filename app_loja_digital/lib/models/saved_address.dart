import 'package:app_loja_digital/models/address.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Endereço salvo do usuário (Casa, Trabalho ou título personalizado).
class SavedAddress {
  SavedAddress({
    this.id,
    this.title = 'Casa',
    required this.address,
  });

  SavedAddress.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc)
      : id = doc.id,
        title = (doc.data()?['title'] ?? 'Casa') as String,
        address = Address.fromMap(
            Map<String, dynamic>.from(doc.data()?['address'] as Map? ?? {}));

  String? id;
  String title;
  Address address;

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'address': address.toMap(),
    };
  }
}
