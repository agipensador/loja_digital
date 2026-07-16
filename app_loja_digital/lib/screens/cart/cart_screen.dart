import 'package:app_loja_digital/common/nav_pages.dart';
import 'package:app_loja_digital/common/price_card.dart';
import 'package:app_loja_digital/models/cart_manager.dart';
import 'package:app_loja_digital/models/page_manager.dart';
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
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.shopping_cart_outlined,
                        size: 72, color: Colors.white.withAlpha(180)),
                    const SizedBox(height: 16),
                    const Text(
                      'Seu carrinho está vazio',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Adicione produtos para continuar a compra.\n'
                      'Que tal começar pelos seus favoritos?',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, color: Colors.white70),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Theme.of(context).primaryColor,
                      ),
                      icon: const Icon(Icons.favorite),
                      label: const Text('Ver meus favoritos'),
                      onPressed: () {
                        // Volta à base e abre a página de Favoritos (menu).
                        context
                            .read<PageManager>()
                            .setPage(NavPages.favoritos);
                        Navigator.of(context)
                            .popUntil((r) => r.isFirst);
                      },
                    ),
                  ],
                ),
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
                onPressed: cartManager.isCartValid
                    ? () {
                        Navigator.of(context).pushNamed('/address');
                      }
                    : null,
              ),
            ],
          );
        },
      ),
    );
  }
}
