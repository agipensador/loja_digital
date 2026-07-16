import 'package:app_loja_digital/models/section.dart';
import 'package:app_loja_digital/screens/home/components/section_item_tile.dart';
import 'package:flutter/material.dart';

class SectionList extends StatelessWidget {
  const SectionList(this.section, {super.key});

  final Section section;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 2),
        itemCount: section.items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          // Card um pouco mais alto que largo.
          return AspectRatio(
            aspectRatio: 0.8,
            child: SectionItemTile(section.items[index]),
          );
        },
      ),
    );
  }
}
