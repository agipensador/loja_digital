import 'package:app_loja_digital/models/usage_manager.dart';
import 'package:app_loja_digital/models/tenant_manager.dart';
import 'package:app_loja_digital/models/stores_manager.dart';
import 'package:app_loja_digital/models/staff_member.dart';
import 'package:app_loja_digital/screens/products/components/product_grid_tile.dart';
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
              if (userManager.can(Perm.productsCreate)) {
                return IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Novo produto',
                  onPressed: () {
                    final plan = context.read<TenantManager>().store?.plan;
                    final report = plan == null
                        ? null
                        : context.read<UsageManager>().report(plan,
                            context.read<ProductManager>().allProducts.length);
                    if (report != null && report.capReached) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Sua loja chegou ao teto de uso do '
                              'plano: novos produtos estão pausados. Veja em '
                              'Perfil → Assinatura.'),
                        ),
                      );
                      return;
                    }
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
      body: Consumer2<ProductManager, StoresManager>(
        builder: (_, productManager, stores, __) {
          final categories = productManager.categories;
          final current = stores.currentLocationId;
          // Produtos da unidade do cliente primeiro; os das outras unidades
          // continuam visíveis ("disponível em X") para não perder a venda.
          final filteredProducts = productManager.filteredProducts
            ..sort((a, b) {
              final ah = a.hasStockAt(current) ? 0 : 1;
              final bh = b.hasStockAt(current) ? 0 : 1;
              return ah.compareTo(bh);
            });
          return Column(
            children: <Widget>[
              if (stores.isMultiLocation)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.storefront, size: 18),
                      const SizedBox(width: 6),
                      const Text('Comprando na loja:'),
                      const SizedBox(width: 6),
                      DropdownButton<String>(
                        value: current,
                        underline: const SizedBox.shrink(),
                        items: stores.locations
                            .map((l) => DropdownMenuItem(
                                value: l.id, child: Text(l.name)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) stores.selectLocation(v);
                        },
                      ),
                    ],
                  ),
                ),
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
                child: LayoutBuilder(
                  builder: (_, constraints) {
                    final w = constraints.maxWidth;
                    // Colunas conforme a largura (responsivo web/mobile).
                    final cols = w >= 1100
                        ? 5
                        : w >= 850
                            ? 4
                            : w >= 600
                                ? 3
                                : 2;
                    return GridView.builder(
                      padding: const EdgeInsets.all(8),
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 0.72,
                      ),
                      itemCount: filteredProducts.length,
                      itemBuilder: (_, index) =>
                          ProductGridTile(filteredProducts[index]),
                    );
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