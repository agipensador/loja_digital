import 'package:app_loja_digital/core/tenant.dart';
import 'package:app_loja_digital/models/address.dart';
import 'package:app_loja_digital/models/cart_product.dart';
import 'package:app_loja_digital/models/delivery_option.dart';
import 'package:app_loja_digital/models/item_size.dart';
import 'package:app_loja_digital/models/order.dart';
import 'package:app_loja_digital/models/plan.dart';
import 'package:app_loja_digital/models/product.dart';
import 'package:app_loja_digital/models/user_manager.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/foundation.dart';

class CartManager extends ChangeNotifier {
  CartManager();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final List<CartProduct> items = [];

  String? _userId;
  String? get userId => _userId;

  Address? address;
  Address? get deliveryAddress => address;

  /// Forma de receber escolhida pelo cliente no checkout (retirada, entrega
  /// da loja, Uber, Correios). A loja pode propor outra depois.
  DeliveryOption? deliveryOption;

  num get deliveryPrice => deliveryOption?.fee ?? 0;

  /// Data preferida pelo cliente (entrega própria); a loja define a final.
  DateTime? selectedDeliveryDate;

  /// Taxa da plataforma desta loja (valor e quem paga) — vem do TenantManager.
  ServiceFeeConfig serviceFeeConfig = const ServiceFeeConfig();

  void selectDeliveryOption(DeliveryOption? option) {
    deliveryOption = option;
    final dates = option?.zone?.nextDates(count: 1) ?? [];
    selectedDeliveryDate = dates.isEmpty ? null : dates.first;
    notifyListeners();
  }

  void setSelectedDeliveryDate(DateTime date) {
    selectedDeliveryDate = date;
    notifyListeners();
  }

  /// Atualiza usuário (chamado pelo ProxyProvider / ChangeNotifierProxyProvider)
  /// Recebe o UserManager e tenta extrair um id (compatível com diferentes implementações).
  CartManager updateUser(UserManager userManager) {
    // pega dinamicamente o id (pode ser app.User com .id ou firebase user com .uid)
    final dynamic u = userManager.user;
    final String? uid = (u == null) ? null : (u.id ?? u.uid);

    _userId = uid;
    items.clear();
    address = null;
    deliveryOption = null;

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

  /// Parte da taxa da plataforma que o CLIENTE paga (0 quando a loja
  /// absorve — padrão). A plataforma sempre recebe [platformFee] via split.
  num get serviceFee =>
      items.isEmpty ? 0 : serviceFeeConfig.chargedToCustomer;

  num get platformFee => items.isEmpty ? 0 : serviceFeeConfig.amount;

  num get totalPrice => productsPrice + deliveryPrice + serviceFee;

  bool get isCartValid {
    if (items.isEmpty) return false;
    // todos os itens precisam de tamanho selecionado e estoque suficiente
    for (final cp in items) {
      if (!cp.hasStock) return false;
    }
    return true;
  }

  bool get isAddressValid => address != null;

  bool get isDeliveryChosen => deliveryOption != null;

  // ---------------------------------------------------------------------------
  // Endereço / entrega
  // ---------------------------------------------------------------------------

  /// Novo endereço invalida a forma de entrega (as opções dependem dele).
  void setAddress(Address value) {
    address = value;
    selectDeliveryOption(null);
  }

  void removeAddress() {
    address = null;
    selectDeliveryOption(null);
  }

  Future<void> addToCart(Product product, {required String locationId}) async {
    if (_userId == null) {
      throw StateError('Usuário não logado');
    }

    try {
      final existing =
          items.firstWhere((p) => p.stackable(product, locationId));
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
      final cartProduct =
          CartProduct.fromProduct(product, locationId: locationId);
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
          final index = sizes.indexWhere((s) => s['name'] == cp.size);
          if (index < 0) {
            throw CheckoutException(
                'Tamanho "${cp.size}" indisponível para ${cp.product?.name}');
          }
          final size = ItemSize.fromMap(sizes[index]);
          final int stock = size.stockAt(cp.locationId);
          if (stock < cp.quantity) {
            throw CheckoutException(
                'Estoque insuficiente para ${cp.product?.name} (${cp.size})');
          }
          size.setStockAt(cp.locationId, stock - cp.quantity);
          sizes[index] = size.toMap();
        }
        newSizes[entry.key] = sizes;
      }

      final int current =
          counterSnap.exists ? (counterSnap.data()!['current'] ?? 0) as int : 0;
      final int nextId = current + 1;

      // ---- ESCRITAS ----
      for (final e in newSizes.entries) {
        tx.update(Tenant.col('products').doc(e.key),
            {'sizes': e.value, 'updatedAt': FieldValue.serverTimestamp()});
      }
      tx.set(counterRef, {'current': nextId});

      order.orderId = nextId.toString();
      tx.set(Tenant.col('orders').doc(order.orderId), order.toMap());
    });

    // Reflete a baixa também nos objetos em memória.
    for (final cp in items) {
      final size = cp.itemSize;
      if (size != null) {
        size.setStockAt(cp.locationId, size.stockAt(cp.locationId) - cp.quantity);
      }
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
    deliveryOption = null;
    selectedDeliveryDate = null;
    notifyListeners();
  }
}

class CheckoutException implements Exception {
  CheckoutException(this.message);
  final String message;

  @override
  String toString() => message;
}
