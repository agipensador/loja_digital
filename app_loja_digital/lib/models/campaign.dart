import 'package:app_loja_digital/core/tenant.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Notificação que a LOJA envia aos clientes (stores/{id}/campaigns).
/// Aparece na caixa de notificações do app; o push no celular é disparado
/// pela Cloud Function `onCampaignCreated` (FCM, tópico `store_<id>`).
class Campaign {
  Campaign({
    this.id,
    required this.title,
    required this.body,
    this.createdAt,
    this.createdBy = '',
  });

  Campaign.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc)
      : id = doc.id,
        title = (doc.data()?['title'] ?? '') as String,
        body = (doc.data()?['body'] ?? '') as String,
        createdAt = doc.data()?['createdAt'] as Timestamp?,
        createdBy = (doc.data()?['createdBy'] ?? '') as String;

  final String? id;
  final String title;
  final String body;
  final Timestamp? createdAt;
  final String createdBy;

  static CollectionReference<Map<String, dynamic>> get col =>
      Tenant.col('campaigns');

  /// Campanhas do mês corrente (para a cota do plano).
  static Future<int> countThisMonth() async {
    final now = DateTime.now();
    final start = Timestamp.fromDate(DateTime(now.year, now.month));
    final agg = await col
        .where('createdAt', isGreaterThanOrEqualTo: start)
        .count()
        .get();
    return agg.count ?? 0;
  }

  static Stream<List<Campaign>> recent({int limit = 30}) => col
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map(Campaign.fromDocument).toList());

  Future<void> send(String uid) => col.add({
        'title': title,
        'body': body,
        'createdBy': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
}

/// Aviso da PLATAFORMA (Inforizz) para os lojistas: platform/announcements.
/// Escrito pelo painel admin; lido pelas equipes das lojas.
class PlatformAnnouncement {
  PlatformAnnouncement.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc)
      : id = doc.id,
        title = (doc.data()?['title'] ?? '') as String,
        body = (doc.data()?['body'] ?? '') as String,
        createdAt = doc.data()?['createdAt'] as Timestamp?;

  final String id;
  final String title;
  final String body;
  final Timestamp? createdAt;

  static CollectionReference<Map<String, dynamic>> get col =>
      FirebaseFirestore.instance
          .collection('platform')
          .doc('announcements')
          .collection('items');

  static Stream<List<PlatformAnnouncement>> recent({int limit = 20}) => col
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map(PlatformAnnouncement.fromDocument).toList());
}
