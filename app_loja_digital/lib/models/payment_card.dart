import 'package:cloud_firestore/cloud_firestore.dart';

enum CardBrand { visa, mastercard, amex, elo, hipercard, other }

/// Representação SEGURA de um cartão salvo: guardamos apenas dados
/// mascarados. Número completo e CVV nunca são persistidos.
class PaymentCard {
  PaymentCard({
    this.id,
    required this.holder,
    required this.last4,
    required this.expMonth,
    required this.expYear,
    required this.brand,
    this.debit = false,
  });

  PaymentCard.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc)
      : id = doc.id,
        holder = (doc.data()?['holder'] ?? '') as String,
        last4 = (doc.data()?['last4'] ?? '') as String,
        expMonth = (doc.data()?['expMonth'] ?? 0) as int,
        expYear = (doc.data()?['expYear'] ?? 0) as int,
        debit = (doc.data()?['debit'] ?? false) as bool,
        brand = CardBrand.values.firstWhere(
          (b) => b.name == (doc.data()?['brand'] ?? 'other'),
          orElse: () => CardBrand.other,
        );

  final String? id;
  final String holder;
  final String last4;
  final int expMonth;
  final int expYear;
  final CardBrand brand;
  final bool debit;

  String get masked => '•••• •••• •••• $last4';
  String get expiry =>
      '${expMonth.toString().padLeft(2, '0')}/${expYear.toString().padLeft(2, '0')}';
  String get brandName => brandLabel(brand);

  Map<String, dynamic> toMap() {
    return {
      'holder': holder,
      'last4': last4,
      'expMonth': expMonth,
      'expYear': expYear,
      'brand': brand.name,
      'debit': debit,
    };
  }

  static String brandLabel(CardBrand brand) {
    switch (brand) {
      case CardBrand.visa:
        return 'Visa';
      case CardBrand.mastercard:
        return 'Mastercard';
      case CardBrand.amex:
        return 'Amex';
      case CardBrand.elo:
        return 'Elo';
      case CardBrand.hipercard:
        return 'Hipercard';
      case CardBrand.other:
        return 'Cartão';
    }
  }

  /// Detecta a bandeira a partir do número (aproximação por prefixo).
  static CardBrand detectBrand(String number) {
    final n = number.replaceAll(RegExp(r'\D'), '');
    if (n.isEmpty) return CardBrand.other;
    if (n.startsWith('4')) return CardBrand.visa;
    if (RegExp(r'^3[47]').hasMatch(n)) return CardBrand.amex;
    if (RegExp(r'^(636368|438935|504175|451416|5067|4576|4011|506699)')
        .hasMatch(n)) {
      return CardBrand.elo;
    }
    if (RegExp(r'^(606282|3841)').hasMatch(n)) return CardBrand.hipercard;
    if (RegExp(r'^(5[1-5]|2[2-7])').hasMatch(n)) return CardBrand.mastercard;
    return CardBrand.other;
  }
}
