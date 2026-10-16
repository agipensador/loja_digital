import 'package:app_loja_digital/common/notify_prompt.dart';
import 'package:app_loja_digital/models/supplier.dart';
import 'package:app_loja_digital/models/user_manager.dart';
import 'package:app_loja_digital/models/staff_member.dart';
import 'package:app_loja_digital/models/product.dart';
import 'package:app_loja_digital/models/product_manager.dart';
import 'package:app_loja_digital/screens/edit_product/components/images_form.dart';
import 'package:app_loja_digital/screens/edit_product/components/sizes_form.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class EditProductScreen extends StatefulWidget {
  const EditProductScreen(this.editingProduct, {super.key});

  final Product? editingProduct;

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final _formKey = GlobalKey<FormState>();

  late final bool editing = widget.editingProduct != null;

  late Product product =
      widget.editingProduct != null ? widget.editingProduct!.clone() : Product();

  late final TextEditingController _categoryController =
      TextEditingController(text: product.category);

  static const List<String> _defaultCategories = [
    'Roupas',
    'Calçados',
    'Acessórios',
    'Anéis',
    'Eletrônicos',
    'Outros',
  ];

  @override
  void dispose() {
    _categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(editing ? 'Editar produto' : 'Criar produto'),
        centerTitle: true,
        actions: <Widget>[
          if (editing && context.watch<UserManager>().can(Perm.productsDelete))
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('Excluir produto?'),
                    content: Text('"${product.name}" sai da loja. Pedidos '
                        'antigos continuam com o histórico.'),
                    actions: <Widget>[
                      TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: const Text('Cancelar')),
                      TextButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text('Excluir',
                              style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );
                if (confirmed != true || !context.mounted) return;
                context.read<ProductManager>().delete(product);
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          children: <Widget>[
            ImagesForm(product),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  TextFormField(
                    initialValue: product.name,
                    decoration: const InputDecoration(
                      hintText: 'Título',
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().length < 3) {
                        return 'Título muito curto';
                      }
                      return null;
                    },
                    onSaved: (value) => product.name = value ?? '',
                  ),
                  TextFormField(
                    controller: _categoryController,
                    decoration: const InputDecoration(
                      labelText: 'Categoria',
                      helperText:
                          'Escolha uma sugestão ou digite uma nova (ex: Anéis)',
                      isDense: true,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Informe a categoria'
                        : null,
                    onSaved: (v) =>
                        product.category = (v ?? '').trim().isEmpty
                            ? 'Outros'
                            : v!.trim(),
                  ),
                  Builder(builder: (context) {
                    // Sugestões: categorias padrão + as já usadas em produtos.
                    final existing =
                        context.read<ProductManager>().categories;
                    final suggestions = <String>{
                      ..._defaultCategories,
                      ...existing,
                    }.toList();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        spacing: 6,
                        children: suggestions.map((c) {
                          return ActionChip(
                            label: Text(c),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => setState(
                                () => _categoryController.text = c),
                          );
                        }).toList(),
                      ),
                    );
                  }),
                  const Padding(
                    padding: EdgeInsets.only(top: 16, bottom: 8),
                    child: Text(
                      'Descrição',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextFormField(
                    initialValue: product.description,
                    decoration: const InputDecoration(
                      hintText: 'Descrição',
                      border: InputBorder.none,
                    ),
                    maxLines: null,
                    validator: (value) {
                      if (value == null || value.trim().length < 10) {
                        return 'Descrição muito curta';
                      }
                      return null;
                    },
                    onSaved: (value) => product.description = value ?? '',
                  ),
                  const SizedBox(height: 16),
                  Consumer<SuppliersManager>(
                    builder: (_, suppliers, __) {
                      if (suppliers.suppliers.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return DropdownButtonFormField<String?>(
                        initialValue: suppliers.byId(product.supplierId)?.id,
                        decoration: const InputDecoration(
                          labelText: 'Fornecedor (reposição pelo WhatsApp)',
                        ),
                        items: <DropdownMenuItem<String?>>[
                          const DropdownMenuItem(
                              value: null, child: Text('Nenhum')),
                          for (final s in suppliers.suppliers)
                            DropdownMenuItem(value: s.id, child: Text(s.name)),
                        ],
                        onChanged: (v) => product.supplierId = v,
                        onSaved: (v) => product.supplierId = v,
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('Peso e medidas (para frete)'),
                    subtitle: Text(product.hasShippingInfo
                        ? '${product.weightGrams} g · '
                            '${product.heightCm}×${product.widthCm}×'
                            '${product.lengthCm} cm'
                        : 'Necessário para calcular o frete dos Correios'),
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          for (final f in <(String, int, void Function(int))>[
                            ('Peso (g)', product.weightGrams,
                                (v) => product.weightGrams = v),
                            ('Alt. (cm)', product.heightCm,
                                (v) => product.heightCm = v),
                            ('Larg. (cm)', product.widthCm,
                                (v) => product.widthCm = v),
                            ('Comp. (cm)', product.lengthCm,
                                (v) => product.lengthCm = v),
                          ])
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: TextFormField(
                                  initialValue: f.$2 > 0 ? '${f.$2}' : '',
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                      labelText: f.$1, isDense: true),
                                  onSaved: (v) =>
                                      f.$3(int.tryParse(v ?? '') ?? 0),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizesForm(product),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 44,
                    child: ChangeNotifierProvider.value(
                      value: product,
                      child: Consumer<Product>(
                        builder: (_, product, __) {
                          return ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  primaryColor.withAlpha(100),
                            ),
                            onPressed: product.loading ? null : _save,
                            child: product.loading
                                ? const CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation(
                                        Colors.white),
                                  )
                                : const Text('Salvar',
                                    style: TextStyle(fontSize: 18)),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final wasOutOfStock = widget.editingProduct?.isOutOfStock ?? false;
      await product.save();

      if (!mounted) return;
      context.read<ProductManager>().update(product);
      // Sugere avisar os clientes: produto novo ou de volta ao estoque.
      if (!editing) {
        await NotifyPrompt.ask(
          context,
          question: 'Deseja enviar uma notificação de novo produto?',
          title: 'Novidade na loja!',
          body: '${product.name} acabou de chegar. Confira no app!',
        );
      } else if (wasOutOfStock && product.hasStock) {
        await NotifyPrompt.ask(
          context,
          question: 'Produto de volta ao estoque. Avisar os clientes?',
          title: 'Voltou ao estoque!',
          body: '${product.name} está disponível de novo. Corra!',
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    }
  }
}
