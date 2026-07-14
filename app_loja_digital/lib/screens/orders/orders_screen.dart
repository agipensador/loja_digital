import 'package:app_loja_digital/common/custom_drawer/custom_drawer.dart';
import 'package:app_loja_digital/models/orders_manager.dart';
import 'package:app_loja_digital/models/user_manager.dart';
import 'package:app_loja_digital/screens/orders/components/order_tile.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loggedIn = context.watch<UserManager>().isLoggedIn;

    return Scaffold(
      drawer: const CustomDrawer(),
      appBar: AppBar(
        title: const Text('Meus Pedidos'),
        centerTitle: true,
      ),
      body: !loggedIn
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Entre para ver seus pedidos.',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Consumer<OrdersManager>(
              builder: (_, ordersManager, __) {
                final orders = ordersManager.myOrders;
                if (orders.isEmpty) {
                  return const Center(
                    child: Text(
                      'Nenhum pedido ainda :(',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(4),
                  itemCount: orders.length,
                  itemBuilder: (_, index) => OrderTile(orders[index]),
                );
              },
            ),
    );
  }
}
