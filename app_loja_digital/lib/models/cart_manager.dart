import 'package:app_loja_digital/core/tenant.dart';
import 'package:app_loja_digital/models/address.dart';
import 'package:app_loja_digital/models/cart_product.dart';
import 'package:app_loja_digital/models/order.dart';
import 'package:app_loja_digital/models/plan.dart';
import 'package:app_loja_digital/models/product.dart';
import 'package:app_loja_digital/models/user_manager.dart';
import 'package:app_loja_digital/services/cep_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/foundation.dart';

class CartManager extends ChangeNotifier {
  CartManager();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CepService _cepService = CepService();

  final List<CartProduct> items = [];

  String? _userId;
  String? get userId => _userId;

  Address? address;
  Address? get deliveryAddress => address;

  num deliveryPrice = 0;

  /// Atualiza usuário (chamado pelo ProxyProvider / ChangeNotifierProxyProvider)
  /// Recebe o UserManager e tenta extrair um id (compatível com diferentes implementações).
  CartManager updateUser(UserManager userManager) {
    // pega dinamicamente o id (pode ser app.User com .id ou firebase user com .uid)
    final dynamic u = userManager.user;
    final String? uid = (u == null) ? null : (u.id ?? u.uid);

    _userId = uid;
    items.clear();
    address = null;
    deliveryPrice = 0;

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

  num get subtotalPrice => productsPrice;

  /// Taxa de serviço da plataforma (R$ 1,99 por pedido), paga pelo cliente.
  /// Cobre os custos de transação — ver PlatformBilling.
  num get serviceFee => items.isEmpty ? 0 : PlatformBilling.serviceFee;

  num get totalPrice => productsPrice + deliveryPrice + serviceFee;

  bool get isCartValid {
    if (items.isEmpty) return false;
    // todos os itens precisam de tamanho selecionado e estoque suficiente
    for (final cp in items) {
      if (!cp.hasStock) return false;
    }
    return true;
  }

  bool get isAddressValid => address != null && deliveryPrice > 0;

  // ---------------------------------------------------------------------------
  // Endereço / entrega
  // ---------------------------------------------------------------------------

  Future<void> getAddress(String cep) async {
    final Address fetched = await _cepService.getAddressFromCep(cep);
    address = fetched;
    _calculateDelivery();
    notifyListeners();
  }

  void setAddress(Address value) {
    address = value;
    _calculateDelivery();
    notifyListeners();
  }

  void removeAddress() {
    address = null;
    deliveryPrice = 0;
    notifyListeners();
  }

  /// Cálculo simples e determinístico de frete a partir da região do CEP.
  /// (Loja base em São Paulo capital — prefixo de CEP "0".)
  void _calculateDelivery() {
    if (address == null || address!.zipCode.isEmpty) {
      deliveryPrice = 0;
      return;
    }
    const int storeRegion = 0;
    final int region =
        int.tryParse(address!.zipCode.substring(0, 1)) ?? storeRegion;
    final double distanceFee = (region - storeRegion).abs() * 1.87;
    final double base = 5.97;
    deliveryPrice = double.parse((base + distanceFee).toStringAsFixed(2));
  }

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

  // ---------------------------------------------------------------------------
  // Checkout — cria o pedido e dá baixa no estoque de forma transacional.
  // ---------------------------------------------------------------------------

  Future<Order> checkout({String paymentMethod = ''}) async {
    if (_userId == null) {
      throw StateError('Usuário não logado');
    }
    if (!isCartValid) {
      throw CheckoutException('Há itens sem estoque no carrinho');
    }
    if (address == null) {
      throw CheckoutException('Endereço de entrega não informado');
    }

    final order = Order.fromCartManager(this);
    order.payment = paymentMethod;

    // Agrupa os itens por produto (um produto pode ter vários tamanhos).
    final Map<String, List<CartProduct>> byProduct = {};
    for (final cp in items) {
      byProduct.putIfAbsent(cp.productId, () => []).add(cp);
    }

    final counterRef = Tenant.col('counters').doc('ordercounter');

    await _firestore.runTransaction((tx) async {
      // ---- LEITURAS (devem vir antes de qualquer escrita) ----
      final counterSnap = await tx.get(counterRef);
      final Map<String, Map<String, dynamic>> productData = {};
      for (final pid in byProduct.keys) {
        final snap = await tx.get(Tenant.col('products').doc(pid));
        if (!snap.exists) {
          throw CheckoutException('Produto indisponível');
        }
        productData[pid] = snap.data()!;
      }

      // ---- VALIDA E CALCULA NOVO ESTOQUE ----
      final Map<String, List<Map<String, dynamic>>> newSizes = {};
      for (final entry in byProduct.entries) {
        final data = productData[entry.key]!;
        final sizes = List<Map<String, dynamic>>.from(
            (data['sizes'] as List<dynamic>? ?? [])
                .map((e) => Map<String, dynamic>.from(e as Map)));

        for (final cp in entry.value) {
          final size = sizes.firstWhere(
            (s) => s['name'] == cp.size,
            orElse: () => <String, dynamic>{},
          );
          if (size.isEmpty) {
            throw CheckoutException(
                'Tamanho "${cp.size}" indisponível para ${cp.product?.name}');
          }
          final int stock = (size['stock'] ?? 0) as int;
          if (stock < cp.quantity) {
            throw CheckoutException(
                'Estoque insuficiente para ${cp.product?.name} (${cp.size})');
          }
          size['stock'] = stock - cp.quantity;
        }
        newSizes[entry.key] = sizes;
      }

      final int current =
          counterSnap.exists ? (counterSnap.data()!['current'] ?? 0) as int : 0;
      final int nextId = current + 1;

      // ---- ESCRITAS ----
      for (final e in newSizes.entries) {
        tx.update(Tenant.col('products').doc(e.key), {'sizes': e.value});
      }
      tx.set(counterRef, {'current': nextId});

      order.orderId = nextId.toString();
      tx.set(Tenant.col('orders').doc(order.orderId), order.toMap());
    });

    // Reflete a baixa também nos objetos em memória.
    for (final cp in items) {
      final size = cp.itemSize;
      if (size != null) size.stock -= cp.quantity;
    }

    await clear();
    return order;
  }

  Future<void> clear() async {
    if (_userId != null) {
      final snap = await _userCartRef().get();
      for (final doc in snap.docs) {
        await doc.reference.delete();
      }
    }
    items.clear();
    address = null;
    deliveryPrice = 0;
    notifyListeners();
  }
}

class CheckoutException implements Exception {
  CheckoutException(this.message);
  final String message;

  @override
  String toString() => message;
}
