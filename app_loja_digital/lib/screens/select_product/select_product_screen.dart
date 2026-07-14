import 'package:app_loja_digital/models/product.dart';
import 'package:app_loja_digital/models/product_manager.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Retorna via Navigator.pop o [Product] escolhido (ou null se cancelar).
class SelectProductScreen extends StatelessWidget {
  const SelectProductScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final products = context.watch<ProductManager>().allProducts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vincular produto'),
        centerTitle: true,
      ),
      backgroundColor: Colors.white,
      body: ListView.builder(
        itemCount: products.length,
        itemBuilder: (_, index) {
          final Product product = products[index];
          return ListTile(
            leading: product.images.isNotEmpty
                ? Image.network(product.images.first,
                    width: 40, height: 40, fit: BoxFit.cover)
                : const Icon(Icons.image_not_supported),
            title: Text(product.name),
            subtitle: Text(product.category),
            onTap: () => Navigator.of(context).pop(product),
          );
        },
      ),
    );
  }
}
