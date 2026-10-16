import 'package:app_loja_digital/common/notify_prompt.dart';
import 'package:app_loja_digital/helpers/br_format.dart';
import 'package:app_loja_digital/common/picked_image.dart';
import 'package:app_loja_digital/models/store.dart';
import 'package:app_loja_digital/models/stores_manager.dart';
import 'package:app_loja_digital/common/address_form.dart';
import 'package:app_loja_digital/models/address.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class EditStoreScreen extends StatefulWidget {
  const EditStoreScreen(this.editingStore, {super.key});

  final Store? editingStore;

  @override
  State<EditStoreScreen> createState() => _EditStoreScreenState();
}

class _EditStoreScreenState extends State<EditStoreScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  late final bool editing = widget.editingStore != null;
  late final Store store =
      widget.editingStore != null ? widget.editingStore!.clone() : Store();

  bool _loading = false;

  late final AddressFormController _address = AddressFormController(
    store.hasStructuredAddress || store.zipCode.isNotEmpty
        ? Address(
            zipCode: store.zipCode,
            street: store.street,
            number: store.number,
            district: store.district,
            city: store.city,
            state: store.state,
          )
        : null,
  );

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file != null) setState(() => store.image = file);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    final a = _address.build();
    store
      ..zipCode = a.zipCode
      ..street = a.street
      ..number = a.number
      ..district = a.district
      ..city = a.city
      ..state = a.state;
    final manager = context.read<StoresManager>();
    setState(() => _loading = true);
    try {
      final isFirst = !editing && manager.stores.isEmpty;
      await store.save(isFirst: isFirst);
      if (!mounted) return;
      context.read<StoresManager>().update(store);
      // Nova unidade (não a primeira): vale avisar os clientes da região.
      if (!editing && !isFirst) {
        await NotifyPrompt.ask(
          context,
          question: 'Nova unidade cadastrada. Avisar os clientes?',
          title: 'Nova loja: ${store.name}',
          body: 'Agora também estamos em ${store.city}. Retire seus pedidos '
              'ou receba mais rápido!',
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

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(editing ? 'Editar loja' : 'Nova loja'),
        centerTitle: true,
        actions: <Widget>[
          if (editing)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                context.read<StoresManager>().delete(store);
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            GestureDetector(
              onTap: _pickImage,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  color: Colors.grey[200],
                  child: store.image != null
                      ? PickedImage(store.image, fit: BoxFit.cover)
                      : const Center(
                          child: Icon(Icons.add_a_photo,
                              size: 48, color: Colors.grey),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: store.name,
              decoration: const InputDecoration(labelText: 'Nome da loja'),
              validator: (v) =>
                  (v == null || v.trim().length < 2) ? 'Informe o nome' : null,
              onSaved: (v) => store.name = v!.trim(),
            ),
            const SizedBox(height: 12),
            AddressFormFields(_address),
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'A cidade/UF define quais clientes esta unidade atende.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            TextFormField(
              initialValue: store.phone,
              decoration: const InputDecoration(
                  labelText: 'Telefone', hintText: '(00) 00000-0000'),
              keyboardType: TextInputType.phone,
              inputFormatters: [MaskFormatter.phone],
              onSaved: (v) => store.phone = v?.trim() ?? '',
            ),
            TextFormField(
              initialValue: store.hours,
              decoration: const InputDecoration(
                labelText: 'Horários',
                helperText: 'Ex: Seg-Sex 8h-20h / Sáb 8h-14h',
              ),
              maxLines: null,
              onSaved: (v) => store.hours = v?.trim() ?? '',
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Loja aberta agora'),
              value: store.open,
              onChanged: (v) => setState(() => store.open = v),
            ),
            const Divider(),
            const Text('Como esta unidade entrega',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Retirada na loja'),
              value: store.offersPickup,
              onChanged: (v) => setState(() => store.offersPickup = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Entrega própria'),
              subtitle: const Text('Locais, dias e valor de cada área em '
                  'Perfil → Zonas de entrega'),
              value: store.offersOwnDelivery,
              onChanged: (v) => setState(() => store.offersOwnDelivery = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Motoboy (Uber)'),
              subtitle: const Text('A loja chama o motoboy pelo app'),
              value: store.offersUber,
              onChanged: (v) => setState(() => store.offersUber = v),
            ),
            if (store.offersUber) ...[
              _FeeField(
                label: 'Saída do motoboy',
                initial: store.uberBaseFee,
                onSaved: (v) => store.uberBaseFee = v,
              ),
              _FeeField(
                label: 'Valor por km',
                initial: store.uberPerKm,
                onSaved: (v) => store.uberPerKm = v,
              ),
              _FeeField(
                label: 'Valor fixo se não der para calcular a distância',
                initial: store.uberFee,
                onSaved: (v) => store.uberFee = v,
              ),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Envio pelos Correios'),
              value: store.offersShipping,
              onChanged: (v) => setState(() => store.offersShipping = v),
            ),
            if (store.offersShipping)
              _FeeField(
                label: 'Valor fixo do envio',
                initial: store.shippingFee,
                onSaved: (v) => store.shippingFee = v,
              ),
            const Divider(),
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text('Redes sociais',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                IconButton(
                  icon: Icon(Icons.add, color: primaryColor),
                  onPressed: () => setState(() => store.socials.add('')),
                ),
              ],
            ),
            const Text(
              'Cole o link (Instagram, Facebook, TikTok, WhatsApp...). '
              'O ícone é reconhecido automaticamente.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            for (int i = 0; i < store.socials.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FaIcon(Social.iconFor(store.socials[i]),
                          color: primaryColor, size: 20),
                    ),
                    Expanded(
                      child: TextFormField(
                        initialValue: store.socials[i],
                        decoration: const InputDecoration(
                            hintText: 'https://instagram.com/sua_loja'),
                        onChanged: (v) => setState(() => store.socials[i] = v),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove, color: Colors.red),
                      onPressed: () =>
                          setState(() => store.socials.removeAt(i)),
                    ),
                  ],
                ),
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

class _FeeField extends StatelessWidget {
  const _FeeField(
      {required this.label, required this.initial, required this.onSaved});

  final String label;
  final num initial;
  final ValueChanged<num> onSaved;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: Br.moneyInput(initial),
      decoration: InputDecoration(
        labelText: label,
        prefixText: 'R\$ ',
        helperText: 'Vazio = grátis. O cliente pode ter esse valor '
            'ajustado se a loja propuser outra entrega.',
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onSaved: (v) =>
          onSaved(Br.parseMoney(v ?? '')),
    );
  }
}
