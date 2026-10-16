import 'package:app_loja_digital/models/product.dart';
import 'package:app_loja_digital/models/product_manager.dart';
import 'package:app_loja_digital/models/stores_manager.dart';
import 'package:app_loja_digital/models/supplier.dart';
import 'package:app_loja_digital/models/tenant_manager.dart';
import 'package:app_loja_digital/models/theme_manager.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Pedido de reposição da unidade [locationId]: itens baixos/esgotados
/// agrupados por fornecedor, quantidade editável, e um botão que abre o
/// WhatsApp do fornecedor com a mensagem pronta.
class RestockScreen extends StatefulWidget {
  const RestockScreen(this.locationId, {super.key});

  final String locationId;

  @override
  State<RestockScreen> createState() => _RestockScreenState();
}

class _RestockScreenState extends State<RestockScreen> {
  /// Quantidade a pedir por produto+variante ("pid|tamanho").
  final Map<String, int> _qty = {};

  int _suggested(Product p, int stock) {
    final target = p.lowStockThreshold * 2;
    return target - stock > 0 ? target - stock : 1;
  }

  Future<void> _send(Supplier supplier, List<Product> products) async {
    final stores = context.read<StoresManager>();
    final items = <RestockItem>[
      for (final p in products)
        for (final s in p.sizes)
          if (s.stockAt(widget.locationId) <= p.lowStockThreshold)
            RestockItem(
              label: s.name.isEmpty ? p.name : '${p.name} (${s.name})',
              quantity: _qty['${p.id}|${s.name}'] ??
                  _suggested(p, s.stockAt(widget.locationId)),
            ),
    ];
    final storeName = context.read<TenantManager>().store?.name.isNotEmpty ==
            true
        ? context.read<TenantManager>().store!.name
        : context.read<ThemeManager>().storeName;
    final message = RestockMessage.text(
      supplier: supplier,
      storeName: storeName,
      locationName: stores.nameOf(widget.locationId),
      items: items,
    );
    await launchUrl(RestockMessage.link(supplier, message),
        mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final products = context
        .watch<ProductManager>()
        .allProducts
        .where((p) => p.needsRestockAt(widget.locationId))
        .toList();
    final suppliers = context.watch<SuppliersManager>();
    final locationName = context.watch<StoresManager>().nameOf(widget.locationId);

    final Map<String?, List<Product>> bySupplier = {};
    for (final p in products) {
      final key = suppliers.byId(p.supplierId) == null ? null : p.supplierId;
      bySupplier.putIfAbsent(key, () => []).add(p);
    }

    return Scaffold(
      appBar: AppBar(title: Text('Reposição · $locationName')),
      body: products.isEmpty
          ? const Center(child: Text('Nenhum produto precisa de reposição.'))
          : ListView(
              children: <Widget>[
                for (final entry in bySupplier.entries)
                  _SupplierGroup(
                    supplier: suppliers.byId(entry.key),
                    products: entry.value,
                    locationId: widget.locationId,
                    qty: _qty,
                    suggested: _suggested,
                    onChanged: () => setState(() {}),
                    onSend: (s) => _send(s, entry.value),
                  ),
              ],
            ),
    );
  }
}

class _SupplierGroup extends StatelessWidget {
  const _SupplierGroup({
    required this.supplier,
    required this.products,
    required this.locationId,
    required this.qty,
    required this.suggested,
    required this.onChanged,
    required this.onSend,
  });

  final Supplier? supplier;
  final List<Product> products;
  final String locationId;
  final Map<String, int> qty;
  final int Function(Product, int) suggested;
  final VoidCallback onChanged;
  final ValueChanged<Supplier> onSend;

  @override
  Widget build(BuildContext context) {
    final s = supplier;
    return Card(
      margin: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ListTile(
            title: Text(s?.name ?? 'Sem fornecedor vinculado',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(s == null
                ? 'Vincule um fornecedor no cadastro do produto.'
                : s.hasWhatsapp
                    ? 'WhatsApp ${s.whatsapp}'
                    : 'Cadastre o WhatsApp do fornecedor.'),
          ),
          for (final p in products)
            for (final size in p.sizes)
              if (size.stockAt(locationId) <= p.lowStockThreshold)
                ListTile(
                  dense: true,
                  title: Text(size.name.isEmpty
                      ? p.name
                      : '${p.name} (${size.name})'),
                  subtitle: Text('Em estoque: ${size.stockAt(locationId)}'),
                  trailing: SizedBox(
                    width: 80,
                    child: TextFormField(
                      initialValue:
                          '${qty['${p.id}|${size.name}'] ?? suggested(p, size.stockAt(locationId))}',
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                          labelText: 'Pedir', isDense: true),
                      onChanged: (v) {
                        qty['${p.id}|${size.name}'] = int.tryParse(v) ?? 0;
                        onChanged();
                      },
                    ),
                  ),
                ),
          if (s != null && s.hasWhatsapp)
            Padding(
              padding: const EdgeInsets.all(12),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.chat),
                label: const Text('Pedir no WhatsApp'),
                onPressed: () => onSend(s),
              ),
            ),
        ],
      ),
    );
  }
}
