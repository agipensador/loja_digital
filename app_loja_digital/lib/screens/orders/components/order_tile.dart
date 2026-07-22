import 'package:app_loja_digital/models/order.dart';
import 'package:app_loja_digital/screens/orders/components/order_timeline.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: OrderTimeline(order.status),
          ),
          if (order.shipping.hasInfo) _ShippingInfo(order),
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

/// Envio: método, código de rastreio (copiável) e botão "Rastrear".
class _ShippingInfo extends StatelessWidget {
  const _ShippingInfo(this.order);
  final Order order;

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final shipping = order.shipping;
    final trackingUrl = shipping.resolvedTrackingUrl;

    final subtitleParts = <String>[
      if (shipping.carrier.isNotEmpty) shipping.carrier,
      if (shipping.trackingCode.isNotEmpty) shipping.trackingCode,
    ];

    return ListTile(
      leading: Icon(
        shipping.method == 'motoboy'
            ? Icons.sports_motorsports
            : shipping.method == 'retirada'
                ? Icons.storefront
                : Icons.local_shipping,
        color: primaryColor,
      ),
      title: Text(
        shipping.methodLabel.isNotEmpty ? shipping.methodLabel : 'Envio',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle:
          subtitleParts.isEmpty ? null : Text(subtitleParts.join(' · ')),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (shipping.trackingCode.isNotEmpty)
            IconButton(
              tooltip: 'Copiar código',
              icon: const Icon(Icons.copy, size: 20),
              onPressed: () {
                Clipboard.setData(
                    ClipboardData(text: shipping.trackingCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Código copiado!')),
                );
              },
            ),
          if (trackingUrl != null)
            TextButton(
              onPressed: () => launchUrl(
                Uri.parse(trackingUrl),
                mode: LaunchMode.externalApplication,
              ),
              child: const Text('Rastrear'),
            ),
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

  /// Ao despachar (Em separação -> Em transporte), pergunta o método e o
  /// código de envio (Correios, motoboy...). Pode pular e informar depois.
  Future<void> _advance() async {
    final order = widget.order;
    if (order.status == Status.preparing) {
      final shipping = await _ShippingDialog.show(context, order.shipping);
      if (shipping == null) return; // cancelou o despacho
      await _run(() async {
        if (shipping.hasInfo) await order.setShipping(shipping);
        await order.advanceStatus();
      });
    } else {
      await _run(order.advanceStatus);
    }
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
        if (order.status == Status.transporting)
          TextButton(
            onPressed: () async {
              final shipping =
                  await _ShippingDialog.show(context, order.shipping);
              if (shipping != null) {
                await _run(() => order.setShipping(shipping));
              }
            },
            child: const Text('Editar envio'),
          ),
        TextButton(
          onPressed: order.status == Status.preparing
              ? null
              : () => _run(order.backStatus),
          child: const Text('Recuar'),
        ),
        TextButton(
          onPressed:
              order.status == Status.delivered ? null : _advance,
          child: const Text('Avançar'),
        ),
      ],
    );
  }
}

/// Formulário de despacho: método + transportadora/entregador + código/link.
class _ShippingDialog extends StatefulWidget {
  const _ShippingDialog(this.initial);
  final OrderShipping initial;

  static Future<OrderShipping?> show(
      BuildContext context, OrderShipping initial) {
    return showDialog<OrderShipping>(
      context: context,
      builder: (_) => _ShippingDialog(initial),
    );
  }

  @override
  State<_ShippingDialog> createState() => _ShippingDialogState();
}

class _ShippingDialogState extends State<_ShippingDialog> {
  late String _method;
  late final TextEditingController _carrier;
  late final TextEditingController _code;
  late final TextEditingController _url;

  @override
  void initState() {
    super.initState();
    _method = widget.initial.method.isEmpty
        ? 'correios'
        : widget.initial.method;
    _carrier = TextEditingController(text: widget.initial.carrier);
    _code = TextEditingController(text: widget.initial.trackingCode);
    _url = TextEditingController(text: widget.initial.trackingUrl);
  }

  @override
  void dispose() {
    _carrier.dispose();
    _code.dispose();
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Informações de envio'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            DropdownButtonFormField<String>(
              initialValue: _method,
              decoration: const InputDecoration(labelText: 'Método'),
              items: OrderShipping.methods.entries
                  .map((e) => DropdownMenuItem(
                      value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _method = v ?? 'correios'),
            ),
            TextField(
              controller: _carrier,
              decoration: const InputDecoration(
                labelText: 'Transportadora / entregador',
                hintText: 'PAC, SEDEX, nome do motoboy...',
              ),
            ),
            TextField(
              controller: _code,
              decoration: const InputDecoration(
                labelText: 'Código de rastreio',
                hintText: 'ex.: BR123456789BR',
              ),
            ),
            TextField(
              controller: _url,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Link de rastreio (opcional)',
                hintText: 'para Correios é gerado automático',
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(
          // Despacha sem código (permite informar depois em "Editar envio").
          onPressed: () =>
              Navigator.of(context).pop(OrderShipping(method: _method)),
          child: const Text('Pular'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(OrderShipping(
            method: _method,
            carrier: _carrier.text.trim(),
            trackingCode: _code.text.trim(),
            trackingUrl: _url.text.trim(),
          )),
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
