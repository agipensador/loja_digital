import 'package:app_loja_digital/common/custom_drawer/custom_drawer.dart';
import 'package:app_loja_digital/models/order.dart';
import 'package:app_loja_digital/models/orders_manager.dart';
import 'package:app_loja_digital/screens/orders/components/order_tile.dart';
import 'package:app_loja_digital/screens/orders/components/orders_search_field.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AdminOrdersScreen extends StatelessWidget {
  const AdminOrdersScreen({super.key});

  Color _colorFor(BuildContext context, Status status) {
    switch (status) {
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
    return Scaffold(
      drawer: const CustomDrawer(),
      appBar: AppBar(
        title: const Text('Pedidos'),
        centerTitle: true,
      ),
      body: Consumer<OrdersManager>(
        builder: (_, ordersManager, __) {
          final orders = ordersManager.filteredOrders;
          return Column(
            children: <Widget>[
              const OrdersSearchField(),
              // Filtros como chips/containers coloridos na própria tela.
              Container(
                color: Colors.white,
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('Filtrar por status',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black54)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: Status.values.map((status) {
                        final bool selected =
                            ordersManager.statusFilter.contains(status);
                        final Color color = _colorFor(context, status);
                        return _FilterChipBox(
                          label: Order.getStatusText(status),
                          selected: selected,
                          color: color,
                          onTap: () => ordersManager.setStatusFilter(
                            status: status,
                            enabled: !selected,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
              Expanded(
                child: orders.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Nenhum pedido nos filtros selecionados.',
                            style: TextStyle(
                                color: Colors.white, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(4),
                        itemCount: orders.length,
                        itemBuilder: (_, index) =>
                            OrderTile(orders[index], showControls: true),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Container que funciona como o checkbox do filtro: fica colorido quando
/// selecionado e apenas contornado quando não.
class _FilterChipBox extends StatelessWidget {
  const _FilterChipBox({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          border: Border.all(color: color, width: 1.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              size: 18,
              color: selected ? Colors.white : color,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
