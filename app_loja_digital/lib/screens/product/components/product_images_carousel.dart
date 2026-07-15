import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';

/// Carrossel de imagens do produto com indicador de bolinhas (posição atual
/// e total), exibido apenas quando há mais de uma imagem.
class ProductImagesCarousel extends StatefulWidget {
  const ProductImagesCarousel(this.images, {super.key});

  final List<String> images;

  @override
  State<ProductImagesCarousel> createState() => _ProductImagesCarouselState();
}

class _ProductImagesCarouselState extends State<ProductImagesCarousel> {
  int _current = 0;

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final size = MediaQuery.of(context).size.width;

    if (widget.images.isEmpty) {
      return Container(
        height: size,
        color: Colors.grey[200],
        alignment: Alignment.center,
        child: const Icon(Icons.image_not_supported,
            size: 64, color: Colors.grey),
      );
    }

    return Column(
      children: <Widget>[
        CarouselSlider(
          options: CarouselOptions(
            height: size,
            enableInfiniteScroll: false,
            viewportFraction: 1,
            onPageChanged: (index, _) => setState(() => _current = index),
          ),
          items: widget.images.map((url) {
            return Image.network(
              url,
              fit: BoxFit.cover,
              width: double.infinity,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFFEDEDED),
                alignment: Alignment.center,
                child: Icon(Icons.image_outlined,
                    color: Colors.grey[400], size: 48),
              ),
            );
          }).toList(),
        ),
        if (widget.images.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.images.length, (index) {
                final bool active = index == _current;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: active ? 20 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: active ? primaryColor : Colors.grey[300],
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
