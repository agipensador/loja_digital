import 'package:app_loja_digital/common/price_card.dart';
import 'package:app_loja_digital/models/cart_manager.dart';
import 'package:app_loja_digital/screens/cart/components/cart_tile.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Carrinho'),
        centerTitle: true,
      ),
      body: Consumer<CartManager>(
        builder: (_, cartManager, __) {
          if (cartManager.items.isEmpty) {
            return const Center(
              child: Text(
                'Seu carrinho está vazio :(',
                style: TextStyle(fontSize: 18),
              ),
            );
          }

          return ListView(
            children: <Widget>[
              Column(
                children:
                    cartManager.items.map((cartProduct) => CartTile(cartProduct)).toList(),
              ),
              PriceCard(
                buttonText: 'Continuar para Entrega',
                onPressed: (){
                  
                }
                /*
                    cartManager.isCartValid
                        ? () {

                          }
                        : null,
                */                        
              ),
            ],
          );
        },
      ),
    );
  }
}
