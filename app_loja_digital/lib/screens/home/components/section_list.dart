import 'package:app_loja_digital/common/stock_badge.dart';
import 'package:app_loja_digital/common/store_image.dart';
import 'package:app_loja_digital/models/product_manager.dart';
import 'package:app_loja_digital/models/section.dart';
import 'package:app_loja_digital/models/section_item.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SectionList extends StatelessWidget {
  const SectionList(this.section, {super.key});

  final Section section;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: section.items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 4),
        itemBuilder: (context, index) {
          final SectionItem item = section.items[index];
          final product = item.product != null
              ? context.watch<ProductManager>().findProductById(item.product!)
              : null;
          return GestureDetector(
            onTap: () {
              if (product != null) {
                Navigator.of(context)
                    .pushNamed('/product', arguments: product);
              }
            },
            child: AspectRatio(
              aspectRatio: 1,
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
        },
      ),
    );
  }
}
