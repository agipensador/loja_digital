/// Compila a PWA de uma loja e põe a marca dela no resultado.
///
///   dart run tool/build_web.dart loja_ju
///   dart run tool/build_web.dart loja_ju --base-href /loja-ju/
///   dart run tool/build_web.dart --tag web-loja_ju-v1.0.0
///   dart run tool/build_web.dart loja_ju --nome "Loja da Ju" --sem-build
///
/// Sai em `build/web_<storeId>`, que é o `public` do alvo de hosting daquela
/// loja no `firebase.json`. **Não publica nada** — no fim imprime o comando
/// de deploy para quem for publicar. Ver `docs/PUBLICAR_WEB.md`.
library;

import 'dart:io';
import 'dart:typed_data';

import 'web/icones.dart';
import 'web/lojas_web.dart';
import 'web/pwa.dart';

Future<void> main(List<String> argumentos) async {
  final opcoes = _Opcoes.ler(argumentos);
  if (opcoes == null) {
    stderr.writeln(_ajuda);
    exitCode = 64; // EX_USAGE
    return;
  }

  if (!File('pubspec.yaml').existsSync()) {
    stderr.writeln('Rode a partir da pasta app_loja_digital/.');
    exitCode = 1;
    return;
  }

  final loja = opcoes.loja;
  final pasta = Directory(loja.pastaDoBuild);
  stdout.writeln('==> ${loja.nome} (${loja.storeId})');

  if (opcoes.comBuild) {
    final codigo = await _compilar(loja, opcoes.baseHref);
    if (codigo != 0) {
      stderr.writeln('flutter build web falhou (código $codigo).');
      exitCode = codigo;
      return;
    }
  } else if (!pasta.existsSync()) {
    stderr.writeln('${pasta.path} não existe — rode sem --sem-build.');
    exitCode = 1;
    return;
  }

  _marcar(pasta, loja);
  _gerarIcones(pasta, loja);

  stdout.writeln('''
==> Pronto: ${pasta.path}

Para ver antes de publicar:
  (cd ${pasta.path} && python -m http.server 8000)

Para publicar (quem tem permissão):
  firebase deploy --only hosting:${loja.alvoDeHosting} --project $_projeto''');
}

const _projeto = 'loja-digital-ju0714';

String get _ajuda => '''
Uso:
  dart run tool/build_web.dart <storeId> [opções]
  dart run tool/build_web.dart --tag web-<storeId>-v<versão> [opções]

Opções:
  --base-href <caminho>  Caminho onde o site é servido (padrão: /).
  --nome <nome>          Troca o nome da loja só neste build.
  --sem-build            Só remenda um build que já existe.

Lojas: ${lojasWeb.keys.join(', ')}''';

/// `flutter build web` da loja, com a saída aparecendo ao vivo.
Future<int> _compilar(LojaWeb loja, String baseHref) async {
  final argumentos = [
    'build',
    'web',
    '--release',
    '--dart-define=STORE_ID=${loja.storeId}',
    '--base-href',
    baseHref,
    '--output',
    loja.pastaDoBuild,
  ];
  stdout.writeln('==> flutter ${argumentos.join(' ')}');
  // runInShell porque no Windows `flutter` é um .bat.
  final processo = await Process.start(
    'flutter',
    argumentos,
    runInShell: true,
    mode: ProcessStartMode.inheritStdio,
  );
  return processo.exitCode;
}

/// Põe nome, descrição e cor da loja no `manifest.json` e no `index.html`.
void _marcar(Directory pasta, LojaWeb loja) {
  final manifest = File('${pasta.path}/manifest.json');
  final index = File('${pasta.path}/index.html');
  for (final arquivo in [manifest, index]) {
    if (!arquivo.existsSync()) {
      throw StateError('${arquivo.path} não existe — o build web falhou?');
    }
  }
  manifest.writeAsStringSync(manifestDaLoja(manifest.readAsStringSync(), loja));
  index.writeAsStringSync(indexDaLoja(index.readAsStringSync(), loja));
  stdout.writeln('==> manifest.json e index.html com a marca da loja');
}

/// Gera os ícones da PWA a partir do logotipo da loja, se ele existir.
void _gerarIcones(Directory pasta, LojaWeb loja) {
  final logo = File(loja.logo);
  if (!logo.existsSync()) {
    stdout.writeln(
      '''
==> ⚠ Sem logotipo em ${loja.logo}: o site vai para o ar com o ícone padrão
    do Flutter. Coloque um PNG quadrado (≥ 512 px) nesse caminho e rode de
    novo (o mesmo arquivo serve de ícone do app nativo — tool/new_flavor.sh).''',
    );
    return;
  }
  final icones = iconesDaLoja(Uint8List.fromList(logo.readAsBytesSync()), loja);
  icones.forEach((caminho, bytes) {
    File('${pasta.path}/$caminho')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes);
  });
  stdout.writeln('==> ${icones.length} ícones gerados de ${loja.logo}');
}

/// O que a linha de comando pediu.
class _Opcoes {
  _Opcoes({required this.loja, required this.baseHref, required this.comBuild});

  final LojaWeb loja;
  final String baseHref;
  final bool comBuild;

  /// Devolve `null` quando os argumentos não fazem sentido (quem chamou
  /// imprime a ajuda).
  static _Opcoes? ler(List<String> argumentos) {
    String? storeId;
    String? tag;
    String? nome;
    var baseHref = '/';
    var comBuild = true;

    // `i` fica fora do laço de propósito: `proximo()` avança o índice, e em
    // `for (var i = ...)` cada iteração ganharia uma cópia nova de `i`.
    var i = 0;
    String? proximo() => i + 1 < argumentos.length ? argumentos[++i] : null;

    for (; i < argumentos.length; i++) {
      final argumento = argumentos[i];
      switch (argumento) {
        case '--tag':
          tag = proximo();
        case '--base-href':
          baseHref = proximo() ?? '';
        case '--nome':
          nome = proximo();
        case '--sem-build':
          comBuild = false;
        case '-h' || '--help':
          return null;
        default:
          if (argumento.startsWith('-') || storeId != null) return null;
          storeId = argumento;
      }
    }

    final loja = tag != null ? lojaDaTag(tag) : lojasWeb[storeId];
    if (loja == null) return null;
    if (!baseHref.startsWith('/') || !baseHref.endsWith('/')) return null;

    return _Opcoes(
      loja: nome == null ? loja : _comNome(loja, nome),
      baseHref: baseHref,
      comBuild: comBuild,
    );
  }

  static LojaWeb _comNome(LojaWeb loja, String nome) => LojaWeb(
    storeId: loja.storeId,
    nome: nome,
    nomeCurto: nome,
    descricao: loja.descricao,
    logo: loja.logo,
    corTema: loja.corTema,
    corFundo: loja.corFundo,
  );
}
