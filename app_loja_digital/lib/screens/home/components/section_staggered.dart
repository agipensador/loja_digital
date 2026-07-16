import 'package:app_loja_digital/models/section.dart';
import 'package:app_loja_digital/screens/home/components/section_item_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

class SectionStaggered extends StatelessWidget {
  const SectionStaggered(this.section, {super.key});

  final Section section;

  // Padrão de tiles (cross, main) que se repete.
  static const List<List<int>> _pattern = [
    [2, 2],
    [2, 1],
    [2, 1],
    [2, 2],
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Colunas conforme a largura (tiles têm 2 células de largura).
        final w = constraints.maxWidth;
        final crossAxisCount = w >= 1000 ? 8 : (w >= 640 ? 6 : 4);

        return StaggeredGrid.count(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          children: List.generate(section.items.length, (index) {
            final tile = _pattern[index % _pattern.length];
            return StaggeredGridTile.count(
              crossAxisCellCount: tile[0],
              mainAxisCellCount: tile[1],
              child: SectionItemTile(section.items[index]),
            );
          }),
        );
      },
    );
  }
}
