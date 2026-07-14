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
    return StaggeredGrid.count(
      crossAxisCount: 4,
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      children: List.generate(section.items.length, (index) {
        final SectionItem item = section.items[index];
        final tile = _pattern[index % _pattern.length];
        return StaggeredGridTile.count(
          crossAxisCellCount: tile[0],
          mainAxisCellCount: tile[1],
          child: GestureDetector(
            onTap: () {
              if (item.product != null) {
                final product = context
                    .read<ProductManager>()
                    .findProductById(item.product!);
                if (product != null) {
                  Navigator.of(context)
                      .pushNamed('/product', arguments: product);
                }
              }
            },
            child: item.image is String
                ? Image.network(item.image as String, fit: BoxFit.cover)
                : Container(color: Colors.white24),
          ),
        );
      }),
    );
  }
}
