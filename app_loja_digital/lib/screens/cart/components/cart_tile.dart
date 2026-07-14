import 'package:app_loja_digital/common/custom_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:app_loja_digital/models/cart_product.dart';
import 'package:provider/provider.dart';
import 'package:app_loja_digital/models/cart_manager.dart';

class CartTile extends StatelessWidget {
  const CartTile(this.cartProduct, {super.key});

  final CartProduct cartProduct;

  @override
  Widget build(BuildContext context) {
    final cartManager = context.read<CartManager>();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: <Widget>[
            SizedBox(
              height: 80,
              width: 80,
              child: cartProduct.product == null
                  ? Container(
                      color: Colors.grey[200],
                      child: const Center(child: CircularProgressIndicator()),
                    )
                  : (cartProduct.product!.images.isNotEmpty
                      ? Image.network(
                          cartProduct.product!.images.first,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.image_not_supported),
                        )),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      cartProduct.product?.name ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 17.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tamanho: ${cartProduct.size}',
                      style: const TextStyle(fontWeight: FontWeight.w300),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'R\$ ${cartProduct.unitPrice.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Column(
              children: <Widget>[
                CustomIconButton(
                  iconData: Icons.add,
                  color: Theme.of(context).primaryColor,
                  onTap: () => cartManager.increment(cartProduct),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Text(
                    '${cartProduct.quantity}',
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
                CustomIconButton(
                  iconData: Icons.remove,
                  color: Theme.of(context).primaryColor,
                  onTap: () => cartManager.decrement(cartProduct),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
