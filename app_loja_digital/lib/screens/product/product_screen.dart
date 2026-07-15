import 'package:app_loja_digital/models/cart_manager.dart';
import 'package:app_loja_digital/models/favorites_manager.dart';
import 'package:app_loja_digital/screens/product/components/product_images_carousel.dart';
import 'package:app_loja_digital/screens/product/components/size_widget.dart';
import 'package:flutter/material.dart';
import 'package:app_loja_digital/models/product.dart';
import 'package:app_loja_digital/models/user_manager.dart';
import 'package:provider/provider.dart';

class ProductScreen extends StatelessWidget {
  const ProductScreen(this.product, {super.key});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return ChangeNotifierProvider.value(
      value: product,
      child: Scaffold(
        appBar: AppBar(
          title: Text(product.name),
          centerTitle: true,
          actions: <Widget>[
            Consumer2<UserManager, FavoritesManager>(
              builder: (_, userManager, favorites, __) {
                final bool fav =
                    product.id != null && favorites.isFavorite(product.id!);
                return IconButton(
                  icon: Icon(fav ? Icons.favorite : Icons.favorite_border),
                  color: fav ? Colors.redAccent : null,
                  tooltip: 'Favoritar',
                  onPressed: () {
                    if (!userManager.isLoggedIn) {
                      Navigator.of(context).pushNamed('/login');
                      return;
                    }
                    if (product.id != null) favorites.toggle(product.id!);
                  },
                );
              },
            ),
            Consumer<UserManager>(
              builder: (_, userManager, __) {
                if (userManager.adminEnabled && !product.deleted) {
                  return IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      Navigator.of(context).pushNamed(
                        '/edit_product',
                        arguments: product,
                      );
                    },
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
        backgroundColor: Colors.white,
        body: ListView(
          children: <Widget>[
            ProductImagesCarousel(product.images),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'A partir de',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Text(
                    'R\$ ${product.basePrice.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 22.0,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 16, bottom: 8),
                    child: Text(
                      'Descrição',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    product.description,
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  product.sizes.map((s) => SizeWidget(size: s)).toList(),
            ),
            const SizedBox(height: 20),
            if (product.hasStock)
              Consumer2<UserManager, Product>(
                builder: (_, userManager, product, __) {
                  return SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: product.selectedSize != null
                          ? () {
                              if (userManager.isLoggedIn) {
                                context
                                    .read<CartManager>()
                                    .addToCart(product);
                                Navigator.of(context).pushNamed('/cart');
                              } else {
                                Navigator.of(context).pushNamed('/login');
                              }
                            }
                          : null,
                      child: Text(
                        userManager.isLoggedIn
                            ? 'Adicionar ao Carrinho'
                            : 'Entre para Comprar',
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
