import 'package:flutter/material.dart';

/// Imagem de rede com placeholder elegante em caso de erro/carregamento.
/// Mantém o mesmo espaço do item (o link/toque por cima continua funcionando).
class StoreImage extends StatelessWidget {
  const StoreImage(this.url, {super.key, this.fit = BoxFit.cover});

  final String? url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) return const _Placeholder();
    return Image.network(
      url!,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => const _Placeholder(),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const _Placeholder(loading: true);
      },
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
