import 'package:app_loja_digital/helpers/br_format.dart';
import 'package:app_loja_digital/models/delivery_zone.dart';
import 'package:app_loja_digital/models/delivery_zones_manager.dart';
import 'package:app_loja_digital/screens/delivery_zones/edit_delivery_zone_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DeliveryZonesScreen extends StatelessWidget {
  const DeliveryZonesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Zonas de entrega'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const EditDeliveryZoneScreen(null),
          ),
        ),
      ),
      body: Consumer<DeliveryZonesManager>(
        builder: (_, manager, __) {
          final zones = manager.zones;
          if (zones.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nenhuma zona cadastrada. Toque em "+" para informar os '
                  'bairros e os dias da semana em que você entrega '
                  'pessoalmente — o cliente vai ver a data sugerida no '
                  'checkout.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            itemCount: zones.length,
            itemBuilder: (_, i) {
              final zone = zones[i];
              return ListTile(
                leading: Icon(
                  zone.active ? Icons.local_shipping : Icons.pause_circle,
                  color: zone.active ? primaryColor : Colors.grey,
                ),
                title: Text(zone.name),
                subtitle: Text(
                  '${zone.districts.join(', ')}\n'
                  '${_weekdaysLabel(zone)} · '
                  '${zone.fee == 0 ? 'grátis' : Br.money(zone.fee)}',
                ),
                isThreeLine: true,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => EditDeliveryZoneScreen(zone),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _weekdaysLabel(DeliveryZone zone) {
    const labels = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
    final sorted = List<int>.from(zone.weekdays)..sort();
    return sorted.map((d) => labels[d - 1]).join(', ');
  }
}
