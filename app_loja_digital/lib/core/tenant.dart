import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Identidade da loja (tenant) que este build/execução atende.
///
/// - Dev/app nativo: `flutter run --dart-define=STORE_ID=loja_ju`
///   (configs prontas no .vscode/launch.json).
/// - Web (Fase 2): o storeId passará a ser resolvido pelo slug da URL
///   (`inforizz.com/slug-da-loja`); até lá vale o dart-define.
///
/// TODA leitura/escrita de dados da loja passa por aqui — é o que garante o
/// isolamento multi-tenant e permite migrar de banco no futuro sem tocar
/// nas telas. Ver docs/ARQUITETURA_SAAS.md §2.5.
class Tenant {
  Tenant._();

  static const String storeId =
      String.fromEnvironment('STORE_ID', defaultValue: 'loja_ju');

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Documento raiz da loja: stores/{storeId}.
  static DocumentReference<Map<String, dynamic>> get storeRef =>
      _db.collection('stores').doc(storeId);

  /// Subcoleção da loja: stores/{storeId}/{name}.
  static CollectionReference<Map<String, dynamic>> col(String name) =>
      storeRef.collection(name);

  /// Pasta da loja no Storage: stores/{storeId}/{folder}.
  static Reference storageFolder(String folder) => FirebaseStorage.instance
      .ref()
      .child('stores')
      .child(storeId)
      .child(folder);
}
