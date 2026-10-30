/// Remenda o `manifest.json` e o `index.html` **já compilados** com a marca
/// de uma loja.
///
/// Por que no resultado do build e não nos arquivos de `web/`: a pasta `web/`
/// é a mesma para todas as lojas. O script antigo (`tool/build_web_flavor.sh`)
/// reescrevia `web/manifest.json` e `web/index.html` no repositório — o que
/// deixava o repositório sujo depois de cada build e fazia a última loja
/// compilada "vazar" para a próxima. Aqui os arquivos versionados nunca são
/// tocados: cada `build/web_<storeId>` sai com a sua marca.
///
/// As funções deste arquivo são puras (texto entra, texto sai) justamente
/// para serem testáveis sem compilar nada — ver `test/web_pwa_test.dart`.
library;

import 'dart:convert';

import 'lojas_web.dart';

/// O `manifest.json` da PWA com o nome, a descrição e as cores da loja.
///
/// Os ícones não são mexidos aqui: eles são arquivos, e quem cuida deles é
/// o `iconesDaLoja` (`icones.dart`).
String manifestDaLoja(String manifestOriginal, LojaWeb loja) {
  final manifest = Map<String, dynamic>.from(
    jsonDecode(manifestOriginal) as Map<String, dynamic>,
  );

  manifest['name'] = loja.nome;
  manifest['short_name'] = loja.nomeCurto;
  manifest['description'] = loja.descricao;
  manifest['theme_color'] = loja.corTema;
  manifest['background_color'] = loja.corFundo;
  // A loja é brasileira e todos os textos do app estão em pt-BR. Sem isto o
  // navegador oferece tradução automática da própria interface da PWA.
  manifest['lang'] = 'pt-BR';

  return '${const JsonEncoder.withIndent('    ').convert(manifest)}\n';
}

final _titulo = RegExp(r'<title>[^<]*</title>');
final _descricao = RegExp(
  r'<meta\s+name="description"\s+content="[^"]*"\s*/?>',
);
final _tituloIos = RegExp(
  r'(<meta\s+name="apple-mobile-web-app-title"\s+content=")[^"]*(")',
);
final _corDoTema = RegExp(r'<meta\s+name="theme-color"\s+content="[^"]*"\s*/?>');
final _fimDoHead = RegExp(r'\s*</head>');

/// O `index.html` da PWA com o título, a descrição e a cor da loja.
///
/// É o que o navegador mostra enquanto o Flutter não desenhou a primeira tela
/// e o que o Google lê para indexar a loja.
String indexDaLoja(String htmlOriginal, LojaWeb loja) {
  var html = htmlOriginal;

  html = html.replaceFirst(_titulo, '<title>${_escapar(loja.nome)}</title>');
  html = html.replaceFirst(
    _descricao,
    '<meta name="description" content="${_escapar(loja.descricao)}">',
  );
  html = html.replaceFirstMapped(
    _tituloIos,
    (m) => '${m.group(1)}${_escapar(loja.nomeCurto)}${m.group(2)}',
  );

  final corDoTema = '<meta name="theme-color" content="${loja.corTema}">';
  html = _corDoTema.hasMatch(html)
      ? html.replaceFirst(_corDoTema, corDoTema)
      // O index.html do Flutter não traz `theme-color`. Entra no fim do
      // <head> para o Android pintar a barra do navegador com a cor da loja.
      : html.replaceFirst(_fimDoHead, '\n  $corDoTema\n</head>');

  return html;
}

/// Escapa o que vai para dentro de um atributo ou de um texto do HTML.
///
/// Nome de loja é digitado por pessoa: "Bolos & Cia" com `&` cru deixa o HTML
/// inválido, e aspas no nome fechariam o atributo.
String _escapar(String texto) => texto
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
