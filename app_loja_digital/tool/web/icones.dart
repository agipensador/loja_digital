/// Gera os ícones da PWA a partir do logotipo da loja.
///
/// Sem isto, toda loja vai para o ar com o ícone padrão do Flutter — na tela
/// inicial do celular do cliente, que é justamente onde a PWA quer estar.
///
/// Usa o pacote `image`, que já é dependência do app (compressão de foto no
/// cadastro de produto), e escreve só dentro de `build/web_<storeId>` — a
/// pasta `web/` do repositório não é tocada, diferente do
/// `flutter_launcher_icons`, que sobrescreveria os ícones compartilhados.
library;

import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'lojas_web.dart';

/// Lado do favicon. 32 px porque 16 px fica borrado em tela retina.
const _ladoDoFavicon = 32;

/// Quanto do ícone "maskable" o logotipo pode ocupar.
///
/// O Android recorta o ícone em círculo, losango ou quadrado arredondado,
/// garantindo apenas um círculo central de 80% do lado (a *safe zone*). Um
/// logotipo quadrado só cabe inteiro nesse círculo se tiver lado
/// `0,8 / √2 ≈ 0,566`. Daí o 0,56: é o maior quadrado que nenhum recorte
/// corta.
const _fracaoSegura = 0.56;

/// Os PNGs da PWA, do caminho dentro do build para o conteúdo do arquivo.
///
/// [logoPng] é o logotipo da loja (PNG quadrado; se não for quadrado, é
/// encaixado inteiro no centro, sem distorcer). Lança [FormatException] se o
/// PNG não puder ser lido.
Map<String, Uint8List> iconesDaLoja(Uint8List logoPng, LojaWeb loja) {
  final logo = img.decodePng(logoPng);
  if (logo == null) {
    throw FormatException('Não consegui ler o logotipo ${loja.logo} como PNG');
  }

  final fundo = _corDoHex(loja.corFundo);

  return {
    'favicon.png': _encaixar(logo, _ladoDoFavicon, 1, fundo),
    'icons/Icon-192.png': _encaixar(logo, 192, 1, fundo),
    'icons/Icon-512.png': _encaixar(logo, 512, 1, fundo),
    'icons/Icon-maskable-192.png': _encaixar(logo, 192, _fracaoSegura, fundo),
    'icons/Icon-maskable-512.png': _encaixar(logo, 512, _fracaoSegura, fundo),
  };
}

/// Desenha [logo] centralizado num quadrado de [lado] px, ocupando [fracao]
/// do lado, sobre o fundo [fundo].
Uint8List _encaixar(img.Image logo, int lado, double fracao, img.Color fundo) {
  final tela = img.Image(width: lado, height: lado, numChannels: 4);
  img.fill(tela, color: fundo);

  // Mantém a proporção: o lado maior do logotipo é que encosta no limite.
  final limite = (lado * fracao).round();
  final escala = limite / (logo.width > logo.height ? logo.width : logo.height);
  final redimensionado = img.copyResize(
    logo,
    width: (logo.width * escala).round().clamp(1, lado),
    height: (logo.height * escala).round().clamp(1, lado),
    interpolation: img.Interpolation.average,
  );

  img.compositeImage(
    tela,
    redimensionado,
    dstX: ((lado - redimensionado.width) / 2).round(),
    dstY: ((lado - redimensionado.height) / 2).round(),
  );

  return img.encodePng(tela);
}

/// `#RRGGBB` (ou `#AARRGGBB`) para cor do pacote `image`.
img.Color _corDoHex(String hex) {
  final limpo = hex.replaceFirst('#', '');
  final valor = int.tryParse(limpo, radix: 16);
  if (valor == null || (limpo.length != 6 && limpo.length != 8)) {
    throw FormatException('Cor inválida: "$hex" (esperado #RRGGBB)');
  }
  final rgb = limpo.length == 8 ? valor & 0xFFFFFF : valor;
  // Opaco de propósito: ícone "maskable" transparente aparece preto no
  // Android, e o favicon fica invisível na aba clara.
  return img.ColorRgba8((rgb >> 16) & 0xFF, (rgb >> 8) & 0xFF, rgb & 0xFF, 255);
}
