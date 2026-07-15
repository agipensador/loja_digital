import 'dart:math' as math;

import 'package:app_loja_digital/models/payment_card.dart';
import 'package:app_loja_digital/screens/payment_methods/components/brand_icon.dart';
import 'package:flutter/material.dart';

/// Cartão visual com animação de virar (frente <-> verso).
class CreditCardWidget extends StatefulWidget {
  const CreditCardWidget({
    super.key,
    required this.number,
    required this.holder,
    required this.expiry,
    required this.cvv,
    required this.showBack,
  });

  final String number;
  final String holder;
  final String expiry;
  final String cvv;
  final bool showBack;

  @override
  State<CreditCardWidget> createState() => _CreditCardWidgetState();
}

class _CreditCardWidgetState extends State<CreditCardWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  @override
  void didUpdateWidget(covariant CreditCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showBack && !oldWidget.showBack) _controller.forward();
    if (!widget.showBack && oldWidget.showBack) _controller.reverse();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final angle = _controller.value * math.pi;
        final isBack = angle > math.pi / 2;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle),
          child: isBack
              ? Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(math.pi),
                  child: _back(),
                )
              : _front(),
        );
      },
    );
  }

  BoxDecoration get _decoration => BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF2C3E50), Color(0xFF1B3A4B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(60),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      );

  String get _formattedNumber {
    final digits = widget.number.replaceAll(RegExp(r'\D'), '');
    final buf = StringBuffer();
    for (int i = 0; i < 16; i++) {
      if (i > 0 && i % 4 == 0) buf.write('  ');
      buf.write(i < digits.length ? digits[i] : '•');
    }
    return buf.toString();
  }

  Widget _front() {
    final brand = PaymentCard.detectBrand(widget.number);
    return AspectRatio(
      aspectRatio: 1.6,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: _decoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Container(
                  width: 40,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.amber[300],
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                BrandIcon(brand, color: Colors.white, size: 40),
              ],
            ),
            const Spacer(),
            Text(
              _formattedNumber,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                letterSpacing: 1.5,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Expanded(
                  child: Text(
                    widget.holder.isEmpty
                        ? 'NOME NO CARTÃO'
                        : widget.holder.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
                Text(
                  widget.expiry.isEmpty ? 'MM/AA' : widget.expiry,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _back() {
    return AspectRatio(
      aspectRatio: 1.6,
      child: Container(
        decoration: _decoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SizedBox(height: 20),
            Container(height: 40, color: Colors.black87),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    color: Colors.white,
                    child: Text(
                      widget.cvv.isEmpty ? 'CVV' : widget.cvv,
                      style: const TextStyle(
                          color: Colors.black,
                          letterSpacing: 2,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Código de segurança (verso)',
                textAlign: TextAlign.right,
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
