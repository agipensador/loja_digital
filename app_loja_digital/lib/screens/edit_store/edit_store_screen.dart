import 'package:app_loja_digital/common/picked_image.dart';
import 'package:app_loja_digital/models/store.dart';
import 'package:app_loja_digital/models/stores_manager.dart';
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

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file != null) setState(() => store.image = file);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => _loading = true);
    try {
      await store.save();
      if (!mounted) return;
      context.read<StoresManager>().update(store);
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
            TextFormField(
              initialValue: store.address,
              decoration: const InputDecoration(
                  labelText: 'Endereço', helperText: 'Usado para abrir o mapa'),
              onSaved: (v) => store.address = v?.trim() ?? '',
            ),
            TextFormField(
              initialValue: store.phone,
              decoration: const InputDecoration(labelText: 'Telefone'),
              keyboardType: TextInputType.phone,
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
