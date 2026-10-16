import 'package:app_loja_digital/common/notify_prompt.dart';
import 'package:app_loja_digital/helpers/br_format.dart';
import 'package:app_loja_digital/models/delivery_zone.dart';
import 'package:app_loja_digital/models/store.dart';
import 'package:app_loja_digital/models/stores_manager.dart';
import 'package:app_loja_digital/models/user_manager.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class EditDeliveryZoneScreen extends StatefulWidget {
  const EditDeliveryZoneScreen(this.editingZone, {super.key});

  final DeliveryZone? editingZone;

  @override
  State<EditDeliveryZoneScreen> createState() =>
      _EditDeliveryZoneScreenState();
}

class _EditDeliveryZoneScreenState extends State<EditDeliveryZoneScreen> {
  final _formKey = GlobalKey<FormState>();

  static const List<String> _weekdayLabels = [
    'Segunda',
    'Terça',
    'Quarta',
    'Quinta',
    'Sexta',
    'Sábado',
    'Domingo',
  ];

  late final bool editing = widget.editingZone != null;
  late final DeliveryZone zone =
      widget.editingZone != null ? widget.editingZone!.clone() : DeliveryZone();

  bool _loading = false;

  /// Unidades em que o usuário pode montar rotas.
  late final List<Store> _locations = context
      .read<UserManager>()
      .allowedLocations(context.read<StoresManager>());

  @override
  void initState() {
    super.initState();
    if (!editing && _locations.isNotEmpty) {
      zone.locationId = _locations.first.id!;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    zone.districts = zone.districts
        .map((d) => d.trim())
        .where((d) => d.isNotEmpty)
        .toList();
    if (zone.districts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adicione ao menos uma cidade ou bairro')),
      );
      return;
    }
    if (zone.weekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione ao menos um dia da semana')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await zone.save();
      if (!mounted) return;
      if (!editing) {
        await NotifyPrompt.ask(
          context,
          question: 'Nova área de entrega. Avisar os clientes?',
          title: 'Agora entregamos em ${zone.districts.take(3).join(', ')}'
              '${zone.districts.length > 3 ? ' e região' : ''}!',
          body: 'Peça pelo app e receba em casa.',
        );
        if (!mounted) return;
      }
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao salvar: $e')),
        );
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _delete() async {
    await zone.delete();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(editing ? 'Editar zona de entrega' : 'Nova zona de entrega'),
        centerTitle: true,
        actions: <Widget>[
          if (editing)
            IconButton(icon: const Icon(Icons.delete), onPressed: _delete),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            TextFormField(
              initialValue: zone.name,
              decoration: const InputDecoration(
                labelText: 'Nome da área',
                hintText: 'Ex: São Leopoldo',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Informe um nome' : null,
              onSaved: (v) => zone.name = v!.trim(),
            ),
            TextFormField(
              initialValue: Br.moneyInput(zone.fee),
              decoration: const InputDecoration(
                labelText: 'Valor da entrega nesta área',
                prefixText: 'R\$ ',
                helperText: 'Valor fixo. Vazio = entrega grátis.',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onSaved: (v) =>
                  zone.fee = Br.parseMoney(v ?? ''),
            ),
            if (_locations.length > 1)
              DropdownButtonFormField<String>(
                initialValue: _locations.any((l) => l.id == zone.locationId)
                    ? zone.locationId
                    : _locations.first.id,
                decoration: const InputDecoration(
                    labelText: 'Unidade que faz esta entrega'),
                items: _locations
                    .map((l) => DropdownMenuItem(
                        value: l.id,
                        child: Text('${l.name} (${l.city}/${l.state})')))
                    .toList(),
                onChanged: (v) => zone.locationId = v ?? zone.locationId,
                onSaved: (v) => zone.locationId = v ?? zone.locationId,
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Zona ativa'),
              value: zone.active,
              onChanged: (v) => setState(() => zone.active = v),
            ),
            const Divider(),
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text('Locais atendidos',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                IconButton(
                  icon: Icon(Icons.add, color: primaryColor),
                  onPressed: () => setState(() => zone.districts.add('')),
                ),
              ],
            ),
            const Text(
              'Cidades (ex.: São Leopoldo) ou bairros, escritos como aparecem '
              'no endereço do cliente. Só vale para o mesmo estado da loja.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            for (int i = 0; i < zone.districts.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: TextFormField(
                        initialValue: zone.districts[i],
                        decoration:
                            const InputDecoration(hintText: 'Cidade ou bairro'),
                        onChanged: (v) =>
                            setState(() => zone.districts[i] = v),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove, color: Colors.red),
                      onPressed: () =>
                          setState(() => zone.districts.removeAt(i)),
                    ),
                  ],
                ),
              ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Dias da semana que entrega nesses bairros',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            for (int i = 0; i < _weekdayLabels.length; i++)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_weekdayLabels[i]),
                value: zone.weekdays.contains(i + 1),
                onChanged: (checked) => setState(() {
                  if (checked == true) {
                    zone.weekdays.add(i + 1);
                  } else {
                    zone.weekdays.remove(i + 1);
                  }
                }),
              ),
            const SizedBox(height: 20),
            SizedBox(
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: _loading ? null : _save,
                child: _loading
                    ? const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(Colors.white))
                    : const Text('Salvar', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
