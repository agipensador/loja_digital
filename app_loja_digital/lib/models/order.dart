import 'package:app_loja_digital/models/cart_manager.dart';
import 'package:app_loja_digital/models/cart_product.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum Status { canceled, preparing, transporting, delivered }

class Order {
  Order.fromCartManager(CartManager cartManager) {
    items = List.from(cartManager.items);
    price = cartManager.totalPrice;
    userId = cartManager.userId!;
    address = cartManager.address!.toMap();
  }

  Order.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    orderId = doc.id;
    final data = doc.data() ?? <String, dynamic>{};
    itemsData = List<Map<String, dynamic>>.from(
        (data['items'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map)));
    price = (data['price'] ?? 0) as num;
    userId = (data['user'] ?? '') as String;
    address = Map<String, dynamic>.from(data['address'] as Map? ?? {});
    date = data['date'] as Timestamp?;
    payment = (data['payment'] ?? '') as String;
    status = Status.values[(data['status'] ?? 0) as int];
  }

  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get firestoreRef =>
      firestore.collection('orders').doc(orderId);

  late String orderId;
  List<CartProduct> items = [];
  List<Map<String, dynamic>> itemsData = [];
  late num price;
  late String userId;
  late Map<String, dynamic> address;
  Timestamp? date;
  Status status = Status.preparing;
  String payment = '';

  Map<String, dynamic> toMap() {
    return {
      'items': items.map((c) => c.toOrderItemMap()).toList(),
      'price': price,
      'user': userId,
      'address': address,
      'status': status.index,
      'payment': payment,
      'date': Timestamp.now(),
    };
  }

  String get statusText => getStatusText(status);

  String get formattedId => '#${orderId.padLeft(6, '0')}';

  /// Avança o status (Em separação -> Em transporte -> Entregue).
  Future<void> advanceStatus() async {
    if (status == Status.preparing) {
      status = Status.transporting;
    } else if (status == Status.transporting) {
      status = Status.delivered;
    } else {
      return;
    }
    await firestoreRef.update({'status': status.index});
  }

  /// Recua o status (não passa de "Em separação").
  Future<void> backStatus() async {
    if (status == Status.transporting) {
      status = Status.preparing;
    } else if (status == Status.delivered) {
      status = Status.transporting;
    } else {
      return;
    }
    await firestoreRef.update({'status': status.index});
  }

  /// Cancela o pedido e devolve o estoque de cada item.
  Future<void> cancel() async {
    status = Status.canceled;
    await firestoreRef.update({'status': status.index});

    for (final item in itemsData) {
      final pid = item['pid'] as String?;
      final size = item['size'] as String?;
      final quantity = (item['quantity'] ?? 0) as int;
      if (pid == null || size == null) continue;

      final productRef = firestore.collection('products').doc(pid);
      await firestore.runTransaction((tx) async {
        final snap = await tx.get(productRef);
        if (!snap.exists) return;
        final data = snap.data()!;
        final sizes = List<Map<String, dynamic>>.from(
            (data['sizes'] as List<dynamic>? ?? [])
                .map((e) => Map<String, dynamic>.from(e as Map)));
        for (final s in sizes) {
          if (s['name'] == size) {
            s['stock'] = ((s['stock'] ?? 0) as int) + quantity;
          }
        }
        tx.update(productRef, {'sizes': sizes});
      });
    }
  }

  static String getStatusText(Status status) {
    switch (status) {
      case Status.canceled:
        return 'Cancelado';
      case Status.preparing:
        return 'Em separação';
      case Status.transporting:
        return 'Em transporte';
      case Status.delivered:
        return 'Entregue';
    }
  }
}
