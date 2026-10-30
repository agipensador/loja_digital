// A esteira também é código — e é o código que ninguém testa.
//
// Um erro de indentação no YAML só aparece no push, e um `if:` esquecido num
// passo que manda o site para o ar só aparece DEPOIS de o site ir para o ar,
// na loja errada. Estes testes leem o workflow de verdade e cobram as regras
// que precisam valer sempre.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import '../../tool/web/lojas_web.dart';

/// O workflow fica na raiz do repositório; os testes rodam em
/// `app_loja_digital/`.
final _arquivo = File('../.github/workflows/web.yml');

void main() {
  late Map<dynamic, dynamic> workflow;
  late Map<dynamic, dynamic> jobs;

  setUpAll(() {
    expect(
      _arquivo.existsSync(),
      isTrue,
      reason: 'rode os testes a partir de app_loja_digital/',
    );
    workflow = loadYaml(_arquivo.readAsStringSync()) as Map;
    jobs = workflow['jobs'] as Map;
  });

  test('é YAML válido e tem gatilho e jobs', () {
    // `on` é palavra reservada no YAML 1.1: sem aspas viraria a chave `true`,
    // e o workflow nunca dispararia.
    expect(workflow.containsKey('on'), isTrue);
    expect(workflow['jobs'], isA<Map>());
  });

  test('os 3 jobs rodam no Linux (a loja não precisa de mac)', () {
    expect(jobs.keys, containsAll(['verificar', 'compilar', 'hosting']));
    for (final nome in ['verificar', 'compilar', 'hosting']) {
      expect(jobs[nome]['runs-on'], 'ubuntu-latest', reason: nome);
    }
  });

  test('o portão de qualidade roda analyze e testes antes de compilar', () {
    final comandos = _comandos(jobs['verificar']);
    expect(comandos.any((c) => c.contains('flutter analyze')), isTrue);
    expect(comandos.any((c) => c.contains('flutter test')), isTrue);
    expect(jobs['compilar']['needs'], 'verificar');
    expect(jobs['hosting']['needs'], 'compilar');
  });

  test('todo job trabalha dentro de app_loja_digital', () {
    // O repositório tem o app numa subpasta; sem isto o `flutter pub get`
    // roda na raiz e o job falha dizendo que não é um projeto Flutter.
    for (final nome in ['verificar', 'compilar']) {
      expect(
        jobs[nome]['defaults']['run']['working-directory'],
        'app_loja_digital',
        reason: nome,
      );
    }
    for (final passo in _passos(jobs['hosting'])) {
      if (passo['run'] == null) continue;
      final dentro = passo['working-directory'] == 'app_loja_digital';
      final soAviso = !'${passo['run']}'.contains('firebase-tools');
      expect(
        dentro || soAviso,
        isTrue,
        reason: 'passo "${passo['name']}" do hosting fora de app_loja_digital',
      );
    }
  });

  group('tag de release', () {
    test('o gatilho de tag casa com o formato que o Dart entende', () {
      final tags = ((workflow['on'] as Map)['push'] as Map)['tags'] as List;
      expect(tags, ['web-*-v*']);

      // O mesmo molde, preenchido: se o glob e o `lojaDaTag` discordarem, a
      // tag dispara a esteira e o build não sabe qual loja compilar.
      for (final id in lojasWeb.keys) {
        final tag = (tags.first as String)
            .replaceFirst('*', id)
            .replaceFirst('*', '1.0.0');
        expect(lojaDaTag(tag)?.storeId, id, reason: tag);
      }
    });

    test('o push filtra caminho só fora de tag', () {
      // `paths` junto com `tags` faz o GitHub comparar o diff do commit — e
      // numa tag ele pode vir vazio, engolindo o release em silêncio.
      final push = (workflow['on'] as Map)['push'] as Map;
      expect(push.containsKey('paths'), isFalse);
      expect(
        ((workflow['on'] as Map)['pull_request'] as Map)['paths'],
        contains('app_loja_digital/**'),
      );
    });

    test('quem resolve a tag é o Dart, não o shell', () {
      final comandos = _comandos(jobs['compilar']).join('\n');
      expect(comandos, contains('tool/build_web.dart --tag'));
    });
  });

  group('envio para o Hosting', () {
    test('só acontece em tag', () {
      expect(jobs['hosting']['if'], contains("github.ref_type == 'tag'"));
    });

    test('fica desligado enquanto não existir o secret', () {
      // Enquanto o dono não criar a chave, o job precisa terminar verde
      // avisando — e, principalmente, sem mandar nada para o ar.
      expect(
        '${jobs['hosting']['env']['TEM_CHAVE']}',
        contains('FIREBASE_SERVICE_ACCOUNT'),
      );
      for (final passo in _passos(jobs['hosting'])) {
        final comando = '${passo['run'] ?? ''}${passo['uses'] ?? ''}';
        final eAviso = comando.contains('::warning');
        expect(
          eAviso || '${passo['if']}' == "env.TEM_CHAVE == 'sim'",
          isTrue,
          reason: 'passo "${passo['name']}" roda sem conferir o secret',
        );
      }
    });

    test('manda só o alvo daquela loja, nunca todas', () {
      // `--only hosting` sem alvo publicaria TODAS as lojas do firebase.json,
      // inclusive as que não foram compiladas neste job (pasta vazia = loja
      // fora do ar).
      final envio = _comandos(
        jobs['hosting'],
      ).firstWhere((c) => c.contains('firebase-tools'));
      expect(envio, contains(r'--only "hosting:$LOJA"'));
      expect(envio, isNot(matches(RegExp(r'--only\s+hosting\s'))));
      expect(jobs['hosting']['env']['LOJA'], contains('needs.compilar'));
    });

    test('a chave entra por arquivo temporário, nunca no comando', () {
      final comandos = _comandos(jobs['hosting']).join('\n');
      expect(comandos, contains(r'$RUNNER_TEMP'));
      // O valor do secret só pode aparecer como variável de ambiente: na
      // linha de comando ele vaza para a lista de processos do runner.
      expect(comandos, isNot(contains(r'${{ secrets.')));
    });
  });
}

List<Map> _passos(dynamic job) => (job['steps'] as List).cast<Map>();

List<String> _comandos(dynamic job) =>
    _passos(
      job,
    ).where((p) => p['run'] != null).map((p) => '${p['run']}').toList();
