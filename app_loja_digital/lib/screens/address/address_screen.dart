import 'package:app_loja_digital/common/address_form.dart';
import 'package:app_loja_digital/common/price_card.dart';
import 'package:app_loja_digital/models/address_manager.dart';
import 'package:app_loja_digital/models/cart_manager.dart';
import 'package:app_loja_digital/models/saved_address.dart';
import 'package:app_loja_digital/models/stores_manager.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AddressScreen extends StatefulWidget {
  const AddressScreen({super.key});

  @override
  State<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen> {
  final _formKey = GlobalKey<FormState>();
  late final AddressFormController _address =
      AddressFormController(context.read<CartManager>().address);

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  void _continue(CartManager cartManager) {
    if (!_formKey.currentState!.validate()) return;
    final address = _address.build();
    cartManager.setAddress(address);
    context.read<StoresManager>().selectForAddress(address);
    Navigator.of(context).pushNamed('/checkout');
  }

  @override
  Widget build(BuildContext context) {
    final cartManager = context.watch<CartManager>();

    return Scaffold(
      appBar: AppBar(title: const Text('Entrega'), centerTitle: true),
      body: ListView(
        children: <Widget>[
          // Endereços salvos (toque para reutilizar)
          Consumer<AddressManager>(
            builder: (_, addressManager, __) {
              if (addressManager.addresses.isEmpty) {
                return const SizedBox.shrink();
              }
              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Text('Endereços salvos',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 16)),
                    ),
                    for (final SavedAddress saved in addressManager.addresses)
                      RadioListTile<String>(
                        value: saved.id!,
                        groupValue: addressManager.selectedId,
                        onChanged: (v) {
                          addressManager.select(v!);
                          _address.fill(saved.address);
                        },
                        title: Text(saved.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold)),
                        subtitle: Text(saved.address.toString()),
                        isThreeLine: true,
                      ),
                  ],
                ),
              );
            },
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Text('Endereço de entrega',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 16)),
                    const SizedBox(height: 12),
                    AddressFormFields(_address),
                  ],
                ),
              ),
            ),
          ),
          PriceCard(
            buttonText: 'Continuar para o Pagamento',
            onPressed: () => _continue(cartManager),
          ),
        ],
      ),
    );
  }
}
