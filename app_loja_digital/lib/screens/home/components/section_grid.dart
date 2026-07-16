import 'package:app_loja_digital/models/section.dart';
import 'package:app_loja_digital/screens/home/components/section_item_tile.dart';
import 'package:flutter/material.dart';

/// Mosaico: grade uniforme de imagens quadradas que se espalha e ajusta a
/// quantidade por linha conforme a largura (como a lista de produtos).
class SectionGrid extends StatelessWidget {
  const SectionGrid(this.section, {super.key});

  final Section section;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final cols = w >= 1100
            ? 6
            : w >= 850
                ? 5
                : w >= 600
                    ? 4
                    : 3;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
          ),
          itemCount: section.items.length,
          itemBuilder: (_, index) => SectionItemTile(section.items[index]),
        );
      },
    );
  }
}
