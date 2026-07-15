import 'package:app_loja_digital/models/product.dart';
import 'package:app_loja_digital/models/product_manager.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Retorna via Navigator.pop o [Product] escolhido (ou null se cancelar).
/// Permite também criar um produto novo ali mesmo.
class SelectProductScreen extends StatelessWidget {
  const SelectProductScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final products = context.watch<ProductManager>().allProducts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vincular produto'),
        centerTitle: true,
      ),
      backgroundColor: Colors.white,
      body: Column(
        children: <Widget>[
          ListTile(
            leading: CircleAvatar(
              backgroundColor: primaryColor,
              child: const Icon(Icons.add, color: Colors.white),
            ),
            title: const Text('Criar novo produto'),
            subtitle: const Text('Cadastre e já vincule à imagem'),
            onTap: () async {
              // Cria um produto novo; ao voltar, ele aparece na lista abaixo
              // para ser selecionado.
              await Navigator.of(context)
                  .pushNamed('/edit_product', arguments: null);
            },
          ),
          const Divider(height: 1),
          Expanded(
            child: products.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Nenhum produto ainda.\n'
                        'Toque em "Criar novo produto" acima.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
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
          ),
        ],
      ),
    );
  }
}
