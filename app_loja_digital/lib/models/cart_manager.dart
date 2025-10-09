import 'package:app_loja_digital/models/cart_product.dart';
import 'package:app_loja_digital/models/product.dart';
import 'package:app_loja_digital/models/user_manager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class CartManager extends ChangeNotifier {
  CartManager();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final List<CartProduct> items = [];

  String? _userId;

  /// Atualiza usuário (chamado pelo ProxyProvider / ChangeNotifierProxyProvider)
  /// Recebe o UserManager e tenta extrair um id (compatível com diferentes implementações).
  CartManager updateUser(UserManager userManager) {
    // pega dinamicamente o id (pode ser app.User com .id ou firebase user com .uid)
    final dynamic u = userManager.user;
    final String? uid = (u == null) ? null : (u.id ?? u.uid);

    _userId = uid;
    items.clear();

    if (_userId != null) {
      _loadCartItems();
    } else {
      notifyListeners();
    }

    return this;
  }

  CollectionReference<Map<String, dynamic>> _userCartRef() {
    if (_userId == null) {
      throw StateError('Usuário não definido');
    }
    return _firestore.collection('users').doc(_userId).collection('cart');
  }

  Future<void> _loadCartItems() async {
    try {
      final snap = await _userCartRef().get();
      items
        ..clear()
        ..addAll(snap.docs.map((d) => CartProduct.fromDocument(d)).toList());
      notifyListeners();
    } catch (e) {
      // ignore: avoid_print
      print('Erro ao carregar cart items: $e');
    }
  }

  double get productsPrice {
    double total = 0.0;
    for (final cp in items) {
      total += (cp.unitPrice * cp.quantity);
    }
    return total;
  }

  bool get isCartValid => items.isNotEmpty;

  Future<void> addToCart(Product product) async {
    if (_userId == null) {
      throw StateError('Usuário não logado');
    }

    try {
      final existing = items.firstWhere((p) => p.stackable(product));
      existing.increment();
      notifyListeners();

      // atualiza no firestore se existir id
      if (existing.id != null) {
        await _userCartRef().doc(existing.id).update({
          'quantity': existing.quantity,
        });
      }
    } catch (e) {
      // não encontrou -> cria novo
      final cartProduct = CartProduct.fromProduct(product);
      final docRef = await _userCartRef().add(cartProduct.toCartItemMap());
      cartProduct.id = docRef.id;
      items.add(cartProduct);
      notifyListeners();
    }
  }

  Future<void> increment(CartProduct cp) async {
    cp.increment();
    if (_userId != null && cp.id != null) {
      await _userCartRef().doc(cp.id).update({'quantity': cp.quantity});
    }
    notifyListeners();
  }

  Future<void> decrement(CartProduct cp) async {
    cp.decrement();
    if (cp.quantity <= 0) {
      if (_userId != null && cp.id != null) {
        await _userCartRef().doc(cp.id).delete();
      }
      items.remove(cp);
    } else {
      if (_userId != null && cp.id != null) {
        await _userCartRef().doc(cp.id).update({'quantity': cp.quantity});
      }
    }
    notifyListeners();
  }
}
