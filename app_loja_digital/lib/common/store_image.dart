import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Imagem de rede com placeholder em caso de erro/carregamento.
///
/// - Celular: cache em disco (`cached_network_image`) — cada foto é baixada
///   uma vez e reaproveitada nas próximas aberturas.
/// - Web: o navegador já cacheia (as fotos sobem com Cache-Control de 1 ano)
///   e o modo `fallback` usa a tag <img> para fotos de outros sites (ex.:
///   links da Shopee), que o Flutter Web não consegue ler por CORS.
class StoreImage extends StatelessWidget {
  const StoreImage(this.url, {super.key, this.fit = BoxFit.cover});

  final String? url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final u = url;
    if (u == null || u.isEmpty) return const _Placeholder();

    if (kIsWeb) {
      return Image.network(
        u,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
        errorBuilder: (_, __, ___) => const _Placeholder(),
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : const _Placeholder(loading: true),
      );
    }

    return CachedNetworkImage(
      imageUrl: u,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      placeholder: (_, __) => const _Placeholder(loading: true),
      errorWidget: (_, __, ___) => const _Placeholder(),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({this.loading = false});
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEDEDED),
      alignment: Alignment.center,
      child: loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(Icons.image_outlined,
              color: Colors.grey[400], size: 36),
    );
  }
}
