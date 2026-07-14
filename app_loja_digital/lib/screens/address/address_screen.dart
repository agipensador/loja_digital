import 'package:app_loja_digital/common/price_card.dart';
import 'package:app_loja_digital/models/address.dart';
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
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Text(
                    'Endereço de Entrega',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  TextFormField(
                    controller: _cepController,
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: 'CEP',
                      hintText: '00000-000',
                      errorText: _cepError,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  ElevatedButton(
                    onPressed:
                        _loadingCep ? null : () => _searchCep(cartManager),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: _loadingCep
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Text('Buscar CEP'),
                  ),
                  if (address != null) _AddressForm(address, _formKey),
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
  const _AddressForm(this.address, this.formKey);

  final Address address;
  final GlobalKey<FormState> formKey;

  @override
  Widget build(BuildContext context) {
    String? req(String? v) =>
        (v == null || v.trim().isEmpty) ? 'Obrigatório' : null;

    return Form(
      key: formKey,
      child: Column(
        children: <Widget>[
          TextFormField(
            initialValue: address.street,
            decoration: const InputDecoration(
                isDense: true, labelText: 'Rua/Avenida'),
            validator: req,
            onSaved: (v) => address.street = v ?? '',
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: TextFormField(
                  initialValue: address.number,
                  decoration: const InputDecoration(
                      isDense: true, labelText: 'Número'),
                  keyboardType: TextInputType.number,
                  validator: req,
                  onSaved: (v) => address.number = v ?? '',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: address.complement,
                  decoration: const InputDecoration(
                      isDense: true, labelText: 'Complemento'),
                  onSaved: (v) => address.complement = v ?? '',
                ),
              ),
            ],
          ),
          TextFormField(
            initialValue: address.district,
            decoration: const InputDecoration(
                isDense: true, labelText: 'Bairro'),
            validator: req,
            onSaved: (v) => address.district = v ?? '',
          ),
          Row(
            children: <Widget>[
              Expanded(
                flex: 3,
                child: TextFormField(
                  initialValue: address.city,
                  decoration: const InputDecoration(
                      isDense: true, labelText: 'Cidade'),
                  validator: req,
                  onSaved: (v) => address.city = v ?? '',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: address.state,
                  decoration: const InputDecoration(
                      isDense: true, labelText: 'UF'),
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
