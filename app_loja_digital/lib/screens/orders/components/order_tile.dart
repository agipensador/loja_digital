import 'package:app_loja_digital/common/store_image.dart';
import 'package:app_loja_digital/helpers/br_format.dart';
import 'package:app_loja_digital/core/tenant.dart';
import 'package:app_loja_digital/helpers/uber_link_helper.dart';
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

    // Cliente com proposta de troca esperando resposta: abre e sinaliza.
    final needsAnswer =
        !showControls && (order.deliveryChange?.isPending ?? false);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ExpansionTile(
        initiallyExpanded: showControls || needsAnswer,
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
                Text(Br.money(order.price)),
                if (needsAnswer)
                  const Text('Responda à proposta da loja',
                      style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
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
            child: OrderTimeline(order.status, pickup: order.shipping.isPickup),
          ),
          if (order.deliveryChange != null &&
              order.deliveryChange!.status != 'applied')
            _DeliveryChangeBanner(order, isAdmin: showControls),
          if (order.adjustment != null)
            _AdjustmentBanner(order, isAdmin: showControls),
          if (order.shipping.hasInfo)
            _ShippingInfo(order, isAdmin: showControls),
          for (final item in order.itemsData)
            ListTile(
              leading: (item['image'] as String?)?.isNotEmpty == true
                  ? SizedBox(
                      width: 48,
                      height: 48,
                      child: StoreImage(item['image'] as String))
                  : const Icon(Icons.image_not_supported),
              title: Text((item['name'] ?? '') as String),
              subtitle: Text('Tamanho: ${item['size'] ?? ''}\n'
                  '${Br.money(((item['price'] ?? 0) as num))}'),
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
  const _ShippingInfo(this.order, {required this.isAdmin});
  final Order order;

  /// Quem chama o Uber é a loja (remetente), não o cliente.
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final shipping = order.shipping;
    final trackingUrl = shipping.resolvedTrackingUrl;

    final subtitleParts = <String>[
      if (shipping.scheduledDateLabel != null)
        '${shipping.isPickup ? 'Retirada' : 'Entrega'} em: '
            '${shipping.scheduledDateLabel}'
      else if (shipping.preferredDateLabel != null)
        'Dia preferido: ${shipping.preferredDateLabel} (a loja confirma)',
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
        shipping.methodLabel.isNotEmpty
            ? shipping.methodLabel
            : shipping.zoneId.isNotEmpty
                ? 'Entrega própria da loja'
                : 'Envio',
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
          if (isAdmin && shipping.method == 'motoboy')
            TextButton(
              onPressed: () => _openUber(context),
              child: const Text('Abrir Uber'),
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

  /// Abre o Uber com a loja como origem e o endereço do pedido como destino.
  /// A origem vem da primeira unidade física cadastrada (`locations`).
  Future<void> _openUber(BuildContext context) async {
    final locations = await Tenant.col('locations').limit(1).get();
    final pickupAddress = locations.docs.isNotEmpty
        ? (locations.docs.first.data()['address'] as String? ?? '')
        : '';

    final addr = order.address;
    final dropoffAddress = [
      addr['street'],
      addr['number'],
      addr['district'],
      addr['city'],
      addr['state'],
    ].where((p) => (p as String?)?.isNotEmpty == true).join(', ');

    final link = UberLinkHelper.buildWebFallbackLink(
      pickupAddress: pickupAddress,
      dropoffAddress: dropoffAddress,
    );
    await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
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
    if (order.nextStatus == Status.transporting) {
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

  /// A loja define a data FINAL de entrega/retirada.
  Future<void> _pickDate() async {
    final order = widget.order;
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: order.shipping.scheduledDate?.toDate() ??
          order.shipping.preferredDate?.toDate() ??
          now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 90)),
      helpText: order.shipping.isPickup
          ? 'Data para retirada'
          : 'Data da entrega',
    );
    if (date != null) await _run(() => order.setScheduledDate(date));
  }

  Future<void> _proposeChange() async {
    final proposal = await _ProposeChangeDialog.show(context, widget.order);
    if (proposal == null) return;
    await _run(() => widget.order.proposeDeliveryChange(
        method: proposal.method, fee: proposal.fee, note: proposal.note));
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

    final changePending = order.deliveryChange?.isPending ?? false;

    return OverflowBar(
      alignment: MainAxisAlignment.end,
      children: <Widget>[
        TextButton(
          onPressed: () => _run(order.cancel),
          child: const Text('Cancelar',
              style: TextStyle(color: Colors.red)),
        ),
        if (order.status != Status.delivered) ...[
          TextButton(
            onPressed: _pickDate,
            child: Text(order.shipping.scheduledDate == null
                ? 'Definir data'
                : 'Mudar data'),
          ),
          if (!changePending)
            TextButton(
              onPressed: _proposeChange,
              child: const Text('Propor outra entrega'),
            ),
        ],
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
          onPressed: order.previousStatus == null
              ? null
              : () => _run(order.backStatus),
          child: const Text('Recuar'),
        ),
        TextButton(
          onPressed: order.nextStatus == null ? null : _advance,
          child: const Text('Avançar'),
        ),
      ],
    );
  }
}

class _Proposal {
  _Proposal(this.method, this.fee, this.note);
  final String method;
  final num fee;
  final String note;
}

/// A loja propõe outra forma de entrega e valor (ex.: "não envio por
/// Correios para São Leopoldo, entrego eu por R$ 10").
class _ProposeChangeDialog extends StatefulWidget {
  const _ProposeChangeDialog(this.order);
  final Order order;

  static Future<_Proposal?> show(BuildContext context, Order order) =>
      showDialog<_Proposal>(
          context: context, builder: (_) => _ProposeChangeDialog(order));

  @override
  State<_ProposeChangeDialog> createState() => _ProposeChangeDialogState();
}

class _ProposeChangeDialogState extends State<_ProposeChangeDialog> {
  late String _method = OrderShipping.methods.keys
      .firstWhere((m) => m != widget.order.shipping.method);
  final _fee = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _fee.dispose();
    _note.dispose();
    super.dispose();
  }

  num get _feeValue => Br.parseMoney(_fee.text);

  @override
  Widget build(BuildContext context) {
    final diff = _feeValue - widget.order.deliveryPrice;
    return AlertDialog(
      title: const Text('Propor outra entrega'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Pedido atual: '
                '${widget.order.shipping.methodLabel.isEmpty ? '—' : widget.order.shipping.methodLabel}'
                ' · ${Br.money(widget.order.deliveryPrice)}'),
            DropdownButtonFormField<String>(
              initialValue: _method,
              decoration: const InputDecoration(labelText: 'Nova forma'),
              items: OrderShipping.methods.entries
                  .map((e) =>
                      DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _method = v ?? _method),
            ),
            TextField(
              controller: _fee,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Novo valor da entrega', prefixText: 'R\$ '),
              onChanged: (_) => setState(() {}),
            ),
            TextField(
              controller: _note,
              decoration: const InputDecoration(
                  labelText: 'Mensagem para o cliente',
                  hintText: 'Ex.: Para São Leopoldo eu mesma entrego'),
            ),
            const SizedBox(height: 8),
            Text(
              diff < 0
                  ? 'Se o cliente aceitar, a loja devolve '
                      '${Br.money((-diff))}.'
                  : diff > 0
                      ? 'Se o cliente aceitar, ele paga mais '
                          '${Br.money(diff)}.'
                      : 'Mesmo valor.',
              style: TextStyle(
                  color: diff < 0 ? Colors.green.shade700 : Colors.orange),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: () => Navigator.pop(
              context, _Proposal(_method, _feeValue, _note.text.trim())),
          child: const Text('Enviar ao cliente'),
        ),
      ],
    );
  }
}

