import 'package:app_loja_digital/common/price_card.dart';
import 'package:app_loja_digital/models/address.dart';
import 'package:app_loja_digital/models/address_manager.dart';
import 'package:app_loja_digital/models/cart_manager.dart';
import 'package:app_loja_digital/services/cep_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AddressScreen extends StatefulWidget {
  const AddressScreen({super.key});

  @override
  State<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen> {
  final _cepController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _loadingCep = false;
  String? _cepError;

  @override
  void dispose() {
    _cepController.dispose();
    super.dispose();
  }

  Future<void> _searchCep(CartManager cartManager) async {
    setState(() {
      _loadingCep = true;
      _cepError = null;
    });
    try {
      await cartManager.getAddress(_cepController.text);
    } on CepAbertoException catch (e) {
      setState(() => _cepError = e.message);
    } catch (e) {
      setState(() => _cepError = 'Erro ao buscar CEP');
    } finally {
      if (mounted) setState(() => _loadingCep = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartManager = context.watch<CartManager>();
    final Address? address = cartManager.address;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Entrega'),
        centerTitle: true,
      ),
      body: ListView(
        children: <Widget>[
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
                    for (final saved in addressManager.addresses)
                      RadioListTile<String>(
                        value: saved.id!,
                        groupValue: addressManager.selectedId,
                        onChanged: (v) {
                          addressManager.select(v!);
                          cartManager.setAddress(saved.address);
                          _cepController.text = saved.address.zipCode;
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Text(
                    'Ou informe outro endereço',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: TextFormField(
                          controller: _cepController,
                          decoration: InputDecoration(
                            isDense: true,
                            labelText: 'CEP',
                            hintText: '00000-000',
                            errorText: _cepError,
                            border: const OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          onFieldSubmitted: (_) => _searchCep(cartManager),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _loadingCep
                              ? null
                              : () => _searchCep(cartManager),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                          ),
                          icon: _loadingCep
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                        Colors.white),
                                  ),
                                )
                              : const Icon(Icons.search, size: 18),
                          label: const Text('Buscar'),
                        ),
                      ),
                    ],
                  ),
                  if (address != null) ...[
                    const SizedBox(height: 16),
                    _AddressForm(
                      address,
                      _formKey,
                      // Recria os campos quando um novo CEP é buscado,
                      // reaplicando rua/bairro/cidade/UF preenchidos.
                      key: ValueKey('cep_${address.zipCode}'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (address != null)
            PriceCard(
              buttonText: 'Continuar para o Pagamento',
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  _formKey.currentState!.save();
                  cartManager.setAddress(address);
                  Navigator.of(context).pushNamed('/checkout');
                }
              },
            ),
        ],
      ),
    );
  }
}

class _AddressForm extends StatelessWidget {
  const _AddressForm(this.address, this.formKey, {super.key});

  final Address address;
  final GlobalKey<FormState> formKey;

  @override
  Widget build(BuildContext context) {
    String? req(String? v) =>
        (v == null || v.trim().isEmpty) ? 'Obrigatório' : null;

    const gap = SizedBox(height: 12);
    const dec = InputDecoration(isDense: true, border: OutlineInputBorder());

    return Form(
      key: formKey,
      child: Column(
        children: <Widget>[
          TextFormField(
            initialValue: address.street,
            decoration: dec.copyWith(labelText: 'Rua/Avenida'),
            validator: req,
            onSaved: (v) => address.street = v ?? '',
          ),
          gap,
          Row(
            children: <Widget>[
              Expanded(
                child: TextFormField(
                  initialValue: address.number,
                  decoration: dec.copyWith(labelText: 'Número'),
                  keyboardType: TextInputType.number,
                  validator: req,
                  onSaved: (v) => address.number = v ?? '',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  initialValue: address.complement,
                  decoration: dec.copyWith(labelText: 'Complemento'),
                  onSaved: (v) => address.complement = v ?? '',
                ),
              ),
            ],
          ),
          gap,
          TextFormField(
            initialValue: address.district,
            decoration: dec.copyWith(labelText: 'Bairro'),
            validator: req,
            onSaved: (v) => address.district = v ?? '',
          ),
          gap,
          Row(
            children: <Widget>[
              Expanded(
                flex: 3,
                child: TextFormField(
                  initialValue: address.city,
                  decoration: dec.copyWith(labelText: 'Cidade'),
                  validator: req,
                  onSaved: (v) => address.city = v ?? '',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  initialValue: address.state,
                  decoration: dec.copyWith(labelText: 'UF', counterText: ''),
                  maxLength: 2,
                  validator: req,
                  onSaved: (v) => address.state = v ?? '',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
