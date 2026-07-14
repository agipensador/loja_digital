import 'package:app_loja_digital/common/custom_drawer/custom_drawer.dart';
import 'package:app_loja_digital/models/order.dart';
import 'package:app_loja_digital/models/orders_manager.dart';
import 'package:app_loja_digital/screens/orders/components/order_tile.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AdminOrdersScreen extends StatelessWidget {
  const AdminOrdersScreen({super.key});

  void _openFilters(BuildContext context, OrdersManager ordersManager) {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return Consumer<OrdersManager>(
          builder: (_, manager, __) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Filtros',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  for (final status in Status.values)
                    CheckboxListTile(
                      title: Text(Order.getStatusText(status)),
                      value: manager.statusFilter.contains(status),
                      onChanged: (value) => manager.setStatusFilter(
                        status: status,
                        enabled: value ?? false,
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const CustomDrawer(),
      appBar: AppBar(
        title: const Text('Pedidos'),
        centerTitle: true,
        actions: <Widget>[
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: () => _openFilters(
                context,
                context.read<OrdersManager>(),
              ),
            ),
          ),
        ],
      ),
      body: Consumer<OrdersManager>(
        builder: (_, ordersManager, __) {
          final orders = ordersManager.filteredOrders;
          if (orders.isEmpty) {
            return const Center(
              child: Text(
                'Nenhum pedido nos filtros selecionados.',
                style: TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(4),
            itemCount: orders.length,
            itemBuilder: (_, index) =>
                OrderTile(orders[index], showControls: true),
          );
        },
      ),
    );
  }
}
