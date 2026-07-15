import 'package:app_loja_digital/models/payment_card.dart';
import 'package:app_loja_digital/models/user_manager.dart';
import 'package:app_loja_digital/services/payment_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

const String kPixMethod = 'pix';

class PaymentManager extends ChangeNotifier {
  PaymentManager(this.service);

  final PaymentService service;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _userId;
  List<PaymentCard> cards = [];

  /// id do cartão selecionado, ou [kPixMethod] para Pix.
  String? selectedMethod;

  bool get isLoggedIn => _userId != null;

  PaymentManager updateUser(UserManager userManager) {
    _userId = userManager.user?.id;
    cards = [];
    selectedMethod = null;
    if (_userId != null) {
      _load();
    } else {
      notifyListeners();
    }
    return this;
  }

  CollectionReference<Map<String, dynamic>> _ref() {
    return _firestore.collection('users').doc(_userId).collection('cards');
  }

  Future<void> _load() async {
    try {
      final snap = await _ref().get();
      cards = snap.docs.map((d) => PaymentCard.fromDocument(d)).toList();
      if (cards.isNotEmpty) selectedMethod = cards.first.id;
      notifyListeners();
    } catch (e) {
      debugPrint('Erro ao carregar cartões: $e');
    }
  }

  PaymentCard? get selectedCard {
    if (selectedMethod == null || selectedMethod == kPixMethod) return null;
    try {
      return cards.firstWhere((c) => c.id == selectedMethod);
    } catch (_) {
      return null;
    }
  }

  String get selectedLabel {
    if (selectedMethod == kPixMethod) return 'Pix';
    final c = selectedCard;
    if (c != null) return '${c.brandName} ${c.masked}';
    return 'Selecione uma forma de pagamento';
  }

  void selectMethod(String method) {
    selectedMethod = method;
    notifyListeners();
  }

  /// Adiciona um cartão: tokeniza (provedor) e persiste APENAS o mascarado.
  Future<void> addCard(RawCard raw, {bool debit = false}) async {
    if (_userId == null) return;

    // Fluxo de tokenização já pronto (Fake por enquanto, Mercado Pago depois).
    // O token seria enviado ao backend na cobrança; aqui garantimos que o
    // número real não vá para o Firestore.
    await service.createCardToken(raw);

    final digits = raw.number.replaceAll(RegExp(r'\D'), '');
    final card = PaymentCard(
      holder: raw.holder,
      last4: digits.length >= 4 ? digits.substring(digits.length - 4) : digits,
      expMonth: raw.expMonth,
      expYear: raw.expYear,
      brand: PaymentCard.detectBrand(digits),
      debit: debit,
    );

    final doc = await _ref().add(card.toMap());
    cards.add(PaymentCard(
      id: doc.id,
      holder: card.holder,
      last4: card.last4,
      expMonth: card.expMonth,
      expYear: card.expYear,
      brand: card.brand,
      debit: card.debit,
    ));
    selectedMethod = doc.id;
    notifyListeners();
  }

  Future<void> removeCard(PaymentCard card) async {
    cards.removeWhere((c) => c.id == card.id);
    if (selectedMethod == card.id) {
      selectedMethod = cards.isNotEmpty ? cards.first.id : null;
    }
    notifyListeners();
    if (card.id != null) await _ref().doc(card.id).delete();
  }
}
