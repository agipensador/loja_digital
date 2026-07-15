import 'package:app_loja_digital/common/picked_image.dart';
import 'package:app_loja_digital/models/product.dart';
import 'package:app_loja_digital/models/section.dart';
import 'package:app_loja_digital/models/section_item.dart';
import 'package:app_loja_digital/screens/select_product/select_product_screen.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class EditSectionImages extends StatelessWidget {
  const EditSectionImages({super.key});

  @override
  Widget build(BuildContext context) {
    final section = context.watch<Section>();
    final picker = ImagePicker();

    Future<void> pick(ImageSource source) async {
      Navigator.of(context).pop();
      try {
        final XFile? file = await picker.pickImage(source: source);
        if (file != null) {
          section.addItem(SectionItem(image: file));
        }
      } catch (e) {
        debugPrint('Erro ao selecionar imagem: $e');
      }
    }

    void showAddSheet() {
      showModalBottomSheet(
        context: context,
        builder: (_) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Câmera'),
                onTap: () => pick(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galeria'),
                onTap: () => pick(ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
    }

    Future<void> linkProduct(SectionItem item) async {
      final Product? product = await Navigator.of(context).push<Product>(
        MaterialPageRoute(builder: (_) => const SelectProductScreen()),
      );
      if (product != null) {
        section.setItemProduct(item, product.id);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final item in section.items)
              _EditImageTile(
                item: item,
                onRemove: () => section.removeItem(item),
                onLink: () => linkProduct(item),
              ),
            InkWell(
              onTap: showAddSheet,
              child: Container(
                width: 90,
                height: 90,
                color: Colors.white24,
                child: const Icon(Icons.add_a_photo, color: Colors.white),
              ),
            ),
          ],
        ),
        if (section.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              section.error!,
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }
}

class _EditImageTile extends StatelessWidget {
  const _EditImageTile({
    required this.item,
    required this.onRemove,
    required this.onLink,
  });

  final SectionItem item;
  final VoidCallback onRemove;
  final VoidCallback onLink;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 90,
      height: 90,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          PickedImage(item.image, fit: BoxFit.cover),
          Align(
            alignment: Alignment.topRight,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                color: Colors.red,
                child: const Icon(Icons.close,
                    color: Colors.white, size: 18),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: GestureDetector(
              onTap: onLink,
              child: Container(
                color: item.product != null
                    ? Colors.green
                    : Colors.black54,
                padding: const EdgeInsets.all(2),
                child: Icon(
                  item.product != null ? Icons.link : Icons.link_off,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
