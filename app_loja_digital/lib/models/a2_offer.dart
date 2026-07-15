import 'package:app_loja_digital/models/product.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Status de moderação definido pelo A2 (a loja só lê como feedback).
enum A2Status { pending, approved, rejected }

/// Contrato padronizado "Offer" que a loja expõe para o A2.
///
/// Esta é a ÚNICA superfície de acoplamento entre a loja e o A2: ambos
/// concordam apenas com o formato desta oferta. O A2 nunca lê o modelo
/// interno de Product da loja — um Adapter do A2 consome [toContract].
class A2Offer {
  A2Offer({
    this.id,
    required this.storeId,
    required this.productId,
    required this.title,
    required this.description,
    required this.price,
    required this.images,
    required this.category,
    required this.metadata,
    this.status = A2Status.pending,
    this.reviewNote = '',
  });

  A2Offer.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc)
      : id = doc.id,
        storeId = (doc.data()?['storeId'] ?? '') as String,
        productId = (doc.data()?['productId'] ?? '') as String,
        title = (doc.data()?['title'] ?? '') as String,
        description = (doc.data()?['description'] ?? '') as String,
        price = (doc.data()?['price'] ?? 0) as num,
        images = List<String>.from(doc.data()?['images'] as List? ?? []),
        category = (doc.data()?['category'] ?? '') as String,
        metadata = Map<String, dynamic>.from(
            doc.data()?['metadata'] as Map? ?? {}),
        reviewNote = (doc.data()?['reviewNote'] ?? '') as String,
        status = A2Status.values.firstWhere(
          (s) => s.name == (doc.data()?['status'] ?? 'pending'),
          orElse: () => A2Status.pending,
        );

  final String? id;
  final String storeId;
  final String productId;
  final String title;
  final String description;
  final num price;
  final List<String> images;
  final String category;
  final Map<String, dynamic> metadata;
  final A2Status status;
  final String reviewNote;

  /// Constrói uma oferta a partir de um produto da loja (mapeamento loja→A2).
  factory A2Offer.fromProduct(Product product, {required String storeId}) {
    return A2Offer(
      storeId: storeId,
      productId: product.id!,
      title: product.name,
      description: product.description,
      price: product.basePrice,
      images: List<String>.from(product.images),
      category: product.category,
      // Metadados configuráveis (tamanhos/variantes), como o A2 espera.
      metadata: {
        'variants': product.sizes
            .map((s) => {'name': s.name, 'price': s.price, 'stock': s.stock})
            .toList(),
        'totalStock': product.totalStock,
      },
    );
  }

  /// Documento gravado na coleção-contrato `a2_offers` (o "outbox" da loja).
  Map<String, dynamic> toContract() {
    return {
      'storeId': storeId,
      'productId': productId,
      'title': title,
      'description': description,
      'price': price,
      'images': images,
      'category': category,
      'metadata': metadata,
      'status': status.name, // a loja publica sempre como 'pending'
      'reviewNote': reviewNote,
      'source': 'loja_digital',
      'contractVersion': 1,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  String get statusLabel {
    switch (status) {
      case A2Status.pending:
        return 'Em análise';
      case A2Status.approved:
        return 'Aprovado';
      case A2Status.rejected:
        return 'Rejeitado';
    }
  }
}
