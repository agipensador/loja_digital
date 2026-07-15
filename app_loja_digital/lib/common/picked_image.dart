import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Exibe uma imagem que pode ser:
/// - String: URL já salva (Image.network)
/// - XFile: imagem recém-selecionada (Image.memory via bytes) — funciona em
///   Web e mobile, ao contrário de Image.file, que não roda no Flutter Web.
class PickedImage extends StatelessWidget {
  const PickedImage(this.image, {super.key, this.fit = BoxFit.cover});

  final dynamic image;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (image is String) {
      return Image.network(image as String, fit: fit);
    }
    if (image is XFile) {
      return FutureBuilder<Uint8List>(
        future: (image as XFile).readAsBytes(),
        builder: (_, snapshot) {
          if (snapshot.hasData) {
            return Image.memory(snapshot.data!, fit: fit);
          }
          return const Center(child: CircularProgressIndicator());
        },
      );
    }
    return Container(color: Colors.grey[200]);
  }
}
