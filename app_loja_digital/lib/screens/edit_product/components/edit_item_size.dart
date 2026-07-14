import 'package:app_loja_digital/common/custom_icon_button.dart';
import 'package:app_loja_digital/models/item_size.dart';
import 'package:flutter/material.dart';

class EditItemSize extends StatefulWidget {
  const EditItemSize({
    super.key,
    required this.size,
    required this.onRemove,
  });

  final ItemSize size;
  final VoidCallback onRemove;

  @override
  State<EditItemSize> createState() => _EditItemSizeState();
}

class _EditItemSizeState extends State<EditItemSize> {
  late final TextEditingController _stockController =
      TextEditingController(text: widget.size.stock.toString());

  ItemSize get size => widget.size;

  @override
  void dispose() {
    _stockController.dispose();
    super.dispose();
  }

  void _setStock(int value) {
    final clamped = value < 0 ? 0 : value;
    size.stock = clamped;
    _stockController.text = clamped.toString();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(
          flex: 30,
          child: TextFormField(
            initialValue: size.name,
            decoration: const InputDecoration(
              labelText: 'Título',
              isDense: true,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Inválido';
              return null;
            },
            onChanged: (value) => size.name = value,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          flex: 25,
          child: TextFormField(
            controller: _stockController,
            decoration: const InputDecoration(
              labelText: 'Estoque',
              isDense: true,
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (int.tryParse(value ?? '') == null) return 'Inválido';
              return null;
            },
            onChanged: (value) => size.stock = int.tryParse(value) ?? 0,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          flex: 30,
          child: TextFormField(
            initialValue:
                size.price > 0 ? size.price.toStringAsFixed(2) : null,
            decoration: const InputDecoration(
              labelText: 'Preço',
              prefixText: 'R\$ ',
              isDense: true,
            ),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              if (num.tryParse((value ?? '').replaceAll(',', '.')) == null) {
                return 'Inválido';
              }
              return null;
            },
            onChanged: (value) =>
                size.price = num.tryParse(value.replaceAll(',', '.')) ?? 0,
          ),
        ),
        CustomIconButton(
          iconData: Icons.remove,
          color: Colors.red,
          onTap: widget.onRemove,
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CustomIconButton(
              iconData: Icons.arrow_drop_up,
              color: Colors.black54,
              onTap: () => _setStock(size.stock + 1),
            ),
            CustomIconButton(
              iconData: Icons.arrow_drop_down,
              color: Colors.black54,
              onTap: () => _setStock(size.stock - 1),
            ),
          ],
        ),
      ],
    );
  }
}
