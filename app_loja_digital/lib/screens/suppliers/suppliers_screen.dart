import 'package:app_loja_digital/models/supplier.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Fornecedores/distribuidores (nome + WhatsApp) para pedidos de reposição.
class SuppliersScreen extends StatelessWidget {
  const SuppliersScreen({super.key});

  Future<void> _edit(BuildContext context, [Supplier? supplier]) async {
    final s = supplier ?? Supplier();
    final name = TextEditingController(text: s.name);
    final contact = TextEditingController(text: s.contact);
    final phone = TextEditingController(text: s.whatsapp);
    final saved = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(supplier == null ? 'Novo fornecedor' : 'Editar fornecedor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
                controller: name,
                decoration:
                    const InputDecoration(labelText: 'Nome do fornecedor')),
            TextField(
                controller: contact,
                decoration: const InputDecoration(
                    labelText: 'Pessoa de contato (opcional)')),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                  labelText: 'WhatsApp com DDD', hintText: '51 99999-9999'),
            ),
          ],
        ),
        actions: <Widget>[
          if (supplier != null)
            TextButton(
              onPressed: () async {
                await supplier.delete();
                if (c.mounted) Navigator.pop(c, false);
              },
              child: const Text('Excluir', style: TextStyle(color: Colors.red)),
            ),
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Salvar')),
        ],
      ),
    );
    if (saved == true && name.text.trim().isNotEmpty) {
      s
        ..name = name.text.trim()
        ..contact = contact.text.trim()
        ..whatsapp = phone.text.trim();
      await s.save();
    }
    name.dispose();
    contact.dispose();
    phone.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<SuppliersManager>();
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(title: const Text('Fornecedores'), centerTitle: true),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryColor,
        onPressed: () => _edit(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: manager.suppliers.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Cadastre seus fornecedores com o WhatsApp. Depois, em cada '
                  'produto, escolha o fornecedor — quando o estoque baixar, '
                  'o app monta o pedido e abre a conversa pronta.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              children: <Widget>[
                for (final s in manager.suppliers)
                  ListTile(
                    leading: Icon(Icons.local_shipping, color: primaryColor),
                    title: Text(s.name),
                    subtitle: Text([
                      if (s.contact.isNotEmpty) s.contact,
                      s.hasWhatsapp ? s.whatsapp : 'Sem WhatsApp',
                    ].join(' · ')),
                    onTap: () => _edit(context, s),
                  ),
              ],
            ),
    );
  }
}
