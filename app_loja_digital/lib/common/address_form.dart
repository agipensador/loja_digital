import 'package:app_loja_digital/helpers/br_format.dart';
import 'package:app_loja_digital/models/address.dart';
import 'package:app_loja_digital/services/cep_service.dart';
import 'package:flutter/material.dart';

/// Estado do formulário de endereço (compartilhado pelas telas de entrega,
/// endereços salvos e unidade física). Começa pelo CEP: ao completar os 8
/// dígitos, busca e preenche rua, bairro, cidade e UF — o número fica com a
/// pessoa (obrigatório, ou "Sem número").
class AddressFormController extends ChangeNotifier {
  AddressFormController([Address? initial]) {
    if (initial != null) fill(initial);
  }

  static const noNumberText = 'S/N';

  final cep = TextEditingController();
  final street = TextEditingController();
  final number = TextEditingController();
  final complement = TextEditingController();
  final district = TextEditingController();
  final city = TextEditingController();
  final state = TextEditingController();

  bool noNumber = false;
  bool loading = false;
  String? cepError;

  /// Rua/bairro/cidade liberados: CEP encontrado, CEP não achado (preenche
  /// à mão) ou endereço já existente.
  bool unlocked = false;

  final CepService _service = CepService();

  void fill(Address a) {
    cep.text = Br.cep(a.zipCode);
    street.text = a.street;
    noNumber = a.number == noNumberText;
    number.text = noNumber ? '' : a.number;
    complement.text = a.complement;
    district.text = a.district;
    city.text = a.city;
    state.text = a.state;
    unlocked = a.zipCode.isNotEmpty || a.street.isNotEmpty;
    notifyListeners();
  }

  Address build() => Address(
        zipCode: Br.digits(cep.text),
        street: street.text.trim(),
        number: noNumber ? noNumberText : number.text.trim(),
        complement: complement.text.trim(),
        district: district.text.trim(),
        city: city.text.trim(),
        state: state.text.trim().toUpperCase(),
      );

  void setNoNumber(bool value) {
    noNumber = value;
    if (value) number.clear();
    notifyListeners();
  }

  Future<void> search() async {
    if (Br.digits(cep.text).length != 8) return;
    loading = true;
    cepError = null;
    notifyListeners();
    try {
      final found = await _service.getAddressFromCep(cep.text);
      street.text = found.street;
      district.text = found.district;
      city.text = found.city;
      state.text = found.state;
    } on CepAbertoException catch (e) {
      cepError = '${e.message}. Preencha o endereço abaixo.';
    } catch (_) {
      cepError = 'Não foi possível buscar o CEP. Preencha abaixo.';
    } finally {
      loading = false;
      unlocked = true;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    for (final c in [cep, street, number, complement, district, city, state]) {
      c.dispose();
    }
    super.dispose();
  }
}

/// Campos do endereço, na ordem do CEP para baixo.
class AddressFormFields extends StatelessWidget {
  const AddressFormFields(this.controller, {super.key});

  final AddressFormController controller;

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Obrigatório' : null;

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 12);
    const dec = InputDecoration(isDense: true, border: OutlineInputBorder());
    final c = controller;

    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextFormField(
              controller: c.cep,
              keyboardType: TextInputType.number,
              inputFormatters: [MaskFormatter.cep],
              decoration: dec.copyWith(
                labelText: 'CEP',
                hintText: '00000-000',
                errorText: c.cepError,
                errorMaxLines: 2,
                suffixIcon: c.loading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: c.search,
                      ),
              ),
              // Busca sozinho ao completar os 8 dígitos.
              onChanged: (v) {
                if (Br.digits(v).length == 8) c.search();
              },
              validator: (v) => Br.digits(v ?? '').length == 8
                  ? null
                  : 'Informe o CEP com 8 dígitos',
            ),
            if (!c.unlocked)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Digite o CEP para preencher o endereço.',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ),
            if (c.unlocked) ...[
              gap,
              TextFormField(
                controller: c.street,
                decoration: dec.copyWith(labelText: 'Rua/Avenida'),
                validator: _required,
              ),
              gap,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: TextFormField(
                      // Recria o campo ao marcar "sem número" (limpa o erro).
                      key: ValueKey('numero-${c.noNumber}'),
                      controller: c.number,
                      enabled: !c.noNumber,
                      keyboardType: TextInputType.number,
                      decoration: dec.copyWith(
                          labelText: c.noNumber ? 'Sem número' : 'Número'),
                      validator: (v) => c.noNumber ? null : _required(v),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: c.complement,
                      decoration: dec.copyWith(labelText: 'Complemento'),
                    ),
                  ),
                ],
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Endereço sem número'),
                value: c.noNumber,
                onChanged: (v) => c.setNoNumber(v ?? false),
              ),
              TextFormField(
                controller: c.district,
                decoration: dec.copyWith(labelText: 'Bairro'),
                validator: _required,
              ),
              gap,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: c.city,
                      decoration: dec.copyWith(labelText: 'Cidade'),
                      validator: _required,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: c.state,
                      maxLength: 2,
                      textCapitalization: TextCapitalization.characters,
                      decoration:
                          dec.copyWith(labelText: 'UF', counterText: ''),
                      validator: (v) =>
                          (v ?? '').trim().length == 2 ? null : 'UF',
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}
