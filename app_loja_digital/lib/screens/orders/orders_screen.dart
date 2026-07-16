import 'package:app_loja_digital/common/custom_drawer/custom_drawer.dart';
import 'package:app_loja_digital/common/message_text.dart';
import 'package:app_loja_digital/models/orders_manager.dart';
import 'package:app_loja_digital/models/user_manager.dart';
import 'package:app_loja_digital/screens/orders/components/order_tile.dart';
import 'package:app_loja_digital/screens/orders/components/orders_search_field.dart';
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
          ? const MessageText('Entre para ver seus pedidos.')
          : Column(
              children: <Widget>[
                const OrdersSearchField(),
                Expanded(
                  child: Consumer<OrdersManager>(
                    builder: (_, ordersManager, __) {
                      final orders = ordersManager.myOrders;
                      if (orders.isEmpty) {
                        return MessageText(
                          ordersManager.search.isEmpty
                              ? 'Nenhum pedido ainda :('
                              : 'Nenhum pedido encontrado.',
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.all(4),
                        itemCount: orders.length,
                        itemBuilder: (_, index) => OrderTile(orders[index]),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
