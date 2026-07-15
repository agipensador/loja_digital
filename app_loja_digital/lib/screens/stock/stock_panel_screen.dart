import 'package:app_loja_digital/common/store_image.dart';
import 'package:app_loja_digital/models/item_size.dart';
import 'package:app_loja_digital/models/product.dart';
import 'package:app_loja_digital/models/product_manager.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

enum _StockFilter { all, low, out }

class StockPanelScreen extends StatefulWidget {
  const StockPanelScreen({super.key});

  @override
  State<StockPanelScreen> createState() => _StockPanelScreenState();
}

class _StockPanelScreenState extends State<StockPanelScreen> {
  _StockFilter _filter = _StockFilter.all;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Controle de estoque'), centerTitle: true),
      body: Consumer<ProductManager>(
        builder: (_, productManager, __) {
          final all = productManager.allProducts;
          final low = all.where((p) => p.isLowStock).toList();
          final out = all.where((p) => p.isOutOfStock).toList();

          List<Product> visible;
          switch (_filter) {
            case _StockFilter.low:
              visible = low;
              break;
            case _StockFilter.out:
              visible = out;
              break;
            case _StockFilter.all:
              visible = List.of(all);
          }
          // Menor estoque primeiro: o que está acabando aparece no topo.
          visible.sort((a, b) => a.totalStock.compareTo(b.totalStock));

          return Column(
            children: <Widget>[
              _Summary(
                total: all.length,
                low: low.length,
                out: out.length,
                filter: _filter,
                onFilter: (f) => setState(() => _filter = f),
              ),
              Expanded(
                child: visible.isEmpty
                    ? const Center(child: Text('Nenhum produto aqui.'))
                    : ListView.builder(
                        itemCount: visible.length,
                        itemBuilder: (_, i) => _StockProductTile(
                          visible[i],
                          onChanged: () => setState(() {}),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.total,
    required this.low,
    required this.out,
    required this.filter,
    required this.onFilter,
  });

  final int total;
  final int low;
  final int out;
  final _StockFilter filter;
  final ValueChanged<_StockFilter> onFilter;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).primaryColor.withAlpha(15),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: <Widget>[
          _Chip('Todos', total, Colors.blueGrey,
              filter == _StockFilter.all, () => onFilter(_StockFilter.all)),
          const SizedBox(width: 8),
          _Chip('Estoque baixo', low, Colors.orange,
              filter == _StockFilter.low, () => onFilter(_StockFilter.low)),
          const SizedBox(width: 8),
          _Chip('Esgotado', out, Colors.red,
              filter == _StockFilter.out, () => onFilter(_StockFilter.out)),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.count, this.color, this.selected, this.onTap);
  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? color : color.withAlpha(30),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: <Widget>[
              Text('$count',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: selected ? Colors.white : color)),
              Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 11,
                      color: selected ? Colors.white : color)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StockProductTile extends StatefulWidget {
  const _StockProductTile(this.product, {required this.onChanged});
  final Product product;
  final VoidCallback onChanged;

  @override
  State<_StockProductTile> createState() => _StockProductTileState();
}

class _StockProductTileState extends State<_StockProductTile> {
  Product get p => widget.product;

  Future<void> _changeStock(ItemSize size, int delta) async {
    final v = size.stock + delta;
    size.stock = v < 0 ? 0 : v;
    setState(() {});
    widget.onChanged();
    await p.updateStock();
  }

  Future<void> _changeThreshold(int delta) async {
    await p.setLowStockThreshold(p.lowStockThreshold + delta);
    setState(() {});
    widget.onChanged();
  }

  Widget _badge() {
    if (p.isOutOfStock) {
      return const _Tag('Esgotado', Colors.red);
    }
    if (p.isLowStock) {
      return const _Tag('Estoque baixo', Colors.orange);
    }
    return const _Tag('OK', Colors.green);
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ExpansionTile(
        leading: SizedBox(
          width: 44,
          height: 44,
          child: StoreImage(p.images.isNotEmpty ? p.images.first : null),
        ),
        title: Text(p.name),
        subtitle: Row(
          children: <Widget>[
            Text('Total: ${p.totalStock}'),
            const SizedBox(width: 8),
            _badge(),
          ],
        ),
        children: <Widget>[
          for (final size in p.sizes)
            ListTile(
              dense: true,
              title: Text(size.name.isEmpty ? 'Único' : size.name),
              subtitle: Text('R\$ ${size.price.toStringAsFixed(2)}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    color: Colors.red,
                    onPressed: () => _changeStock(size, -1),
                  ),
                  SizedBox(
                    width: 32,
                    child: Text('${size.stock}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    color: primaryColor,
                    onPressed: () => _changeStock(size, 1),
                  ),
                  TextButton(
                    onPressed: () => _changeStock(size, 10),
                    child: const Text('+10'),
                  ),
                ],
              ),
            ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
            child: Row(
              children: <Widget>[
                const Expanded(
                  child: Text('Alertar quando o total ficar ≤'),
                ),
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: () => _changeThreshold(-1),
                ),
                Text('${p.lowStockThreshold}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _changeThreshold(1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(40),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
