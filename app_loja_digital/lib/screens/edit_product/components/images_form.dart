import 'package:app_loja_digital/common/picked_image.dart';
import 'package:app_loja_digital/models/product.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ImagesForm extends StatelessWidget {
  const ImagesForm(this.product, {super.key});

  final Product product;

  /// Foto por link (não ocupa armazenamento da loja). Se o site de origem
  /// apagar a foto, ela some aqui também — o aviso deixa isso claro.
  static Future<String?> _askImageUrl(BuildContext context) async {
    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Adicionar imagem por link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: controller,
              keyboardType: TextInputType.url,
              decoration:
                  const InputDecoration(hintText: 'https://...'),
            ),
            const SizedBox(height: 8),
            const Text(
              'A imagem continua no site de origem: se ela for apagada lá, '
              'some aqui também. Para não depender disso, envie a foto.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(c, controller.text.trim()),
              child: const Text('Adicionar')),
        ],
      ),
    );
    controller.dispose();
    if (url == null || !url.startsWith('http')) return null;
    return url;
  }

  @override
  Widget build(BuildContext context) {
    final picker = ImagePicker();

    return FormField<List<dynamic>>(
      initialValue: List.from(product.images),
      onSaved: (images) => product.newImages = images!,
      validator: (images) {
        if (images == null || images.isEmpty) {
          return 'Adicione pelo menos uma imagem';
        }
        return null;
      },
      builder: (state) {
        Future<void> pick(ImageSource source) async {
          try {
            final XFile? file = await picker.pickImage(source: source);
            if (file != null) {
              state.value!.add(file);
              state.didChange(state.value);
            }
          } catch (e) {
            debugPrint('Erro ao selecionar imagem: $e');
          } finally {
            if (context.mounted) Navigator.of(context).pop();
          }
        }

        return Column(
          children: <Widget>[
            AspectRatio(
              aspectRatio: 1,
              child: CarouselSlider(
                options: CarouselOptions(
                  aspectRatio: 1,
                  viewportFraction: 1,
                  enableInfiniteScroll: false,
                ),
                items: [
                  ...state.value!.map<Widget>((image) {
                    return Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        PickedImage(image, fit: BoxFit.cover),
                        Align(
                          alignment: Alignment.topRight,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: CircleAvatar(
                              backgroundColor: Colors.red,
                              radius: 16,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.delete,
                                    color: Colors.white, size: 18),
                                onPressed: () {
                                  state.value!.remove(image);
                                  state.didChange(state.value);
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                  Material(
                    color: Colors.grey[100],
                    child: IconButton(
                      icon: const Icon(Icons.add_a_photo, size: 50),
                      onPressed: () {
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
                                ListTile(
                                  leading: const Icon(Icons.link),
                                  title: const Text('Link da imagem'),
                                  subtitle: const Text(
                                      'Ex.: foto do seu anúncio na Shopee'),
                                  onTap: () async {
                                    Navigator.of(context).pop();
                                    final url = await _askImageUrl(context);
                                    if (url != null) {
                                      state.value!.add(url);
                                      state.didChange(state.value);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
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
