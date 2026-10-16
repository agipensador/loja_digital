import 'package:app_loja_digital/common/address_form.dart';
import 'package:app_loja_digital/models/address_manager.dart';
import 'package:app_loja_digital/models/saved_address.dart';
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
  late final AddressFormController _address =
      AddressFormController(widget.editing?.address);
  final _customTitle = TextEditingController();

  late String _titleOption; // 'Casa' | 'Trabalho' | 'Outro'

  @override
  void initState() {
    super.initState();
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
    _address.dispose();
    _customTitle.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final title =
        _titleOption == 'Outro' ? _customTitle.text.trim() : _titleOption;
    final saved = SavedAddress(
      id: widget.editing?.id,
      title: title.isEmpty ? 'Endereço' : title,
      address: _address.build(),
    );
    await context.read<AddressManager>().save(saved);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

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
              const SizedBox(height: 12),
              TextFormField(
                controller: _customTitle,
                decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    labelText: 'Nome do local',
                    hintText: 'Ex: Casa da mãe'),
                validator: (v) => _titleOption == 'Outro' &&
                        (v == null || v.trim().isEmpty)
                    ? 'Obrigatório'
                    : null,
              ),
            ],
            const SizedBox(height: 16),
            AddressFormFields(_address),
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
