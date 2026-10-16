import 'package:app_loja_digital/core/tenant.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:app_loja_digital/models/product.dart';

class ProductManager extends ChangeNotifier {
  ProductManager() {
    _loadAllProducts();
  }

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

  /// Sincronização incremental do catálogo, a cada abertura do app:
  /// 1. mostra na hora o que está no cache local do Firestore (sem custo);
  /// 2. pede ao servidor só os produtos com `updatedAt` mais novo que o
  ///    mais recente do cache — novos, editados, estoque e excluídos
  ///    (exclusão é soft-delete, também atualiza `updatedAt`).
  /// Sem cache (1º acesso), baixa tudo uma vez. Com 300 produtos e nada
  /// alterado, uma abertura custa 0–1 leitura em vez de 300.
  Future<void> _loadAllProducts() async {
    final col = Tenant.col('products');
    final Map<String, Product> byId = {};

    try {
      final cached = await col.get(const GetOptions(source: Source.cache));
      for (final d in cached.docs) {
        byId[d.id] = Product.fromDocument(d);
      }
      if (byId.isNotEmpty) {
        _allProducts = byId.values.toList();
        notifyListeners();
      }
    } catch (_) {
      // Sem cache disponível (ex.: navegador sem IndexedDB): segue p/ servidor.
    }

    Timestamp? newest;
    for (final p in byId.values) {
      final t = p.updatedAt;
      if (t != null && (newest == null || t.compareTo(newest) > 0)) newest = t;
    }

    try {
      final query = newest == null
          ? col
          : col.where('updatedAt', isGreaterThan: newest);
      final fresh = await query.get(const GetOptions(source: Source.server));
      for (final d in fresh.docs) {
        byId[d.id] = Product.fromDocument(d);
      }
    } catch (e) {
      debugPrint('Catálogo offline, usando cache: $e');
    }

    _allProducts = byId.values.toList();
    notifyListeners();
  }

  /// Força uma atualização (ex.: puxar para atualizar, volta do background).
  Future<void> refresh() => _loadAllProducts();

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
