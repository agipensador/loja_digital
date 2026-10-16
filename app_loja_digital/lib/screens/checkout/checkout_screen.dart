import 'package:app_loja_digital/models/store.dart';
import 'package:app_loja_digital/services/shipping_quote_service.dart';
import 'package:app_loja_digital/helpers/br_format.dart';
import 'package:app_loja_digital/common/price_card.dart';
import 'package:app_loja_digital/models/cart_manager.dart';
import 'package:app_loja_digital/models/delivery_option.dart';
import 'package:app_loja_digital/models/delivery_zones_manager.dart';
import 'package:app_loja_digital/models/order.dart';
import 'package:app_loja_digital/models/payment_manager.dart';
import 'package:app_loja_digital/models/plan.dart';
import 'package:app_loja_digital/models/stores_manager.dart';
import 'package:app_loja_digital/models/tenant_manager.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _loading = false;

  /// Estimativa do motoboy (distância loja → cliente), por unidade+CEP.
  num? _uberEstimate;
  String? _uberKey;

  void _estimateUber(Store location, String cep) {
    final key = '${location.id}|$cep';
    if (!location.offersUber || key == _uberKey) return;
    _uberKey = key;
    ShippingQuoteService.estimateUber(location, cep).then((value) {
      if (!mounted || _uberKey != key) return;
      setState(() => _uberEstimate = value);
      final cart = context.read<CartManager>();
      final chosen = cart.deliveryOption;
      if (chosen?.method == DeliveryMethods.uber) {
        cart.selectDeliveryOption(DeliveryOption.forLocation(location, null,
                uberEstimate: value)
            .firstWhere((o) => o.method == DeliveryMethods.uber));
      }
    });
  }

  /// Opções que a unidade que atende o pedido oferece para o endereço.
  /// Recalculadas quando unidades/áreas terminam de carregar ou mudam.
  List<DeliveryOption> _options(BuildContext context) {
    final cart = context.watch<CartManager>();
    final stores = context.watch<StoresManager>();
    final zones = context.watch<DeliveryZonesManager>();
    final address = cart.address;
    if (address == null) return [];
    final locationId = cart.items.isEmpty
        ? stores.currentLocationId
        : cart.items.first.locationId;
    final location = stores.locationById(locationId);
    if (location == null) return [];
    final zone = zones.zoneFor(address, stores, locationId: locationId);
    _estimateUber(location, address.zipCode);
    return DeliveryOption.forLocation(location, zone,
        uberEstimate: _uberEstimate);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A taxa da plataforma (e quem paga) vem da configuração da loja.
    final config = Provider.of<TenantManager>(context).store?.serviceFee;
    if (config != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<CartManager>().serviceFeeConfig = config;
      });
    }
  }

  Future<void> _finish(CartManager cartManager) async {
    // Loja suspensa (mensalidade vencida) não vende.
    if (!context.read<TenantManager>().canSell) {
      _snack('Esta loja está temporariamente indisponível.', error: true);
      return;
    }
    if (!cartManager.isDeliveryChosen) {
      _snack('Escolha como quer receber o pedido');
      return;
    }
    final payment = context.read<PaymentManager>();
    if (payment.selectedMethod == null) {
      _snack('Escolha uma forma de pagamento');
      return;
    }
    setState(() => _loading = true);
    try {
      final Order order =
          await cartManager.checkout(paymentMethod: payment.selectedLabel);
      if (!mounted) return;
      _showSuccess(order);
    } on CheckoutException catch (e) {
      if (mounted) _snack(e.message, error: true);
    } catch (e) {
      if (mounted) _snack('Falha ao finalizar: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: error ? Colors.red : null,
    ));
  }

  void _showSuccess(Order order) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Pedido realizado!'),
        content: Text(
          'Seu pedido ${order.formattedId} foi criado com sucesso.\n'
          'Total: ${Br.money(order.price)}\n\n'
          'A loja vai confirmar a entrega e a data. Se ela precisar mudar '
          'a forma de entrega, você recebe a proposta no pedido.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              // volta para a base (fecha checkout, entrega e carrinho)
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartManager = context.watch<CartManager>();
    final options = _options(context);
    final selected = cartManager.deliveryOption;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pagamento'),
        centerTitle: true,
      ),
      body: ListView(
        children: <Widget>[
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('Seu endereço',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(cartManager.address?.toString() ?? '—'),
                ],
              ),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text('Como você quer receber?',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 16)),
                  ),
                  if (options.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('A loja ainda não configurou formas de '
                          'entrega para este endereço.'),
                    ),
                  for (final option in options)
                    _OptionTile(
                      option: option,
                      selected: selected?.method == option.method,
                      onTap: () => cartManager.selectDeliveryOption(option),
                    ),
                  if (selected?.zone != null) _PreferredDate(cartManager),
                ],
              ),
            ),
          ),
          Consumer<PaymentManager>(
            builder: (_, payment, __) {
              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: Icon(
                    payment.selectedMethod == kPixMethod
                        ? Icons.pix
                        : Icons.credit_card,
                    color: Theme.of(context).primaryColor,
                  ),
                  title: const Text('Forma de pagamento'),
                  subtitle: Text(payment.selectedLabel),
                  trailing: TextButton(
                    onPressed: () => Navigator.of(context)
                        .pushNamed('/payment_methods'),
                    child: const Text('Alterar'),
                  ),
                ),
              );
            },
          ),
          PriceCard(
            buttonText: 'Finalizar Pedido',
            onPressed: _loading ? null : () => _finish(cartManager),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile(
      {required this.option, required this.selected, required this.onTap});

  final DeliveryOption option;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon {
    switch (option.method) {
      case DeliveryMethods.ownDelivery:
        return Icons.local_shipping;
      case DeliveryMethods.pickup:
        return Icons.storefront;
      case DeliveryMethods.uber:
        return Icons.sports_motorsports;
      default:
        return Icons.markunread_mailbox;
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    return ListTile(
      onTap: onTap,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: selected ? primaryColor : Colors.grey,
      ),
      title: Row(
        children: <Widget>[
          Icon(_icon, size: 18, color: primaryColor),
          const SizedBox(width: 6),
          Expanded(child: Text(option.title)),
        ],
      ),
      subtitle: Text(option.detail),
      trailing: Text(
        option.fee == 0 ? 'Grátis' : Plan.money(option.fee),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Entrega da loja: o cliente indica o dia preferido; a loja confirma a
/// data final (ou propõe outra) depois.
class _PreferredDate extends StatelessWidget {
  const _PreferredDate(this.cartManager);

  final CartManager cartManager;

  static const _weekdays = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

  String _fmt(DateTime d) => '${_weekdays[d.weekday - 1]}, '
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  bool _same(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final dates = cartManager.deliveryOption!.zone!.nextDates(count: 4);
    final chosen = cartManager.selectedDeliveryDate;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('Dia preferido (a loja confirma):'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: <Widget>[
              for (final d in dates)
                ChoiceChip(
                  label: Text(_fmt(d)),
                  selected: chosen != null && _same(chosen, d),
                  onSelected: (_) => cartManager.setSelectedDeliveryDate(d),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
