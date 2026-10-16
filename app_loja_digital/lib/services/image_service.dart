import 'package:app_loja_digital/services/usage_service.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

/// Foto enviada: URL da versão de exibição e da miniatura (listas/grades).
class UploadedImage {
  const UploadedImage(this.url, this.thumbUrl);
  final String url;
  final String thumbUrl;
}

/// Compressão antes do upload. Uma foto de celular (3–5 MB, 4000 px) vira
/// JPEG de até 1600 px (~150–300 KB) — na tela do celular não se vê
/// diferença — mais uma miniatura de 480 px (~30–50 KB) para as grades,
/// onde está a maior parte das visualizações.
///
/// Não existe "descomprimir na hora de exibir": JPEG é compressão com perda
/// e o que economiza é justamente guardar menos dados. O ganho de qualidade
/// percebida vem de mostrar a miniatura na lista e a versão grande só na
/// tela do produto.
class ImageService {
  ImageService._();

  static const int maxSide = 1600;
  static const int thumbSide = 480;
  static const int quality = 82;

  /// Cache de 1 ano: os nomes são únicos (timestamp), então uma foto nunca
  /// muda no mesmo endereço — celular e navegador podem guardar para sempre.
  static final SettableMetadata _metadata = SettableMetadata(
    contentType: 'image/jpeg',
    cacheControl: 'public, max-age=31536000, immutable',
  );

  static Uint8List _resize(Uint8List bytes, int side) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes; // formato desconhecido: envia como veio
    final oriented = img.bakeOrientation(decoded);
    final longest = oriented.width > oriented.height
        ? oriented.width
        : oriented.height;
    final resized = longest <= side
        ? oriented
        : oriented.width >= oriented.height
            ? img.copyResize(oriented, width: side)
            : img.copyResize(oriented, height: side);
    return Uint8List.fromList(img.encodeJpg(resized, quality: quality));
  }

  static Future<Uint8List> compress(Uint8List bytes, {int side = maxSide}) =>
      compute(_resizeArgs, _ResizeArgs(bytes, side));

  static Uint8List _resizeArgs(_ResizeArgs a) => _resize(a.bytes, a.side);

  /// Comprime e envia [file] para [folder] (gera também a miniatura).
  static Future<UploadedImage> upload(Reference folder, XFile file) async {
    final original = await file.readAsBytes();
    final full = await compress(original);
    final thumb = await compress(original, side: thumbSide);
    final name = DateTime.now().millisecondsSinceEpoch.toString();

    final fullRef = folder.child('$name.jpg');
    final thumbRef = folder.child('thumbs').child('$name.jpg');
    await fullRef.putData(full, _metadata);
    await thumbRef.putData(thumb, _metadata);
    await UsageService.addStorageBytes(full.length + thumb.length);

    return UploadedImage(
      await fullRef.getDownloadURL(),
      await thumbRef.getDownloadURL(),
    );
  }

  /// Apaga uma foto do nosso Storage (links externos são ignorados) e
  /// desconta do uso de armazenamento da loja.
  static Future<void> delete(String url) async {
    if (!url.contains('firebasestorage.googleapis.com')) return;
    try {
      final ref = FirebaseStorage.instance.refFromURL(url);
      final meta = await ref.getMetadata();
      await ref.delete();
      await UsageService.addStorageBytes(-(meta.size ?? 0));
    } catch (e) {
      debugPrint('Falha ao apagar imagem: $e');
    }
  }
}

class _ResizeArgs {
  const _ResizeArgs(this.bytes, this.side);
  final Uint8List bytes;
  final int side;
}
