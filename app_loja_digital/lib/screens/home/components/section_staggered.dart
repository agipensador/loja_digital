import 'package:app_loja_digital/common/stock_badge.dart';
import 'package:app_loja_digital/common/store_image.dart';
import 'package:app_loja_digital/models/product_manager.dart';
import 'package:app_loja_digital/models/section.dart';
import 'package:app_loja_digital/models/section_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';

class SectionStaggered extends StatelessWidget {
  const SectionStaggered(this.section, {super.key});

  final Section section;

  // Padrão de tiles (cross, main) que se repete e preenche 4 colunas.
  static const List<List<int>> _pattern = [
    [2, 2],
    [2, 1],
    [2, 1],
    [2, 2],
  ];

  @override
  Widget build(BuildContext context) {
    final productManager = context.watch<ProductManager>();
    return StaggeredGrid.count(
      crossAxisCount: 4,
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      children: List.generate(section.items.length, (index) {
        final SectionItem item = section.items[index];
        final tile = _pattern[index % _pattern.length];
        final product = item.product != null
            ? productManager.findProductById(item.product!)
            : null;
        return StaggeredGridTile.count(
          crossAxisCellCount: tile[0],
          mainAxisCellCount: tile[1],
          child: GestureDetector(
            onTap: () {
              if (product != null) {
                Navigator.of(context)
                    .pushNamed('/product', arguments: product);
              }
            },
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                StoreImage(
                  item.image is String ? item.image as String : null,
                ),
                Positioned(
                  top: 4,
                  left: 4,
                  child: StockBadge(product),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
