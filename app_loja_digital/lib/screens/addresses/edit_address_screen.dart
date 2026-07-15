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
  final _cep = TextEditingController();
  final _cepService = CepService();

  late Address _address =
      widget.editing?.address ?? Address();
  late String _titleOption; // 'Casa' | 'Trabalho' | 'Outro'
  late final TextEditingController _customTitle;

  bool _cepLoading = false;
  String? _cepError;

  @override
  void initState() {
    super.initState();
    final t = widget.editing?.title ?? 'Casa';
    if (AddressManager.fixedTitles.contains(t)) {
      _titleOption = t;
      _customTitle = TextEditingController();
    } else {
      _titleOption = 'Outro';
      _customTitle = TextEditingController(text: t);
    }
    _cep.text = _address.zipCode;
  }

  @override
  void dispose() {
    _cep.dispose();
    _customTitle.dispose();
    super.dispose();
  }

  Future<void> _searchCep() async {
    setState(() {
      _cepLoading = true;
      _cepError = null;
    });
    try {
      final found = await _cepService.getAddressFromCep(_cep.text);
      setState(() {
        // mantém número/complemento já digitados
        found.number = _address.number;
        found.complement = _address.complement;
        _address = found;
      });
    } on CepAbertoException catch (e) {
      setState(() => _cepError = e.message);
    } catch (_) {
      setState(() => _cepError = 'Erro ao buscar CEP');
    } finally {
      if (mounted) setState(() => _cepLoading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    final title =
        _titleOption == 'Outro' ? _customTitle.text.trim() : _titleOption;
    final saved = SavedAddress(
      id: widget.editing?.id,
      title: title.isEmpty ? 'Endereço' : title,
      address: _address,
    );
    await context.read<AddressManager>().save(saved);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    String? req(String? v) =>
        (v == null || v.trim().isEmpty) ? 'Obrigatório' : null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.editing == null ? 'Novo endereço' : 'Editar endereço'),
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
            if (_titleOption == 'Outro')
              TextFormField(
                controller: _customTitle,
                decoration: const InputDecoration(
                    labelText: 'Nome do local', hintText: 'Ex: Casa da mãe'),
                validator: (v) => _titleOption == 'Outro' ? req(v) : null,
              ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: TextFormField(
                    controller: _cep,
                    decoration: InputDecoration(
                        labelText: 'CEP', errorText: _cepError),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _cepLoading ? null : _searchCep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: _cepLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation(Colors.white)))
                      : const Text('Buscar'),
                ),
              ],
            ),
            TextFormField(
              key: ValueKey('street${_address.street}'),
              initialValue: _address.street,
              decoration: const InputDecoration(labelText: 'Rua/Avenida'),
              validator: req,
              onSaved: (v) => _address.street = v ?? '',
            ),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextFormField(
                    initialValue: _address.number,
                    decoration: const InputDecoration(labelText: 'Número'),
                    keyboardType: TextInputType.number,
                    validator: req,
                    onSaved: (v) => _address.number = v ?? '',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: _address.complement,
                    decoration:
                        const InputDecoration(labelText: 'Complemento'),
                    onSaved: (v) => _address.complement = v ?? '',
                  ),
                ),
              ],
            ),
            TextFormField(
              key: ValueKey('district${_address.district}'),
              initialValue: _address.district,
              decoration: const InputDecoration(labelText: 'Bairro'),
              validator: req,
              onSaved: (v) => _address.district = v ?? '',
            ),
            Row(
              children: <Widget>[
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    key: ValueKey('city${_address.city}'),
                    initialValue: _address.city,
                    decoration: const InputDecoration(labelText: 'Cidade'),
                    validator: req,
                    onSaved: (v) => _address.city = v ?? '',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    key: ValueKey('state${_address.state}'),
                    initialValue: _address.state,
                    decoration: const InputDecoration(labelText: 'UF'),
                    maxLength: 2,
                    validator: req,
                    onSaved: (v) => _address.state = v ?? '',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  // grava CEP digitado no endereço
                  _address.zipCode = _cep.text;
                  _save();
                },
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
