import 'package:app_loja_digital/models/plan.dart';
import 'package:app_loja_digital/models/tenant_manager.dart';
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
              // Nova unidade: só o dono, e dentro do limite do plano.
              final tenant = context.watch<TenantManager>();
              final stores = context.watch<StoresManager>().stores;
              final limit = tenant.store?.plan.maxLocations ?? 1;
              if (userManager.masterEnabled) {
                return IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Nova unidade',
                  onPressed: () {
                    if (stores.length >= limit) {
                      final next = PlanCatalog.forLocations(stores.length + 1);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(next == null
                            ? 'O limite da plataforma é de 5 unidades.'
                            : 'Seu plano permite $limit unidade(s). Mude para '
                                'o ${next.name} em Perfil → Assinatura.'),
                      ));
                      return;
                    }
                    Navigator.of(context)
                        .pushNamed('/edit_store', arguments: null);
                  },
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
