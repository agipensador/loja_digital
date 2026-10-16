import 'package:app_loja_digital/helpers/br_format.dart';
import 'package:app_loja_digital/common/custom_icon_button.dart';
import 'package:app_loja_digital/models/item_size.dart';
import 'package:app_loja_digital/models/store.dart';
import 'package:app_loja_digital/models/stores_manager.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
  /// O formulário edita o estoque da 1ª unidade; com várias unidades, as
  /// demais são ajustadas no painel de estoque.
  late final Store _location = context.read<StoresManager>().locations.first;
  late final bool _multi = context.read<StoresManager>().isMultiLocation;

  late final TextEditingController _stockController =
      TextEditingController(text: size.stockAt(_location.id!).toString());

  ItemSize get size => widget.size;

  @override
  void dispose() {
    _stockController.dispose();
    super.dispose();
  }

  void _setStock(int value) {
    size.setStockAt(_location.id!, value);
    _stockController.text = size.stockAt(_location.id!).toString();
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
            decoration: InputDecoration(
              labelText: _multi ? 'Estoque ${_location.name}' : 'Estoque',
              isDense: true,
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (int.tryParse(value ?? '') == null) return 'Inválido';
              return null;
            },
            onChanged: (value) =>
                size.setStockAt(_location.id!, int.tryParse(value) ?? 0),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          flex: 30,
          child: TextFormField(
            initialValue:
                size.price > 0 ? Br.moneyInput(size.price) : null,
            decoration: const InputDecoration(
              labelText: 'Preço',
              prefixText: 'R\$ ',
              isDense: true,
            ),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              if (Br.parseMoney(value ?? '') <= 0) {
                return 'Inválido';
              }
              return null;
            },
            onChanged: (value) =>
                size.price = Br.parseMoney(value),
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
              onTap: () => _setStock(size.stockAt(_location.id!) + 1),
            ),
            CustomIconButton(
              iconData: Icons.arrow_drop_down,
              color: Colors.black54,
              onTap: () => _setStock(size.stockAt(_location.id!) - 1),
            ),
          ],
        ),
      ],
    );
  }
}
