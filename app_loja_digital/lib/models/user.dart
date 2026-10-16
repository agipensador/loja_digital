import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  User({
    required this.name,
    required this.email,
    required this.password,
    required this.confirmPassword,
    required this.id,
    this.storeId = '',
  });

  User.fromDocument(DocumentSnapshot<Map<String, dynamic>> document)
      : id = document.id,
        name = (document.data()?['name'] ?? '') as String,
        email = (document.data()?['email'] ?? '') as String,
        storeId = (document.data()?['storeId'] ?? '') as String,
        password = '',
        confirmPassword = '';

  String id;
  String name;
  String email;
  String password;
  String confirmPassword;

  /// Loja onde o usuário se cadastrou — ele pertence somente a ela.
  String storeId;

  bool admin = false;

  /// Versão dos Termos/Política aceita no cadastro (prova de consentimento).
  static const String currentTermsVersion = '2026-09';

  DocumentReference<Map<String, dynamic>> get firestoreRef =>
      FirebaseFirestore.instance.collection('users').doc(id);

      CollectionReference get cartReference => 
      firestoreRef.collection('cart');

  Future<void> saveData() async {
    await firestoreRef.set(toMap(), SetOptions(merge: true));
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      // normalizado para a busca por e-mail na gestão de equipe
      'email': email.trim().toLowerCase(),
      'storeId': storeId,
    };
  }

  Future<void> recordTermsAcceptance() async {
    await firestoreRef.set({
      'acceptedTermsVersion': currentTermsVersion,
      'acceptedTermsAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
