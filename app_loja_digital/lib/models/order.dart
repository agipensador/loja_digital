import 'package:app_loja_digital/core/tenant.dart';
import 'package:app_loja_digital/models/cart_manager.dart';
import 'package:app_loja_digital/models/cart_product.dart';
import 'package:app_loja_digital/models/item_size.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Dinheiro sempre com 2 casas (evita 559.4000000000001 no banco).
num roundMoney(num value) => (value * 100).round() / 100;

/// Gravado por ÍNDICE no Firestore: valores novos só entram no FIM.
enum Status {
  canceled,
  preparing,
  transporting,
  delivered,
  pendingPayment,
  readyForPickup,
}

/// A loja propõe outra forma de entrega (ex.: cliente pediu Correios a
/// R$ 20, a loja entrega por motoboy a R$ 10); o cliente aceita ou recusa.
class DeliveryChange {
  DeliveryChange({
    required this.method,
    required this.fee,
    required this.previousMethod,
    required this.previousFee,
    this.note = '',
    this.status = 'pending',
    this.requestedAt,
  });

  DeliveryChange.fromMap(Map<String, dynamic> map)
      : method = (map['method'] ?? '') as String,
        fee = (map['fee'] ?? 0) as num,
        previousMethod = (map['previousMethod'] ?? '') as String,
        previousFee = (map['previousFee'] ?? 0) as num,
        note = (map['note'] ?? '') as String,
        status = (map['status'] ?? 'pending') as String,
        requestedAt = map['requestedAt'] as Timestamp?;

  final String method;
  final num fee;
  final String previousMethod;
  final num previousFee;
  final String note;

  /// pending → accepted | rejected (pelo cliente) → applied (pela loja).
  String status;
  final Timestamp? requestedAt;

  bool get isPending => status == 'pending';

  /// Positivo: cliente paga a mais; negativo: loja devolve.
  num get difference => fee - previousFee;

  Map<String, dynamic> toMap() => {
        'method': method,
        'fee': fee,
        'previousMethod': previousMethod,
        'previousFee': previousFee,
        'note': note,
        'status': status,
        'requestedAt': requestedAt ?? Timestamp.now(),
      };
}

/// Ajuste de valor depois de uma troca de entrega aceita.
/// [amount] > 0 = devolver ao cliente; < 0 = cliente deve pagar a diferença.
/// Com o Mercado Pago ligado, a devolução vira estorno parcial automático
/// (cartão ou Pix); até lá a loja devolve e marca como feito.
class OrderAdjustment {
  OrderAdjustment({required this.amount, this.status = 'pending', this.how = ''});

  OrderAdjustment.fromMap(Map<String, dynamic> map)
      : amount = (map['amount'] ?? 0) as num,
        status = (map['status'] ?? 'pending') as String,
        how = (map['how'] ?? '') as String;

  final num amount;
  String status; // pending | done
  String how; // 'mp_refund' | 'pix_manual' | 'charged'

  bool get isRefund => amount > 0;

  Map<String, dynamic> toMap() =>
      {'amount': amount, 'status': status, 'how': how};
}

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
    this.scheduledDate,
    this.preferredDate,
    this.zoneId = '',
  });

  OrderShipping.fromMap(Map<String, dynamic> map)
      : method = (map['method'] ?? '') as String,
        carrier = (map['carrier'] ?? '') as String,
        trackingCode = (map['trackingCode'] ?? '') as String,
        trackingUrl = (map['trackingUrl'] ?? '') as String,
        shippedAt = map['shippedAt'] as Timestamp?,
        scheduledDate = map['scheduledDate'] as Timestamp?,
        preferredDate = map['preferredDate'] as Timestamp?,
        zoneId = (map['zoneId'] ?? '') as String;

  static const Map<String, String> methods = {
    'entrega_propria': 'Entrega da loja',
    'retirada': 'Retirada na loja',
    'uber': 'Motoboy (Uber)',
    'correios': 'Correios',
    'motoboy': 'Motoboy',
    'transportadora': 'Transportadora',
  };

  String method; // chave em [methods] ou vazio
  String carrier; // ex.: "PAC", "SEDEX", nome do motoboy/transportadora
  String trackingCode;
  String trackingUrl; // link direto (ex.: rastreio do motoboy)
  Timestamp? shippedAt;

  /// Data FINAL de entrega/retirada — definida pela loja.
  Timestamp? scheduledDate;

  /// Data que o cliente preferiu no checkout (a loja confirma ou muda).
  Timestamp? preferredDate;

  /// Zona de entrega própria usada (ver [DeliveryZone]), vazio se não houve.
  String zoneId;

  String get methodLabel => methods[method] ?? '';

  bool get isPickup => method == 'retirada';

  bool get hasInfo =>
      method.isNotEmpty ||
      trackingCode.isNotEmpty ||
      trackingUrl.isNotEmpty ||
      scheduledDate != null ||
      preferredDate != null;

  static String? _fmt(Timestamp? t) {
    final d = t?.toDate();
    if (d == null) return null;
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}';
  }

  String? get scheduledDateLabel => _fmt(scheduledDate);
  String? get preferredDateLabel => _fmt(preferredDate);

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
      'scheduledDate': scheduledDate,
      'preferredDate': preferredDate,
      'zoneId': zoneId,
    };
  }
}

