// A PWA de cada loja é a vitrine que o cliente abre no navegador — e o
// título da aba, o nome do atalho e o ícone são decididos no BUILD, não em
// tempo de execução. Errar isso não dá erro nenhum: o site sobe funcionando,
// só que chamado "app_loja_digital" com o ícone do Flutter.
//
// Estes testes cobram as três coisas que ninguém percebe quebrando:
//   1. o remendo da marca (manifest + index) faz o que promete;
//   2. o catálogo de lojas, o firebase.json e o .firebaserc concordam;
//   3. a pasta web/ compartilhada não tem o nome de nenhuma loja dentro.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../tool/web/icones.dart';
import '../tool/web/lojas_web.dart';
import '../tool/web/pwa.dart';

const _loja = LojaWeb(
  storeId: 'loja_teste',
  nome: 'Bolos & Cia "da esquina"',
  nomeCurto: 'Bolos & Cia',
  descricao: 'Bolos <caseiros> & doces',
  logo: 'flavors/lojateste/icon.png',
  corTema: '#112233',
  corFundo: '#FFEEDD',
);

void main() {
  group('manifest da loja', () {
    late Map<String, dynamic> manifest;

    setUpAll(() {
      final original = File('web/manifest.json').readAsStringSync();
      manifest =
          jsonDecode(manifestDaLoja(original, _loja)) as Map<String, dynamic>;
    });

    test('nome, descrição e cores são os da loja', () {
      expect(manifest['name'], _loja.nome);
      expect(manifest['short_name'], _loja.nomeCurto);
      expect(manifest['description'], _loja.descricao);
      expect(manifest['theme_color'], '#112233');
      expect(manifest['background_color'], '#FFEEDD');
      expect(manifest['lang'], 'pt-BR');
    });

    test('mantém o que não é da loja (ícones, display, start_url)', () {
      // Se o remendo apagar os ícones, o celular não oferece "instalar".
      expect(manifest['icons'], hasLength(4));
      expect(manifest['display'], 'standalone');
      expect(manifest['start_url'], '.');
    });
  });

  group('index.html da loja', () {
    late String html;

    setUpAll(() {
      html = indexDaLoja(File('web/index.html').readAsStringSync(), _loja);
    });

    test('título, descrição e título do iOS são os da loja', () {
      expect(html, contains('<title>Bolos &amp; Cia &quot;da esquina&quot;</title>'));
      expect(
        html,
        contains(
          '<meta name="description" content="Bolos &lt;caseiros&gt; &amp; doces">',
        ),
      );
      expect(
        html,
        contains(
          '<meta name="apple-mobile-web-app-title" content="Bolos &amp; Cia">',
        ),
      );
    });

    test('nada do nome antigo sobra', () {
      expect(html, isNot(contains('app_loja_digital')));
      expect(html, isNot(contains('Inforizz Lojas')));
    });

    test('a cor da loja pinta a barra do navegador', () {
      expect(html, contains('<meta name="theme-color" content="#112233">'));
      // Uma só, senão o navegador usa a primeira (que seria a da plataforma).
      expect(RegExp('name="theme-color"').allMatches(html), hasLength(1));
    });

    test('insere a cor quando o index não tem theme-color', () {
      const semCor = '<!DOCTYPE html><html lang="pt-BR"><head>'
          '<title>x</title></head><body></body></html>';
      final remendado = indexDaLoja(semCor, _loja);
      expect(remendado, contains('<meta name="theme-color" content="#112233">'));
      expect(remendado.indexOf('theme-color'), lessThan(remendado.indexOf('</head>')));
    });

    test('o idioma da página é pt-BR', () {
      // Sem `lang`, o navegador oferece traduzir a loja e leitor de tela lê
      // os textos em português com fonética de inglês.
      expect(html, contains('<html lang="pt-BR">'));
    });
  });

  group('catálogo de lojas', () {
    test('toda loja tem marca completa e plausível', () {
      expect(lojasWeb, isNotEmpty);
      lojasWeb.forEach((id, loja) {
        expect(loja.storeId, id, reason: 'a chave do mapa é o storeId');
        expect(loja.nome.trim(), isNotEmpty);
        expect(loja.descricao.trim(), isNotEmpty);
        expect(
          loja.nomeCurto.length,
          lessThanOrEqualTo(12),
          reason: '$id: o Android corta o nome do atalho em ~12 caracteres',
        );
        for (final cor in [loja.corTema, loja.corFundo]) {
          expect(cor, matches(RegExp(r'^#[0-9A-Fa-f]{6}$')), reason: id);
        }
        expect(loja.logo, startsWith('flavors/'), reason: id);
        expect(loja.pastaDoBuild, 'build/web_$id');
      });
    });

    test('a loja_ju (primeira a ir para o ar) está no catálogo', () {
      expect(lojasWeb.containsKey('loja_ju'), isTrue);
    });

    test('tag de release aponta para a loja certa', () {
      expect(lojaDaTag('web-loja_ju-v1.0.0')?.storeId, 'loja_ju');
      expect(versaoDaTag('web-loja_ju-v1.0.0'), '1.0.0');
      expect(lojaDaTag(' web-loja_ju-v2 ')?.storeId, 'loja_ju');
    });

    test('tag de loja desconhecida ou fora do formato não publica nada', () {
      expect(lojaDaTag('web-loja_que_nao_existe-v1'), isNull);
      expect(lojaDaTag('v1.0.0'), isNull);
      expect(lojaDaTag('web-loja_ju'), isNull);
      expect(lojaDaTag('web--v1'), isNull);
      expect(versaoDaTag('v1.0.0'), isNull);
    });
  });

  group('firebase.json e .firebaserc', () {
    late List<dynamic> hosting;
    late Map<String, dynamic> alvos;

    setUpAll(() {
      final config =
          jsonDecode(File('firebase.json').readAsStringSync()) as Map;
      hosting = config['hosting'] as List<dynamic>;
      final firebaserc =
          jsonDecode(File('.firebaserc').readAsStringSync()) as Map;
      alvos = ((firebaserc['targets']
                  as Map)['loja-digital-ju0714']
              as Map)['hosting'] as Map<String, dynamic>;
    });

    test('cada loja do catálogo tem alvo de hosting nos dois arquivos', () {
      for (final loja in lojasWeb.values) {
        final entrada = hosting.cast<Map>().firstWhere(
              (h) => h['target'] == loja.alvoDeHosting,
              orElse: () => throw StateError(
                'firebase.json sem o alvo "${loja.alvoDeHosting}"',
              ),
            );
        expect(
          entrada['public'],
          loja.pastaDoBuild,
          reason: '${loja.storeId}: o alvo publicaria a pasta errada',
        );
        expect(
          alvos[loja.alvoDeHosting],
          isNotEmpty,
          reason: '.firebaserc sem o site do alvo "${loja.alvoDeHosting}"',
        );
      }
    });

    test('nenhum alvo de hosting sem loja no catálogo', () {
      for (final entrada in hosting.cast<Map>()) {
        expect(
          lojasWeb.containsKey(entrada['target']),
          isTrue,
          reason: 'alvo "${entrada['target']}" não existe em lojas_web.dart',
        );
      }
      for (final alvo in alvos.keys) {
        expect(lojasWeb.containsKey(alvo), isTrue, reason: alvo);
      }
    });

    test('o site é uma SPA: toda rota cai no index.html', () {
      for (final entrada in hosting.cast<Map>()) {
        final rewrites = entrada['rewrites'] as List;
        expect(rewrites, isNotEmpty, reason: '${entrada['target']}');
        expect(rewrites.first, {'source': '**', 'destination': '/index.html'});
      }
    });

    test('index.html e o carregador do Flutter não ficam em cache', () {
      // Sem isto, o cliente continua vendo a versão antiga da loja depois de
      // cada deploy, até o cache do navegador vencer.
      for (final entrada in hosting.cast<Map>()) {
        final headers = (entrada['headers'] as List).cast<Map>();
        final semCache = headers.firstWhere(
          (h) => (h['headers'] as List).cast<Map>().any(
                (c) => c['key'] == 'Cache-Control' && c['value'] == 'no-cache',
              ),
          orElse: () =>
              throw StateError('${entrada['target']}: sem regra de no-cache'),
        );
        for (final arquivo in [
          'index.html',
          'flutter_bootstrap.js',
          'flutter_service_worker.js',
          'main.dart.js',
        ]) {
          expect(semCache['source'], contains(arquivo));
        }
      }
    });
  });

  group('pasta web/ compartilhada', () {
    test('não tem o nome de nenhuma loja escrito dentro', () {
      // A pasta web/ é a mesma para todas as lojas. Nome de loja aqui vaza
      // para o site das outras.
      for (final arquivo in ['web/index.html', 'web/manifest.json']) {
        final conteudo = File(arquivo).readAsStringSync();
        for (final loja in lojasWeb.values) {
          expect(conteudo, isNot(contains(loja.nome)), reason: arquivo);
          expect(conteudo, isNot(contains(loja.storeId)), reason: arquivo);
        }
      }
    });

    test('não sobrou o texto padrão do flutter create', () {
      for (final arquivo in ['web/index.html', 'web/manifest.json']) {
        final conteudo = File(arquivo).readAsStringSync();
        expect(conteudo, isNot(contains('A new Flutter project')),
            reason: arquivo);
        expect(conteudo, isNot(contains('app_loja_digital')), reason: arquivo);
      }
    });
  });

  group('ícones da PWA', () {
    late Map<String, Uint8List> icones;

    setUpAll(() {
      icones = iconesDaLoja(_logoDeTeste(), _loja);
    });

    test('gera os 4 ícones do manifest e o favicon', () {
      final manifest = jsonDecode(
        manifestDaLoja(File('web/manifest.json').readAsStringSync(), _loja),
      ) as Map<String, dynamic>;
      final noManifest = (manifest['icons'] as List)
          .cast<Map>()
          .map((i) => i['src'] as String)
          .toSet();

      expect(icones.keys, containsAll(noManifest));
      expect(icones.keys, contains('favicon.png'));
      expect(icones, hasLength(5));
    });

    test('cada ícone é um PNG quadrado do tamanho que o manifest promete', () {
      final lados = {
        'favicon.png': 32,
        'icons/Icon-192.png': 192,
        'icons/Icon-512.png': 512,
        'icons/Icon-maskable-192.png': 192,
        'icons/Icon-maskable-512.png': 512,
      };
      lados.forEach((caminho, lado) {
        final png = img.decodePng(icones[caminho]!);
        expect(png, isNotNull, reason: caminho);
        expect(png!.width, lado, reason: caminho);
        expect(png.height, lado, reason: caminho);
      });
    });

    test('o maskable deixa margem: o recorte do Android não corta o logo', () {
      final maskable = img.decodePng(icones['icons/Icon-maskable-512.png']!)!;
      // Canto = fundo da loja (#FFEEDD); centro = o logotipo (vermelho).
      final canto = maskable.getPixel(2, 2);
      expect([canto.r, canto.g, canto.b], [0xFF, 0xEE, 0xDD]);
      final centro = maskable.getPixel(256, 256);
      expect([centro.r, centro.g, centro.b], [255, 0, 0]);

      // E o logo tem que ocupar a área central, não o ícone inteiro.
      final naBorda = maskable.getPixel(100, 256);
      expect([naBorda.r, naBorda.g, naBorda.b], [0xFF, 0xEE, 0xDD]);
    });

    test('o ícone normal usa o espaço todo', () {
      final normal = img.decodePng(icones['icons/Icon-512.png']!)!;
      final centro = normal.getPixel(256, 256);
      expect([centro.r, centro.g, centro.b], [255, 0, 0]);
      final quaseBorda = normal.getPixel(10, 256);
      expect([quaseBorda.r, quaseBorda.g, quaseBorda.b], [255, 0, 0]);
    });

    test('logotipo que não é PNG dá erro claro, não ícone em branco', () {
      expect(
        () => iconesDaLoja(Uint8List.fromList([1, 2, 3]), _loja),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

/// Um logotipo quadrado vermelho, para não depender de arquivo no disco.
Uint8List _logoDeTeste() {
  final logo = img.Image(width: 64, height: 64, numChannels: 4);
  img.fill(logo, color: img.ColorRgba8(255, 0, 0, 255));
  return img.encodePng(logo);
}
