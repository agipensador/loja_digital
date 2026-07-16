import 'package:app_loja_digital/models/section.dart';
import 'package:app_loja_digital/screens/home/components/section_item_tile.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';

/// Carrossel: banners largos que passam automaticamente/deslizando, com
/// indicador de bolinhas. Ótimo para destaques e promoções.
class SectionCarousel extends StatefulWidget {
  const SectionCarousel(this.section, {super.key});

  final Section section;

  @override
  State<SectionCarousel> createState() => _SectionCarouselState();
}

class _SectionCarouselState extends State<SectionCarousel> {
  int _current = 0;

  @override
  Widget build(BuildContext context) {
    final items = widget.section.items;
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      children: <Widget>[
        CarouselSlider(
          options: CarouselOptions(
            aspectRatio: 16 / 7,
            viewportFraction: 0.92,
            enableInfiniteScroll: items.length > 1,
            autoPlay: items.length > 1,
            autoPlayInterval: const Duration(seconds: 4),
            enlargeCenterPage: true,
            onPageChanged: (i, _) => setState(() => _current = i),
          ),
          items: items.map((item) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: SectionItemTile(item, radius: 10),
            );
          }).toList(),
        ),
        if (items.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(items.length, (index) {
                final active = index == _current;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: active ? 18 : 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: active ? Colors.white : Colors.white54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}