class Order {
  Order.fromCartManager(CartManager cartManager) {
    items = List.from(cartManager.items);
    productsPrice = roundMoney(cartManager.productsPrice);
    deliveryPrice = roundMoney(cartManager.deliveryPrice);
    serviceFee = roundMoney(cartManager.serviceFee);
    platformFee = roundMoney(cartManager.platformFee);
    price = roundMoney(cartManager.totalPrice);
    userId = cartManager.userId!;
    address = cartManager.address!.toMap();
    locationId = items.isEmpty ? kDefaultLocationId : items.first.locationId;
    final option = cartManager.deliveryOption;
    final preferred = cartManager.selectedDeliveryDate;
    shipping = OrderShipping(
      method: option?.method ?? '',
      zoneId: option?.zone?.id ?? '',
      preferredDate: preferred == null ? null : Timestamp.fromDate(preferred),
    );
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
    platformFee = (data['platformFee'] ?? serviceFee) as num;
    userId = (data['user'] ?? '') as String;
    address = Map<String, dynamic>.from(data['address'] as Map? ?? {});
    date = data['date'] as Timestamp?;
    payment = (data['payment'] ?? '') as String;
    locationId = (data['locationId'] ?? kDefaultLocationId) as String;
    status = Status.values[(data['status'] ?? 0) as int];
    shipping = OrderShipping.fromMap(
        Map<String, dynamic>.from(data['shipping'] as Map? ?? {}));
    final change = data['deliveryChange'] as Map?;
    deliveryChange = change == null
        ? null
        : DeliveryChange.fromMap(Map<String, dynamic>.from(change));
    final adj = data['adjustment'] as Map?;
    adjustment = adj == null
        ? null
        : OrderAdjustment.fromMap(Map<String, dynamic>.from(adj));
  }

  DocumentReference<Map<String, dynamic>> get firestoreRef =>
      Tenant.col('orders').doc(orderId);

  late String orderId;
  List<CartProduct> items = [];
  List<Map<String, dynamic>> itemsData = [];
  late num price; // total (produtos + entrega + taxa de serviço)
  num productsPrice = 0;
  num deliveryPrice = 0;
  /// Parte da taxa da plataforma paga pelo cliente (0 se a loja absorve).
  num serviceFee = 0;

  /// Taxa total da plataforma (retida no split do MP), paga por quem for.
  num platformFee = 0;
  late String userId;
  late Map<String, dynamic> address;
  Timestamp? date;
  Status status = Status.preparing;
  String payment = '';
  OrderShipping shipping = OrderShipping();

  /// Unidade física que atende este pedido (1 pedido por unidade).
  String locationId = kDefaultLocationId;

  DeliveryChange? deliveryChange;
  OrderAdjustment? adjustment;

