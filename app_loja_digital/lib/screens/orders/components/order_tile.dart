import 'package:app_loja_digital/models/order.dart';
import 'package:flutter/material.dart';

class OrderTile extends StatelessWidget {
  const OrderTile(this.order, {super.key, this.showControls = false});

  final Order order;
  final bool showControls;

  Color _statusColor(BuildContext context) {
    switch (order.status) {
      case Status.canceled:
        return Colors.red;
      case Status.delivered:
        return Colors.green;
      default:
        return Theme.of(context).primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ExpansionTile(
        initiallyExpanded: showControls,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  order.formattedId,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                Text('R\$ ${order.price.toStringAsFixed(2)}'),
              ],
            ),
            Text(
              order.statusText,
              style: TextStyle(
                color: _statusColor(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        children: <Widget>[
          for (final item in order.itemsData)
            ListTile(
              leading: (item['image'] as String?)?.isNotEmpty == true
                  ? Image.network(item['image'] as String,
                      width: 48, height: 48, fit: BoxFit.cover)
                  : const Icon(Icons.image_not_supported),
              title: Text((item['name'] ?? '') as String),
              subtitle: Text('Tamanho: ${item['size'] ?? ''}\n'
                  'R\$ ${((item['price'] ?? 0) as num).toStringAsFixed(2)}'),
              trailing: Text('${item['quantity'] ?? 0}x'),
              isThreeLine: true,
            ),
          if (showControls && order.status != Status.canceled)
            _AdminControls(order),
        ],
      ),
    );
  }
}

class _AdminControls extends StatefulWidget {
  const _AdminControls(this.order);
  final Order order;

  @override
  State<_AdminControls> createState() => _AdminControlsState();
}

class _AdminControlsState extends State<_AdminControls> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    await action();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;

    if (_busy) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return OverflowBar(
      alignment: MainAxisAlignment.end,
      children: <Widget>[
        TextButton(
          onPressed: () => _run(order.cancel),
          child: const Text('Cancelar',
              style: TextStyle(color: Colors.red)),
        ),
        TextButton(
          onPressed: order.status == Status.preparing
              ? null
              : () => _run(order.backStatus),
          child: const Text('Recuar'),
        ),
        TextButton(
          onPressed: order.status == Status.delivered
              ? null
              : () => _run(order.advanceStatus),
          child: const Text('Avançar'),
        ),
      ],
    );
  }
}
