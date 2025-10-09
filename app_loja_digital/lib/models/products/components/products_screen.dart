import 'package:app_loja_digital/models/products/components/product_list_tile.dart';
import 'package:app_loja_digital/models/products/components/search_dialog.dart';
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
          )
          
        ],
      ),
      body: Consumer<ProductManager>(
        builder: (_, productManager, __) {
          final filteredProducts = productManager.filteredProducts;
          return ListView.builder(
            padding: const EdgeInsets.all(4),
            itemCount: filteredProducts.length,
            itemBuilder: (_, index) {
              return ProductListTile(filteredProducts[index]);
            },
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