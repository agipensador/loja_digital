import 'dart:async';

import 'package:app_loja_digital/core/tenant.dart';
import 'package:app_loja_digital/models/order.dart';
import 'package:app_loja_digital/models/staff_member.dart';
import 'package:app_loja_digital/models/user_manager.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/foundation.dart';

class OrdersManager extends ChangeNotifier {
  OrdersManager();

  String? userId;
  bool _admin = false;
  bool get admin => _admin;

  List<Order> orders = [];

  /// Filtros de status usados na tela de pedidos do admin.
  final Set<Status> statusFilter = {
    Status.preparing,
    Status.transporting,
    Status.readyForPickup,
  };

  String _search = '';
  String get search => _search;
  set search(String value) {
    _search = value;
    notifyListeners();
  }

  /// Busca por ID do pedido (#000123 ou o id cru) ou nome de produto.
  bool _matchesSearch(Order order) {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return true;
    final numeric = q.replaceAll(RegExp(r'[^0-9]'), '');
    if (order.orderId.toLowerCase().contains(q)) return true;
    if (order.formattedId.toLowerCase().contains(q)) return true;
    if (numeric.isNotEmpty && order.orderId.contains(numeric)) return true;
    for (final item in order.itemsData) {
      final name = (item['name'] ?? '').toString().toLowerCase();
      if (name.contains(q)) return true;
    }
    return false;
  }

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  UserManager? _userManager;
  String? _scope;

  OrdersManager updateUser(UserManager userManager) {
    final newUid = userManager.user?.id;
    final newAdmin = userManager.can(Perm.orders);
    final newScope = userManager.restrictedLocationIds?.join(',');
    _userManager = userManager;
    // UserManager notifica por vários motivos; só reinscreve se mudou algo.
    if (newUid == userId &&
        newAdmin == _admin &&
        newScope == _scope &&
        _subscription != null) {
      notifyListeners();
      return this;
    }
    userId = newUid;
    _admin = newAdmin;
    _scope = newScope;

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
    Query<Map<String, dynamic>> query = Tenant.col('orders');
    final restricted = _userManager?.restrictedLocationIds;
    if (!_admin) {
      query = query.where('user', isEqualTo: userId);
    } else if (restricted != null) {
      // Funcionário de unidades específicas: as rules exigem este filtro.
      query = query.where('locationId', whereIn: restricted);
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
  List<Order> get myOrders => orders
      .where((o) => o.userId == userId && _matchesSearch(o))
      .toList();

  /// Pedidos que a equipe pode ver: funcionário só das unidades dele.
  List<Order> get _teamOrders => orders
      .where((o) => _userManager?.worksAt(o.locationId) ?? false)
      .toList();

  /// Lista aplicada aos filtros de status e busca (usada no painel admin).
  List<Order> get filteredOrders => _teamOrders
      .where((o) => statusFilter.contains(o.status) && _matchesSearch(o))
      .toList();

  void setStatusFilter({required Status status, required bool enabled}) {
    if (enabled) {
      statusFilter.add(status);
    } else {
      statusFilter.remove(status);
    }
    notifyListeners();
  }

  /// Pedidos NÃO cancelados criados dentro do mês de [month] (ano+mês).
  /// Usado pelo relatório financeiro do admin. Cálculo on-the-fly a partir
  /// dos pedidos já carregados em memória — se o histórico da loja crescer
  /// muito, trocar por query paginada por mês
  /// (`where('date', isGreaterThanOrEqualTo: ...)`).
  List<Order> ordersForMonth(DateTime month) {
    return _teamOrders.where((o) {
      final date = o.date?.toDate();
      if (date == null || o.status == Status.canceled) return false;
      return date.year == month.year && date.month == month.month;
    }).toList();
  }

  /// Receita da LOJA: produtos + frete. A taxa de serviço é da plataforma.
  num monthRevenue(DateTime month) => ordersForMonth(month)
      .fold<num>(0, (total, o) => total + o.productsPrice + o.deliveryPrice);

  num monthProductsRevenue(DateTime month) => ordersForMonth(month)
      .fold<num>(0, (total, o) => total + o.productsPrice);

  num monthDeliveryRevenue(DateTime month) => ordersForMonth(month)
      .fold<num>(0, (total, o) => total + o.deliveryPrice);

  int monthOrderCount(DateTime month) => ordersForMonth(month).length;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
