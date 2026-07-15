import 'package:app_loja_digital/models/address_manager.dart';
import 'package:app_loja_digital/models/saved_address.dart';
import 'package:app_loja_digital/screens/addresses/edit_address_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AddressesScreen extends StatelessWidget {
  const AddressesScreen({super.key});

  IconData _iconFor(String title) {
    if (title == 'Casa') return Icons.home;
    if (title == 'Trabalho') return Icons.work;
    return Icons.place;
  }

  void _openEdit(BuildContext context, SavedAddress? address) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EditAddressScreen(address),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Meus endereços'), centerTitle: true),
      body: Consumer<AddressManager>(
        builder: (_, manager, __) {
          if (!manager.isLoggedIn) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Entre para salvar seus endereços.'),
              ),
            );
          }

          return ListView(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '${manager.addresses.length} de ${AddressManager.maxAddresses} endereços',
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
              for (final address in manager.addresses)
                RadioListTile<String>(
                  value: address.id!,
                  groupValue: manager.selectedId,
                  onChanged: (v) => manager.select(v!),
                  secondary: Icon(_iconFor(address.title),
                      color: primaryColor),
                  title: Text(address.title,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(address.address.toString()),
                  isThreeLine: true,
                ),
              const Divider(),
              if (manager.canAddMore)
                ListTile(
                  leading: Icon(Icons.add_location_alt, color: primaryColor),
                  title: const Text('Adicionar endereço'),
                  onTap: () => _openEdit(context, null),
                )
              else
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Limite de 5 endereços atingido.',
                      style: TextStyle(color: Colors.grey)),
                ),
              if (manager.addresses.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 8,
                    children: manager.addresses.map((a) {
                      return ActionChip(
                        avatar: const Icon(Icons.edit, size: 16),
                        label: Text('Editar ${a.title}'),
                        onPressed: () => _openEdit(context, a),
                      );
                    }).toList(),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
