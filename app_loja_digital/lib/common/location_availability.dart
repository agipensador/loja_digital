import 'package:app_loja_digital/models/product.dart';
import 'package:app_loja_digital/models/stores_manager.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// "Disponível na sua loja" / "Disponível em São Paulo — envio ou retirada".
/// Mostra o produto mesmo quando ele não está na unidade do cliente, para a
/// loja não perder a venda. Some quando a loja tem uma unidade só.
class LocationAvailability extends StatelessWidget {
  const LocationAvailability(this.product, {super.key, this.compact = false});

  final Product product;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final stores = context.watch<StoresManager>();
    if (!stores.isMultiLocation || product.isOutOfStock) {
      return const SizedBox.shrink();
    }

    final current = stores.currentLocation;
    final String text;
    final Color color;
    if (product.hasStockAt(current.id!)) {
      text = compact
          ? current.name
          : 'Disponível na loja ${current.name}';
      color = Colors.green.shade700;
    } else {
      final others = product.locationsWithStock.map(stores.nameOf).join(', ');
      text = compact
          ? 'Em $others'
          : 'Disponível em $others — envio ou retirada na loja';
      color = Colors.orange.shade800;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.storefront, size: compact ? 14 : 18, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: TextStyle(fontSize: compact ? 11 : 14, color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
