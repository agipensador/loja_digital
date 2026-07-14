import 'package:app_loja_digital/models/item_size.dart';
import 'package:app_loja_digital/models/product.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SizeWidget extends StatelessWidget {
  const SizeWidget({super.key, required this.size});

  final ItemSize size;

  @override
  Widget build(BuildContext context) {
    final product = context.watch<Product>();
    final selected = size == product.selectedSize;

    Color color;
    if (!size.hasStock) {
      color = Colors.red.withAlpha(50);
    } else if (selected) {
      color = Theme.of(context).primaryColor;
    } else {
      color = Colors.grey;
    }

    return GestureDetector(
      onTap: () {
        if (size.hasStock) {
          product.selectedSize = size;
        }
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              color: color,
              padding:
                  const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: Text(
                size.name,
                style: const TextStyle(color: Colors.white),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'R\$ ${size.price.toStringAsFixed(2)}',
                style: TextStyle(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
