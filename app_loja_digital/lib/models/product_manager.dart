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

  String _categoryFilter = '';
  String get categoryFilter => _categoryFilter;
  set categoryFilter(String value) {
    _categoryFilter = value;
    notifyListeners();
  }

  /// Produtos visíveis na loja (não deletados).
  List<Product> get allProducts =>
      List.unmodifiable(_allProducts.where((p) => !p.deleted));

  /// Categorias distintas dos produtos visíveis, em ordem alfabética.
  List<String> get categories {
    final set = <String>{};
    for (final p in allProducts) {
      set.add(p.category);
    }
    final list = set.toList()..sort();
    return list;
  }

  List<Product> get filteredProducts {
    Iterable<Product> result = allProducts;

    if (_categoryFilter.isNotEmpty) {
      result = result.where((p) => p.category == _categoryFilter);
    }

    if (_search.isNotEmpty) {
      result = result
          .where((p) => p.name.toLowerCase().contains(_search.toLowerCase()));
    }

    return result.toList();
  }

  Future<void> _loadAllProducts() async {
    final QuerySnapshot<Map<String, dynamic>> snapProducts =
        await firestore.collection('products').get();

    _allProducts =
        snapProducts.docs.map((d) => Product.fromDocument(d)).toList();
    notifyListeners();
  }

  Product? findProductById(String id) {
    try {
      return _allProducts.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Insere/atualiza um produto na lista local após salvar no Firestore.
  void update(Product product) {
    _allProducts.removeWhere((p) => p.id == product.id);
    _allProducts.add(product);
    notifyListeners();
  }

  void delete(Product product) {
    product.delete();
    _allProducts.removeWhere((p) => p.id == product.id);
    notifyListeners();
  }
}
