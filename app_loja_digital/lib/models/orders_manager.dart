import 'dart:async';

import 'package:app_loja_digital/models/order.dart';
import 'package:app_loja_digital/models/user_manager.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/foundation.dart';

class OrdersManager extends ChangeNotifier {
  OrdersManager();

  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  String? userId;
  bool _admin = false;
  bool get admin => _admin;

  List<Order> orders = [];

  /// Filtros de status usados na tela de pedidos do admin.
  final Set<Status> statusFilter = {
    Status.preparing,
    Status.transporting,
  };

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  OrdersManager updateUser(UserManager userManager) {
    userId = userManager.user?.id;
    _admin = userManager.adminEnabled;

    orders.clear();
    _subscription?.cancel();

    if (userId != null) {
      _listenToOrders();
    } else {
      notifyListeners();
    }

    return this;
  }

  void _listenToOrders() {
    Query<Map<String, dynamic>> query = firestore.collection('orders');
    if (!_admin) {
      query = query.where('user', isEqualTo: userId);
    }

    _subscription = query.snapshots().listen((event) {
      orders = event.docs.map((d) => Order.fromDocument(d)).toList();
      // mais recentes primeiro
      orders.sort((a, b) {
        final da = a.date?.millisecondsSinceEpoch ?? 0;
        final db = b.date?.millisecondsSinceEpoch ?? 0;
        return db.compareTo(da);
      });
      notifyListeners();
    });
  }

  /// Pedidos do próprio usuário (funciona tanto para admin quanto cliente).
  List<Order> get myOrders =>
      orders.where((o) => o.userId == userId).toList();

  /// Lista aplicada aos filtros de status (usada no painel admin).
  List<Order> get filteredOrders {
    return orders.where((o) => statusFilter.contains(o.status)).toList();
  }

  void setStatusFilter({required Status status, required bool enabled}) {
    if (enabled) {
      statusFilter.add(status);
    } else {
      statusFilter.remove(status);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
