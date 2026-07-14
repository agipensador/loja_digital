import 'package:app_loja_digital/models/item_size.dart';
import 'package:app_loja_digital/models/product.dart';
import 'package:app_loja_digital/screens/edit_product/components/edit_item_size.dart';
import 'package:flutter/material.dart';

class SizesForm extends StatelessWidget {
  const SizesForm(this.product, {super.key});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return FormField<List<ItemSize>>(
      initialValue: product.sizes,
      validator: (sizes) {
        if (sizes == null || sizes.isEmpty) {
          return 'Adicione pelo menos um tamanho/variante';
        }
        return null;
      },
      builder: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'Tamanhos / Variantes',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.add,
                      color: Theme.of(context).primaryColor),
                  onPressed: () {
                    state.value!.add(ItemSize());
                    state.didChange(state.value);
                  },
                ),
              ],
            ),
            const Text(
              'Para produtos sem tamanho (ex: relógio), use uma única variante '
              'chamada "Único".',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 8),
            for (final size in state.value!)
              EditItemSize(
                key: ObjectKey(size),
                size: size,
                onRemove: () {
                  state.value!.remove(size);
                  state.didChange(state.value);
                },
              ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  state.errorText!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
          ],
        );
      },
    );
  }
}