  Map<String, dynamic> toMap() {
    return {
      'items': items.map((c) => c.toOrderItemMap()).toList(),
      'price': price,
      'productsPrice': productsPrice,
      'deliveryPrice': deliveryPrice,
      'serviceFee': serviceFee,
      'platformFee': platformFee,
      'user': userId,
      'address': address,
      'status': status.index,
      'payment': payment,
      'locationId': locationId,
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

  /// A loja define a data FINAL de entrega/retirada.
  Future<void> setScheduledDate(DateTime date) async {
    shipping.scheduledDate = Timestamp.fromDate(date);
    await firestoreRef.update({'shipping.scheduledDate': shipping.scheduledDate});
  }

  // ---- Troca de forma de entrega (loja propõe, cliente responde) ----

  /// Loja propõe outra forma de entrega/valor; o cliente vê no pedido.
  Future<void> proposeDeliveryChange(
      {required String method, required num fee, String note = ''}) async {
    deliveryChange = DeliveryChange(
      method: method,
      fee: fee,
      previousMethod: shipping.method,
      previousFee: deliveryPrice,
      note: note,
    );
    await firestoreRef.update({'deliveryChange': deliveryChange!.toMap()});
  }

  /// Cliente aceita ou recusa (as rules só deixam ele mexer no status).
  Future<void> respondDeliveryChange({required bool accept}) async {
    final change = deliveryChange;
    if (change == null || !change.isPending) return;
    change.status = accept ? 'accepted' : 'rejected';
    await firestoreRef.update({'deliveryChange.status': change.status});
  }

  /// Loja aplica a troca aceita: novo método e valor, total recalculado e
  /// ajuste registrado (devolver a diferença ou cobrar a mais).
  /// TODO(Fase B): o backend aplica sozinho ao aceite e faz o estorno MP.
  Future<void> applyDeliveryChange() async {
    final change = deliveryChange;
    if (change == null || change.status != 'accepted') return;
    final diff = change.difference;
    shipping.method = change.method;
    deliveryPrice = roundMoney(change.fee);
    price = roundMoney(price + diff);
    change.status = 'applied';
    // Soma com um ajuste ainda não acertado de uma troca anterior.
    final pending =
        adjustment?.status == 'pending' ? adjustment!.amount : 0;
    final total = roundMoney(pending - diff);
    adjustment = total == 0 ? null : OrderAdjustment(amount: total);
    await firestoreRef.update({
      'shipping.method': shipping.method,
      'deliveryPrice': deliveryPrice,
      'price': price,
      'deliveryChange.status': change.status,
      'adjustment': adjustment?.toMap(),
    });
  }

  /// Loja marca a devolução/cobrança como feita (ex.: Pix de devolução).
  Future<void> markAdjustmentDone(String how) async {
    final adj = adjustment;
    if (adj == null) return;
    adj
      ..status = 'done'
      ..how = how;
    await firestoreRef.update({'adjustment': adj.toMap()});
  }

  /// Próximo status: retirada pula "em transporte" (fica "pronto p/ retirar").
  Status? get nextStatus {
    switch (status) {
      case Status.pendingPayment:
        return Status.preparing;
      case Status.preparing:
        return shipping.isPickup ? Status.readyForPickup : Status.transporting;
      case Status.transporting:
      case Status.readyForPickup:
        return Status.delivered;
      case Status.delivered:
      case Status.canceled:
        return null;
    }
  }

  Status? get previousStatus {
    switch (status) {
      case Status.transporting:
      case Status.readyForPickup:
        return Status.preparing;
      case Status.delivered:
        return shipping.isPickup ? Status.readyForPickup : Status.transporting;
      case Status.preparing:
      case Status.pendingPayment:
      case Status.canceled:
        return null;
    }
  }

  Future<void> advanceStatus() async {
    final next = nextStatus;
    if (next == null) return;
    status = next;
    await firestoreRef.update({'status': status.index});
  }

  Future<void> backStatus() async {
    final prev = previousStatus;
    if (prev == null) return;
    status = prev;
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
      final locationId =
          (item['locationId'] as String?) ?? kDefaultLocationId;
      if (pid == null || size == null) continue;

      final productRef = Tenant.col('products').doc(pid);
      await firestore.runTransaction((tx) async {
        final snap = await tx.get(productRef);
        if (!snap.exists) return;
        final data = snap.data()!;
        final sizes = List<Map<String, dynamic>>.from(
            (data['sizes'] as List<dynamic>? ?? [])
                .map((e) => Map<String, dynamic>.from(e as Map)));
        for (var i = 0; i < sizes.length; i++) {
          if (sizes[i]['name'] != size) continue;
          final s = ItemSize.fromMap(sizes[i]);
          s.setStockAt(locationId, s.stockAt(locationId) + quantity);
          sizes[i] = s.toMap();
        }
        tx.update(productRef,
            {'sizes': sizes, 'updatedAt': FieldValue.serverTimestamp()});
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
      case Status.pendingPayment:
        return 'Aguardando pagamento';
      case Status.readyForPickup:
        return 'Pronto para retirada';
    }
  }
}
