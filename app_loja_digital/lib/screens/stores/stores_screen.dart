import 'package:app_loja_digital/common/custom_drawer/custom_drawer.dart';
import 'package:app_loja_digital/common/message_text.dart';
import 'package:app_loja_digital/models/store.dart';
import 'package:app_loja_digital/models/stores_manager.dart';
import 'package:app_loja_digital/models/user_manager.dart';
import 'package:app_loja_digital/screens/stores/components/store_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class StoresScreen extends StatelessWidget {
  const StoresScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const CustomDrawer(),
      appBar: AppBar(
        title: const Text('Lojas'),
        centerTitle: true,
        actions: <Widget>[
          Consumer<UserManager>(
            builder: (_, userManager, __) {
              if (userManager.adminEnabled) {
                return IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Nova loja',
                  onPressed: () => Navigator.of(context)
                      .pushNamed('/edit_store', arguments: null),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer<StoresManager>(
        builder: (_, storesManager, __) {
          final stores = storesManager.stores;
          if (stores.isEmpty) {
            return const MessageText('Nenhuma loja cadastrada.');
          }
          return ListView.builder(
            itemCount: stores.length,
            itemBuilder: (_, index) {
              final Store store = stores[index];
              return StoreCard(store);
            },
          );
        },
      ),
    );
  }
}
