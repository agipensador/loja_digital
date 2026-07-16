import 'package:app_loja_digital/common/stock_badge.dart';
import 'package:app_loja_digital/common/store_image.dart';
import 'package:app_loja_digital/models/product_manager.dart';
import 'package:app_loja_digital/models/section_item.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Imagem de uma seção da home: cantos arredondados, selo de estoque e
/// link para o produto vinculado (se houver). Reutilizado por todos os
/// formatos de exibição (lista, grade, mosaico, carrossel).
class SectionItemTile extends StatelessWidget {
  const SectionItemTile(this.item, {super.key, this.radius = 6});

  final SectionItem item;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final product = item.product != null
        ? context.watch<ProductManager>().findProductById(item.product!)
        : null;

    return GestureDetector(
      onTap: product != null
          ? () => Navigator.of(context)
              .pushNamed('/product', arguments: product)
          : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            StoreImage(item.image is String ? item.image as String : null),
            Positioned(
              top: 4,
              left: 4,
              child: StockBadge(product),
            ),
          ],
        ),
      ),
    );
  }
}
