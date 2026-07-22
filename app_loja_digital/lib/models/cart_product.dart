import 'package:app_loja_digital/core/tenant.dart';
import 'package:app_loja_digital/models/product.dart';
import 'package:app_loja_digital/models/item_size.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CartProduct {
  // quando criado a partir do produto (usuário adiciona)
  CartProduct.fromProduct(Product product) {
    id = null;
    this.product = product;
    productId = product.id!;
    quantity = 1;
    size = product.selectedSize?.name ?? '';
  }

  // quando lido do Firestore
  CartProduct.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    id = doc.id;
    final data = doc.data() ?? <String, dynamic>{};
    productId = data['pid'] as String? ?? '';
    quantity = data['quantity'] as int? ?? 0;
    size = data['size'] as String? ?? '';

    // carrega o produto completo de forma assíncrona
    Tenant.col('products').doc(productId).get().then((pdoc) {
      product = Product.fromDocument(pdoc);
    });
  }

  // ignore: unused_field
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? id; // id do documento no sub-collection cart
  late String productId;
  late int quantity;
  late String size;

  Product? product; // pode ser null até o carregamento terminar

  ItemSize? get itemSize => product?.findSize(size);

  num get unitPrice {
    return itemSize?.price ?? 0;
  }

  /// Há estoque suficiente para a quantidade pedida deste item.
  bool get hasStock {
    final ItemSize? s = itemSize;
    if (s == null) return false;
    return s.stock >= quantity;
  }

  Map<String, dynamic> toCartItemMap() {
    return {
      'pid': productId,
      'quantity': quantity,
      'size': size,
    };
  }

  /// Snapshot rico usado ao criar um pedido (independe do produto persistir).
  Map<String, dynamic> toOrderItemMap() {
    return {
      'pid': productId,
      'quantity': quantity,
      'size': size,
      'name': product?.name ?? '',
      'price': unitPrice,
      'image': (product?.images.isNotEmpty ?? false)
          ? product!.images.first
          : '',
    };
  }

  bool stackable(Product other) {
    return other.id == productId && other.selectedSize?.name == size;
  }

  void increment() => quantity++;

  void decrement() => quantity--;
}
