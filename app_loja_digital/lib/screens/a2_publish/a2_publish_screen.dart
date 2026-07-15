import 'package:app_loja_digital/models/a2_offer.dart';
import 'package:app_loja_digital/models/a2_publish_manager.dart';
import 'package:app_loja_digital/models/product.dart';
import 'package:app_loja_digital/models/product_manager.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class A2PublishScreen extends StatelessWidget {
  const A2PublishScreen({super.key});

  Color _statusColor(A2Status s) {
    switch (s) {
      case A2Status.approved:
        return Colors.green;
      case A2Status.rejected:
        return Colors.red;
      case A2Status.pending:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Publicar no A2'), centerTitle: true),
      body: Consumer2<A2PublishManager, ProductManager>(
        builder: (_, a2, productManager, __) {
          final products = productManager.allProducts;
          return Column(
            children: <Widget>[
              Container(
                width: double.infinity,
                color: primaryColor.withAlpha(20),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${a2.count} de ${A2PublishManager.maxOffers} produtos publicados',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Escolha até 10 produtos para enviar ao app A2. '
                      'Cada envio entra "Em análise" — o A2 aprova ou rejeita '
                      'o que aparece lá. A loja continua independente.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: products.length,
                  itemBuilder: (_, index) {
                    final Product product = products[index];
                    final bool published = a2.isPublished(product.id!);
                    final offer = a2.offerFor(product.id!);
                    final bool canToggleOn = published || a2.canPublishMore;

                    return ListTile(
                      leading: product.images.isNotEmpty
                          ? Image.network(product.images.first,
                              width: 48, height: 48, fit: BoxFit.cover)
                          : const Icon(Icons.image_not_supported),
                      title: Text(product.name),
                      subtitle: published && offer != null
                          ? Row(
                              children: <Widget>[
                                Icon(Icons.circle,
                                    size: 10,
                                    color: _statusColor(offer.status)),
                                const SizedBox(width: 4),
                                Text(offer.statusLabel,
                                    style: TextStyle(
                                        color: _statusColor(offer.status))),
                              ],
                            )
                          : Text('R\$ ${product.basePrice.toStringAsFixed(2)}'),
                      trailing: Switch(
                        value: published,
                        onChanged: canToggleOn
                            ? (v) {
                                if (v) {
                                  a2.publish(product);
                                } else {
                                  a2.unpublish(product.id!);
                                }
                              }
                            : null,
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
