import 'package:app_loja_digital/models/product.dart';
import 'package:app_loja_digital/models/item_size.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CartProduct {
  // quando criado a partir do produto (usuário adiciona)
  CartProduct.fromProduct(Product product) {
    id = null;
    this.product = product;
    productId = product.id;
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
    FirebaseFirestore.instance
        .collection('products')
        .doc(productId)
        .get()
        .then((pdoc) {
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

  Map<String, dynamic> toCartItemMap() {
    return {
      'pid': productId,
      'quantity': quantity,
      'size': size,
    };
  }

  bool stackable(Product other) {
    return other.id == productId && other.selectedSize?.name == size;
  }

  void increment() => quantity++;

  void decrement() => quantity--;
}
