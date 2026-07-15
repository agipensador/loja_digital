import 'package:app_loja_digital/models/payment_card.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Mostra o logo da bandeira do cartão. Para bandeiras com ícone próprio
/// (Visa/Master/Amex) usa o logo; para Elo/Hipercard mostra o nome; senão,
/// um ícone genérico de cartão.
class BrandIcon extends StatelessWidget {
  const BrandIcon(this.brand, {super.key, this.color, this.size = 28});

  final CardBrand brand;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    switch (brand) {
      case CardBrand.visa:
        return FaIcon(FontAwesomeIcons.ccVisa, color: color, size: size);
      case CardBrand.mastercard:
        return FaIcon(FontAwesomeIcons.ccMastercard,
            color: color, size: size);
      case CardBrand.amex:
        return FaIcon(FontAwesomeIcons.ccAmex, color: color, size: size);
      case CardBrand.elo:
      case CardBrand.hipercard:
        return Text(
          PaymentCard.brandLabel(brand),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: size * 0.55,
          ),
        );
      case CardBrand.other:
        return Icon(Icons.credit_card, color: color, size: size);
    }
  }
}
