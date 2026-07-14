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

  static const List<String> _categories = [
    'Roupas',
    'Calçados',
    'Acessórios',
    'Eletrônicos',
    'Outros',
  ];

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(editing ? 'Editar produto' : 'Criar produto'),
        centerTitle: true,
        actions: <Widget>[
          if (editing)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
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
                  DropdownButtonFormField<String>(
                    initialValue: _categories.contains(product.category)
                        ? product.category
                        : 'Outros',
                    decoration: const InputDecoration(
                      labelText: 'Categoria',
                      isDense: true,
                    ),
                    items: _categories
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c),
                            ))
                        .toList(),
                    onChanged: (value) => product.category = value ?? 'Outros',
                    onSaved: (value) => product.category = value ?? 'Outros',
                  ),
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

      await product.save();

      if (!mounted) return;
      context.read<ProductManager>().update(product);
      Navigator.of(context).pop();
    }
  }
}
