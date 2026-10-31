/// Catálogo das lojas que vão para a web (PWA + Firebase Hosting).
///
/// O app é **um só** para todas as lojas: o que muda é o `STORE_ID` (tenant
/// no Firestore — ver `lib/core/tenant.dart`). Dentro do app, nome e cores da
/// loja vêm do banco (`stores/{storeId}/config/appearance`), e o admin troca
/// quando quiser.
///
/// Só que a web tem uma parte que o navegador precisa ANTES do app carregar:
/// o título da aba, o nome do atalho na tela inicial do celular, a descrição
/// que aparece no Google e a cor da barra do navegador. Nada disso pode
/// esperar o Firestore responder. É isso — e só isso — que mora aqui.
///
/// Loja nova na web = uma entrada neste mapa + um alvo de hosting no
/// `firebase.json` e no `.firebaserc`. O `test/web_pwa_test.dart` cobra que os
/// três concordem, então esquecer um dos lados quebra o teste, não o deploy.
///
/// Trocar o nome de uma loja = uma linha aqui (ou `--nome` na linha de
/// comando, para testar antes de commitar).
library;

/// A marca de uma loja na web, do ponto de vista do navegador.
class LojaWeb {
  const LojaWeb({
    required this.storeId,
    required this.nome,
    required this.nomeCurto,
    required this.descricao,
    required this.logo,
    this.corTema = corTemaPadrao,
    this.corFundo = corFundoPadrao,
  });

  /// Cor da barra do navegador e do ícone. Padrão = cor principal do
  /// `ThemeManager` (`lib/models/theme_manager.dart`), para a loja que ainda
  /// não personalizou nada não ficar com o azul do Flutter.
  static const corTemaPadrao = '#047D8D';

  /// Fundo da splash da PWA. Branco de propósito: é a mesma splash nativa de
  /// todas as lojas (`flutter_native_splash.yaml`).
  static const corFundoPadrao = '#FFFFFF';

  /// Tenant no Firestore e sufixo do alvo de hosting (`hosting:<storeId>`).
  final String storeId;

  /// Título da aba e nome da PWA.
  final String nome;

  /// Nome embaixo do ícone na tela inicial. O Android corta em ~12
  /// caracteres, por isso é um campo separado e não um `substring` do [nome].
  final String nomeCurto;

  /// `<meta name="description">` e `description` do manifest — é o texto que
  /// aparece no resultado de busca.
  final String descricao;

  /// Logotipo da loja (PNG quadrado, de preferência ≥ 512 px), de onde saem
  /// os ícones da PWA. Caminho relativo à raiz do app.
  ///
  /// Mesma pasta que o `tool/new_flavor.sh` usa para o ícone do app nativo,
  /// para a loja ter um logotipo só. Arquivo ausente = o build mantém os
  /// ícones padrão e avisa.
  final String logo;

  final String corTema;
  final String corFundo;

  /// Pasta de saída do build (`firebase.json` → `public`).
  String get pastaDoBuild => 'build/web_$storeId';

  /// Alvo de hosting (`firebase deploy --only hosting:<alvo>`).
  String get alvoDeHosting => storeId;
}

/// As lojas que têm (ou vão ter) site.
///
/// `loja_ju` e `loja_gi` são as duas lojas criadas no ar em 08/10/2026 —
/// ver `docs/STATUS.md`. O site de cada uma só existe depois que o dono roda
/// o `firebase hosting:sites:create` (ver `docs/PUBLICAR_WEB.md`).
const lojasWeb = <String, LojaWeb>{
  'loja_ju': LojaWeb(
    storeId: 'loja_ju',
    nome: 'Loja Ju',
    nomeCurto: 'Loja Ju',
    descricao: 'Loja Ju: veja o catálogo, monte seu carrinho e receba em casa.',
    logo: 'flavors/lojaju/icon.png',
  ),
  'loja_gi': LojaWeb(
    storeId: 'loja_gi',
    nome: 'Loja Gi',
    nomeCurto: 'Loja Gi',
    descricao: 'Loja Gi: veja o catálogo, monte seu carrinho e receba em casa.',
    logo: 'flavors/lojagi/icon.png',
  ),
};

/// Prefixo das tags que publicam um site: `web-<storeId>-v<versão>`.
///
/// Exemplo: `web-loja_ju-v1.0.0`. O `_` do `storeId` é aceito; o que separa
/// os campos é o `-v`.
final _tagDeRelease = RegExp(r'^web-([a-z0-9_]+)-v(.+)$');

/// A loja de uma tag de release web, ou `null` se a tag não é desse formato
/// (ou aponta para uma loja que não está no catálogo).
///
/// É a esteira (`.github/workflows/web.yml`) que faz essa pergunta: a tag é a
/// única informação que ela tem para saber qual site publicar.
LojaWeb? lojaDaTag(String tag) {
  final achado = _tagDeRelease.firstMatch(tag.trim());
  if (achado == null) return null;
  return lojasWeb[achado.group(1)];
}

/// A versão escrita na tag (`web-loja_ju-v1.2.3` → `1.2.3`), ou `null`.
String? versaoDaTag(String tag) =>
    _tagDeRelease.firstMatch(tag.trim())?.group(2);
