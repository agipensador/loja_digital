import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:app_loja_digital/models/product.dart';

class ProductManager extends ChangeNotifier {
  ProductManager() {
    _loadAllProducts();
  }

  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  List<Product> _allProducts = [];

  String _search = '';

  String get search => _search;

  set search(String value) {
    _search = value;
    notifyListeners();
  }

  List<Product> get allProducts => List.unmodifiable(_allProducts);

  List<Product> get filteredProducts {
    if (_search.isEmpty) {
      return List.unmodifiable(_allProducts);
    } else {
      return _allProducts
          .where((p) => p.name.toLowerCase().contains(_search.toLowerCase()))
          .toList();
    }
  }

  Future<void> _loadAllProducts() async {
    final QuerySnapshot<Map<String, dynamic>> snapProducts =
        await firestore.collection('products').get();

    _allProducts =
        snapProducts.docs.map((d) => Product.fromDocument(d)).toList();
    notifyListeners();
  }
}
