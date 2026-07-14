import 'package:app_loja_digital/common/price_card.dart';
import 'package:app_loja_digital/models/cart_manager.dart';
import 'package:app_loja_digital/models/order.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _loading = false;

  Future<void> _finish(CartManager cartManager) async {
    setState(() => _loading = true);
    try {
      final Order order = await cartManager.checkout();
      if (!mounted) return;
      _showSuccess(order);
    } on CheckoutException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Falha ao finalizar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSuccess(Order order) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Pedido realizado!'),
        content: Text(
          'Seu pedido ${order.formattedId} foi criado com sucesso.\n'
          'Total: R\$ ${order.price.toStringAsFixed(2)}',
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
                  const Text(
                    'Entregar em',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(cartManager.address?.toString() ?? '—'),
                ],
              ),
            ),
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
