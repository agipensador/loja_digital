import 'package:app_loja_digital/models/orders_manager.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Campo de busca de pedidos por ID (#000123) ou nome do produto.
class OrdersSearchField extends StatefulWidget {
  const OrdersSearchField({super.key});

  @override
  State<OrdersSearchField> createState() => _OrdersSearchFieldState();
}

class _OrdersSearchFieldState extends State<OrdersSearchField> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.text = context.read<OrdersManager>().search;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ordersManager = context.read<OrdersManager>();
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: TextField(
        controller: _controller,
        onChanged: (value) {
          ordersManager.search = value;
          setState(() {});
        },
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Buscar por nº do pedido ou produto',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _controller.clear();
                    ordersManager.search = '';
                    setState(() {});
                  },
                ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }
}
