import 'package:app_loja_digital/core/tenant.dart';
import 'package:app_loja_digital/models/cart_manager.dart';
import 'package:app_loja_digital/models/cart_product.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum Status { canceled, preparing, transporting, delivered }

/// Dados de envio/entrega do pedido — responsabilidade da loja.
/// O admin informa o método e o código (rastreio dos Correios, código do
/// motoboy...) ao despachar; o cliente acompanha e rastreia pelo app.
class OrderShipping {
  OrderShipping({
    this.method = '',
    this.carrier = '',
    this.trackingCode = '',
    this.trackingUrl = '',
    this.shippedAt,
  });

  OrderShipping.fromMap(Map<String, dynamic> map)
      : method = (map['method'] ?? '') as String,
        carrier = (map['carrier'] ?? '') as String,
        trackingCode = (map['trackingCode'] ?? '') as String,
        trackingUrl = (map['trackingUrl'] ?? '') as String,
        shippedAt = map['shippedAt'] as Timestamp?;

  static const Map<String, String> methods = {
    'correios': 'Correios',
    'motoboy': 'Motoboy',
    'transportadora': 'Transportadora',
    'retirada': 'Retirada na loja',
  };

  String method; // chave em [methods] ou vazio
  String carrier; // ex.: "PAC", "SEDEX", nome do motoboy/transportadora
  String trackingCode;
  String trackingUrl; // link direto (ex.: rastreio do motoboy)
  Timestamp? shippedAt;

  String get methodLabel => methods[method] ?? '';

  bool get hasInfo =>
      method.isNotEmpty || trackingCode.isNotEmpty || trackingUrl.isNotEmpty;

  /// URL de rastreio: usa a informada; para Correios monta a oficial.
  String? get resolvedTrackingUrl {
    if (trackingUrl.isNotEmpty) return trackingUrl;
    if (method == 'correios' && trackingCode.isNotEmpty) {
      return 'https://rastreamento.correios.com.br/app/index.php'
          '?objetos=$trackingCode';
    }
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'method': method,
      'carrier': carrier,
      'trackingCode': trackingCode,
      'trackingUrl': trackingUrl,
      'shippedAt': shippedAt,
    };
  }
}

class Order {
  Order.fromCartManager(CartManager cartManager) {
    items = List.from(cartManager.items);
    productsPrice = cartManager.productsPrice;
    deliveryPrice = cartManager.deliveryPrice;
    serviceFee = cartManager.serviceFee;
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
    productsPrice = (data['productsPrice'] ?? 0) as num;
    deliveryPrice = (data['deliveryPrice'] ?? 0) as num;
    serviceFee = (data['serviceFee'] ?? 0) as num;
    userId = (data['user'] ?? '') as String;
    address = Map<String, dynamic>.from(data['address'] as Map? ?? {});
    date = data['date'] as Timestamp?;
    payment = (data['payment'] ?? '') as String;
    status = Status.values[(data['status'] ?? 0) as int];
    shipping = OrderShipping.fromMap(
        Map<String, dynamic>.from(data['shipping'] as Map? ?? {}));
  }

  DocumentReference<Map<String, dynamic>> get firestoreRef =>
      Tenant.col('orders').doc(orderId);

  late String orderId;
  List<CartProduct> items = [];
  List<Map<String, dynamic>> itemsData = [];
  late num price; // total (produtos + entrega + taxa de serviço)
  num productsPrice = 0;
  num deliveryPrice = 0;
  num serviceFee = 0;
  late String userId;
  late Map<String, dynamic> address;
  Timestamp? date;
  Status status = Status.preparing;
  String payment = '';
  OrderShipping shipping = OrderShipping();

  Map<String, dynamic> toMap() {
    return {
      'items': items.map((c) => c.toOrderItemMap()).toList(),
      'price': price,
      'productsPrice': productsPrice,
      'deliveryPrice': deliveryPrice,
      'serviceFee': serviceFee,
      'user': userId,
      'address': address,
      'status': status.index,
      'payment': payment,
      'shipping': shipping.toMap(),
      'date': Timestamp.now(),
    };
  }

  String get statusText => getStatusText(status);

  String get formattedId => '#${orderId.padLeft(6, '0')}';

  /// Grava as informações de envio (rastreio/motoboy) no pedido.
  Future<void> setShipping(OrderShipping value) async {
    shipping = value;
    shipping.shippedAt ??= Timestamp.now();
    await firestoreRef.update({'shipping': shipping.toMap()});
  }

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

    final firestore = FirebaseFirestore.instance;
    for (final item in itemsData) {
      final pid = item['pid'] as String?;
      final size = item['size'] as String?;
      final quantity = (item['quantity'] ?? 0) as int;
      if (pid == null || size == null) continue;

      final productRef = Tenant.col('products').doc(pid);
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
