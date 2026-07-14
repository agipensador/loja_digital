import 'package:app_loja_digital/screens/products/components/product_list_tile.dart';
import 'package:app_loja_digital/screens/products/components/search_dialog.dart';
import 'package:app_loja_digital/models/user_manager.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_loja_digital/common/custom_drawer/custom_drawer.dart';
import 'package:app_loja_digital/models/product_manager.dart';

class ProductsScreen extends StatelessWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const CustomDrawer(),
      appBar: AppBar(
        title: Consumer<ProductManager>(
          builder: (_ , productManager , __){
            if(productManager.search.isEmpty){
              return const Text('Produtos');
            }else {
              return LayoutBuilder(
                builder: (_ , constraints){
                  return GestureDetector(
                    onTap:() async{
                      final search = await showDialog<String>(context: context,
                      builder: (_) => SearchDialog(
                          productManager.search
                        )
                      );
                      if(search != null) {
                        productManager.search = search;
                  }
                },
                child: SizedBox(
                  width: constraints.biggest.width,
                  child: Text(
                    productManager.search,
                    textAlign: TextAlign.center,
                    ),
                )
                
                );
               }
             );
            }
           }
          ),
        centerTitle: true,
        actions: <Widget>[
          Consumer<ProductManager>(
            builder: (_, productManager ,__) {
              if (productManager.search.isEmpty) {
                      return IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () async {
                    final productManager = context.read<ProductManager>();
                    final search = await showDialog<String>(
                      context: context,
                      builder: (_) => SearchDialog(
                        productManager.search
                      )
                    );
                    if (search != null) {
                      productManager.search = search;
                    }
                  }
                );
              } else {
                 return IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () async {
                      productManager.search = '';
                    }
                );
              }
            },
          ),
          Consumer<UserManager>(
            builder: (_, userManager, __) {
              if (userManager.adminEnabled) {
                return IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Novo produto',
                  onPressed: () {
                    Navigator.of(context)
                        .pushNamed('/edit_product', arguments: null);
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer<ProductManager>(
        builder: (_, productManager, __) {
          final categories = productManager.categories;
          final filteredProducts = productManager.filteredProducts;
          return Column(
            children: <Widget>[
              if (categories.length > 1)
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    children: <Widget>[
                      _CategoryChip(
                        label: 'Todos',
                        selected: productManager.categoryFilter.isEmpty,
                        onTap: () => productManager.categoryFilter = '',
                      ),
                      for (final category in categories)
                        _CategoryChip(
                          label: category,
                          selected:
                              productManager.categoryFilter == category,
                          onTap: () =>
                              productManager.categoryFilter = category,
                        ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(4),
                  itemCount: filteredProducts.length,
                  itemBuilder: (_, index) {
                    return ProductListTile(filteredProducts[index]);
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.white,
        foregroundColor: Theme.of(context).primaryColor,
        onPressed: (){
          Navigator.of(context).pushNamed('/cart');
        },
        child: Icon(Icons.shopping_cart),
    ),
   );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}