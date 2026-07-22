import 'package:app_loja_digital/core/tenant.dart';
import 'package:app_loja_digital/models/a2_offer.dart';
import 'package:app_loja_digital/models/product.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Publica produtos da loja no A2 gravando ofertas no contrato `a2_offers`.
/// É o "outbox" da loja: o A2 consome essa coleção via Adapter e modera.
class A2PublishManager extends ChangeNotifier {
  A2PublishManager() {
    _load();
  }

  static const int maxOffers = 10;

  /// Identidade da loja no contrato A2 — por padrão o próprio tenant;
  /// A2_STORE_ID permite sobrescrever se o A2 usar outra chave.
  static const String _storeIdOverride = String.fromEnvironment('A2_STORE_ID');
  static String get storeId =>
      _storeIdOverride.isNotEmpty ? _storeIdOverride : Tenant.storeId;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<A2Offer> offers = [];
  bool loading = false;

  int get count => offers.length;
  bool get canPublishMore => count < maxOffers;

  CollectionReference<Map<String, dynamic>> get _ref =>
      _firestore.collection('a2_offers');

  Future<void> _load() async {
    try {
      final snap =
          await _ref.where('storeId', isEqualTo: storeId).get();
      offers = snap.docs.map((d) => A2Offer.fromDocument(d)).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Erro ao carregar ofertas A2: $e');
    }
  }

  bool isPublished(String productId) =>
      offers.any((o) => o.productId == productId);

  A2Offer? offerFor(String productId) {
    try {
      return offers.firstWhere((o) => o.productId == productId);
    } catch (_) {
      return null;
    }
  }

  Future<void> publish(Product product) async {
    if (!canPublishMore || isPublished(product.id!)) return;
    loading = true;
    notifyListeners();
    final offer = A2Offer.fromProduct(product, storeId: storeId);
    final doc = await _ref.add(offer.toContract());
    offers.add(A2Offer(
      id: doc.id,
      storeId: offer.storeId,
      productId: offer.productId,
      title: offer.title,
      description: offer.description,
      price: offer.price,
      images: offer.images,
      category: offer.category,
      metadata: offer.metadata,
    ));
    loading = false;
    notifyListeners();
  }

  Future<void> unpublish(String productId) async {
    final offer = offerFor(productId);
    if (offer == null) return;
    offers.removeWhere((o) => o.productId == productId);
    notifyListeners();
    if (offer.id != null) await _ref.doc(offer.id).delete();
  }
}
