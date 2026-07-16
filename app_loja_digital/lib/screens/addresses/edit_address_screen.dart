import 'package:app_loja_digital/models/address.dart';
import 'package:app_loja_digital/models/address_manager.dart';
import 'package:app_loja_digital/models/saved_address.dart';
import 'package:app_loja_digital/services/cep_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class EditAddressScreen extends StatefulWidget {
  const EditAddressScreen(this.editing, {super.key});

  final SavedAddress? editing;

  @override
  State<EditAddressScreen> createState() => _EditAddressScreenState();
}

class _EditAddressScreenState extends State<EditAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cepService = CepService();

  final _cep = TextEditingController();
  final _street = TextEditingController();
  final _number = TextEditingController();
  final _complement = TextEditingController();
  final _district = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _customTitle = TextEditingController();

  late String _titleOption; // 'Casa' | 'Trabalho' | 'Outro'
  bool _cepLoading = false;
  String? _cepError;

  @override
  void initState() {
    super.initState();
    final a = widget.editing?.address;
    if (a != null) {
      _cep.text = a.zipCode;
      _street.text = a.street;
      _number.text = a.number;
      _complement.text = a.complement;
      _district.text = a.district;
      _city.text = a.city;
      _state.text = a.state;
    }
    final t = widget.editing?.title ?? 'Casa';
    if (AddressManager.fixedTitles.contains(t)) {
      _titleOption = t;
    } else {
      _titleOption = 'Outro';
      _customTitle.text = t;
    }
  }

  @override
  void dispose() {
    for (final c in [_cep, _street, _number, _complement, _district, _city,
        _state, _customTitle]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _searchCep() async {
    setState(() {
      _cepLoading = true;
      _cepError = null;
    });
    try {
      final found = await _cepService.getAddressFromCep(_cep.text);
      _street.text = found.street;
      _district.text = found.district;
      _city.text = found.city;
      _state.text = found.state;
      setState(() {});
    } on CepAbertoException catch (e) {
      setState(() => _cepError = e.message);
    } catch (_) {
      setState(() => _cepError = 'Não foi possível buscar. Preencha à mão.');
    } finally {
      if (mounted) setState(() => _cepLoading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final title =
        _titleOption == 'Outro' ? _customTitle.text.trim() : _titleOption;
    final saved = SavedAddress(
      id: widget.editing?.id,
      title: title.isEmpty ? 'Endereço' : title,
      address: Address(
        street: _street.text.trim(),
        number: _number.text.trim(),
        complement: _complement.text.trim(),
        district: _district.text.trim(),
        city: _city.text.trim(),
        state: _state.text.trim(),
        zipCode: _cep.text.trim(),
      ),
    );
    await context.read<AddressManager>().save(saved);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    String? req(String? v) =>
        (v == null || v.trim().isEmpty) ? 'Obrigatório' : null;
    const gap = SizedBox(height: 12);
    const dec = InputDecoration(isDense: true, border: OutlineInputBorder());

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title:
            Text(widget.editing == null ? 'Novo endereço' : 'Editar endereço'),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            const Text('Título', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [...AddressManager.fixedTitles, 'Outro'].map((t) {
                return ChoiceChip(
                  label: Text(t),
                  selected: _titleOption == t,
                  onSelected: (_) => setState(() => _titleOption = t),
                );
              }).toList(),
            ),
            if (_titleOption == 'Outro') ...[
              gap,
              TextFormField(
                controller: _customTitle,
                decoration: dec.copyWith(
                    labelText: 'Nome do local', hintText: 'Ex: Casa da mãe'),
                validator: (v) => _titleOption == 'Outro' ? req(v) : null,
              ),
            ],
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: TextFormField(
                    controller: _cep,
                    decoration:
                        dec.copyWith(labelText: 'CEP', errorText: _cepError),
                    keyboardType: TextInputType.number,
                    onFieldSubmitted: (_) => _searchCep(),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _cepLoading ? null : _searchCep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    icon: _cepLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white)))
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
                    decoration: dec.copyWith(labelText: 'Complemento'),
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
                    decoration:
                        dec.copyWith(labelText: 'UF', counterText: ''),
                    maxLength: 2,
                    validator: req,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: _save,
                child: const Text('Salvar endereço',
                    style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