/// Proposta de troca de entrega: o cliente aceita/recusa; a loja aplica.
class _DeliveryChangeBanner extends StatefulWidget {
  const _DeliveryChangeBanner(this.order, {required this.isAdmin});
  final Order order;
  final bool isAdmin;

  @override
  State<_DeliveryChangeBanner> createState() => _DeliveryChangeBannerState();
}

class _DeliveryChangeBannerState extends State<_DeliveryChangeBanner> {
  bool _busy = false;

  Future<void> _do(Future<void> Function() action) async {
    setState(() => _busy = true);
    await action();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final change = order.deliveryChange!;
    final label = OrderShipping.methods[change.method] ?? change.method;
    final diff = change.difference;
    final who = widget.isAdmin ? 'O cliente recebe' : 'Você recebe';
    final money = diff < 0
        ? '$who de volta ${Br.money((-diff))}.'
        : diff > 0
            ? 'Diferença a pagar: ${Br.money(diff)}.'
            : 'Sem diferença de valor.';

    final String statusText;
    switch (change.status) {
      case 'accepted':
        statusText = widget.isAdmin
            ? 'O cliente ACEITOU. Aplique a troca.'
            : 'Você aceitou. A loja vai aplicar a troca.';
        break;
      case 'rejected':
        statusText = widget.isAdmin
            ? 'O cliente RECUSOU. Mantenha a entrega original ou cancele.'
            : 'Você recusou a troca.';
        break;
      default:
        statusText = widget.isAdmin
            ? 'Aguardando resposta do cliente.'
            : 'A loja propôs uma mudança na entrega:';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withAlpha(40),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(statusText, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('$label · ${Br.money(change.fee)} '
              '(antes ${Br.money(change.previousFee)})'),
          if (change.note.isNotEmpty) Text('"${change.note}"'),
          Text(money),
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (!widget.isAdmin && change.isPending)
            OverflowBar(
              alignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton(
                  onPressed: () =>
                      _do(() => order.respondDeliveryChange(accept: false)),
                  child: const Text('Recusar'),
                ),
                ElevatedButton(
                  onPressed: () =>
                      _do(() => order.respondDeliveryChange(accept: true)),
                  child: const Text('Aceitar'),
                ),
              ],
            )
          else if (widget.isAdmin && change.status == 'accepted')
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () => _do(order.applyDeliveryChange),
                child: const Text('Aplicar troca'),
              ),
            ),
        ],
      ),
    );
  }
}

