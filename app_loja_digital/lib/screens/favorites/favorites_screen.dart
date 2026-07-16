import 'package:app_loja_digital/common/custom_drawer/custom_drawer.dart';
import 'package:app_loja_digital/models/favorites_manager.dart';
import 'package:app_loja_digital/models/product.dart';
import 'package:app_loja_digital/models/product_manager.dart';
import 'package:app_loja_digital/models/theme_manager.dart';
import 'package:app_loja_digital/screens/products/components/product_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const CustomDrawer(),
      appBar: AppBar(
        title: const Text('Favoritos'),
        centerTitle: true,
      ),
      body: Consumer2<FavoritesManager, ProductManager>(
        builder: (_, favorites, productManager, __) {
          if (!favorites.isLoggedIn) {
            return const _Message('Entre para salvar seus favoritos.');
          }

          final List<Product> products = favorites.ids
              .map((id) => productManager.findProductById(id))
              .whereType<Product>()
              .where((p) => !p.deleted)
              .toList();

          if (products.isEmpty) {
            return const _Message(
              'Você ainda não favoritou nada.\n'
              'Toque no ♥ de um produto para salvá-lo aqui.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(4),
            itemCount: products.length,
            itemBuilder: (_, index) => ProductListTile(products[index]),
          );
        },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final onBg =
        ThemeManager.onColor(context.watch<ThemeManager>().background);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: onBg, fontSize: 16),
        ),
      ),
    );
  }
}
