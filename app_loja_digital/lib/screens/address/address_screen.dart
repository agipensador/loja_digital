import 'package:app_loja_digital/common/price_card.dart';
import 'package:app_loja_digital/models/address.dart';
import 'package:app_loja_digital/models/address_manager.dart';
import 'package:app_loja_digital/models/cart_manager.dart';
import 'package:app_loja_digital/models/saved_address.dart';
import 'package:app_loja_digital/services/cep_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AddressScreen extends StatefulWidget {
  const AddressScreen({super.key});

  @override
  State<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cepService = CepService();

  final _cep = TextEditingController();
  final _street = TextEditingController();
  final _number = TextEditingController();
  final _complement = TextEditingController();
  final _district = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();

  bool _loadingCep = false;
  String? _cepError;

  @override
  void dispose() {
    for (final c in [_cep, _street, _number, _complement, _district, _city,
        _state]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(Address a) {
    _cep.text = a.zipCode;
    _street.text = a.street;
    _number.text = a.number;
    _complement.text = a.complement;
    _district.text = a.district;
    _city.text = a.city;
    _state.text = a.state;
  }

  Address _current() => Address(
        street: _street.text.trim(),
        number: _number.text.trim(),
        complement: _complement.text.trim(),
        district: _district.text.trim(),
        city: _city.text.trim(),
        state: _state.text.trim(),
        zipCode: _cep.text.trim(),
      );

  Future<void> _searchCep() async {
    setState(() {
      _loadingCep = true;
      _cepError = null;
    });
    try {
      final found = await _cepService.getAddressFromCep(_cep.text);
      // Preenche o que o CEP retornou; número/complemento seguem manuais.
      _street.text = found.street;
      _district.text = found.district;
      _city.text = found.city;
      _state.text = found.state;
      setState(() {});
    } on CepAbertoException catch (e) {
      // CEP não encontrado: apenas informa e deixa preencher à mão.
      setState(() => _cepError = e.message);
    } catch (_) {
      setState(() => _cepError = 'Não foi possível buscar. Preencha à mão.');
    } finally {
      if (mounted) setState(() => _loadingCep = false);
    }
  }

  void _continue(CartManager cartManager) {
    if (!_formKey.currentState!.validate()) return;
    cartManager.setAddress(_current());
    Navigator.of(context).pushNamed('/checkout');
  }

  @override
  Widget build(BuildContext context) {
    final cartManager = context.watch<CartManager>();
    final primaryColor = Theme.of(context).primaryColor;
    String? req(String? v) =>
        (v == null || v.trim().isEmpty) ? 'Obrigatório' : null;
    const gap = SizedBox(height: 12);
    const dec = InputDecoration(isDense: true, border: OutlineInputBorder());

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
                          _fill(saved.address);
                          setState(() {});
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: TextFormField(
                            controller: _cep,
                            decoration: dec.copyWith(
                              labelText: 'CEP',
                              hintText: '00000-000',
                              errorText: _cepError,
                            ),
                            keyboardType: TextInputType.number,
                            onFieldSubmitted: (_) => _searchCep(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _loadingCep ? null : _searchCep,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
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
                    gap,
                    TextFormField(
                      controller: _street,
                      decoration: dec.copyWith(labelText: 'Rua/Avenida'),
                      validator: req,
                    ),
                    gap,
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextFormField(
                            controller: _number,
                            decoration: dec.copyWith(labelText: 'Número'),
                            keyboardType: TextInputType.number,
                            validator: req,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _complement,
                            decoration:
                                dec.copyWith(labelText: 'Complemento'),
                          ),
                        ),
                      ],
                    ),
                    gap,
                    TextFormField(
                      controller: _district,
                      decoration: dec.copyWith(labelText: 'Bairro'),
                      validator: req,
                    ),
                    gap,
                    Row(
                      children: <Widget>[
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _city,
                            decoration: dec.copyWith(labelText: 'Cidade'),
                            validator: req,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _state,
                            decoration: dec.copyWith(
                                labelText: 'UF', counterText: ''),
                            maxLength: 2,
                            validator: req,
                          ),
                        ),
                      ],
                    ),
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