/// Diferença de valor após a troca: devolução ao cliente ou cobrança extra.
class _AdjustmentBanner extends StatelessWidget {
  const _AdjustmentBanner(this.order, {required this.isAdmin});
  final Order order;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final adj = order.adjustment!;
    final value = Br.money(adj.amount.abs());
    final done = adj.status == 'done';
    final text = adj.isRefund
        ? (done
            ? 'Devolução de $value feita.'
            : isAdmin
                ? 'Devolver $value ao cliente.'
                : 'A loja vai devolver $value para você.')
        : (done
            ? 'Diferença de $value paga.'
            : isAdmin
                ? 'Cliente deve pagar a diferença de $value.'
                : 'Diferença a pagar: $value.');

    return ListTile(
      leading: Icon(done ? Icons.check_circle : Icons.swap_horiz,
          color: done ? Colors.green : Colors.orange),
      title: Text(text),
      subtitle: !done && adj.isRefund
          ? const Text('Cartão: estorno automático quando o Mercado Pago '
              'estiver ligado. Pix: a loja pode devolver por Pix.')
          : null,
      trailing: isAdmin && !done
          ? TextButton(
              onPressed: () => order.markAdjustmentDone(
                  adj.isRefund ? 'pix_manual' : 'charged'),
              child: Text(adj.isRefund ? 'Devolvi' : 'Recebido'),
            )
          : null,
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
          onPressed: () => Navigator.of(context).pop(OrderShipping(
            method: _method,
            scheduledDate: widget.initial.scheduledDate,
            zoneId: widget.initial.zoneId,
          )),
          child: const Text('Pular'),
        ),
        ElevatedButton(
          // Preserva a data/zona que o cliente escolheu no checkout.
          onPressed: () => Navigator.of(context).pop(OrderShipping(
            method: _method,
            carrier: _carrier.text.trim(),
            trackingCode: _code.text.trim(),
            trackingUrl: _url.text.trim(),
            shippedAt: widget.initial.shippedAt,
            scheduledDate: widget.initial.scheduledDate,
            zoneId: widget.initial.zoneId,
          )),
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
