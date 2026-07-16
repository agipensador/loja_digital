import 'package:app_loja_digital/models/product.dart';
import 'package:flutter/material.dart';

/// Selo de estoque: "Esgotado" (vermelho) ou "Restam N" (laranja) quando o
/// produto está baixo. Nada quando há estoque suficiente ou sem produto.
class StockBadge extends StatelessWidget {
  const StockBadge(this.product, {super.key});

  final Product? product;

  @override
  Widget build(BuildContext context) {
    final p = product;
    if (p == null || p.deleted) return const SizedBox.shrink();

    String text;
    Color color;
    if (p.isOutOfStock) {
      text = 'Esgotado';
      color = Colors.red;
    } else if (p.isLowStock) {
      text = 'Restam ${p.totalStock}';
      color = Colors.orange.shade800;
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
