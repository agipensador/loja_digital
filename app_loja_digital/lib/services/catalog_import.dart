import 'dart:convert';
import 'dart:typed_data';

import 'package:app_loja_digital/helpers/br_format.dart';
import 'package:archive/archive.dart';
import 'package:csv/csv.dart';

/// Produto lido de uma planilha (antes de virar `Product`).
class ImportedProduct {
  ImportedProduct(this.key, this.name);

  final String key;
  final String name;
  String description = '';
  String category = 'Outros';
  final List<String> images = [];

  /// variante -> (preço, estoque)
  final Map<String, ({num price, int stock})> variants = {};
}

class CatalogImportResult {
  CatalogImportResult(this.products, this.format, this.warnings);
  final List<ImportedProduct> products;
  final String format;
  final List<String> warnings;
}

/// Importação de catálogo: CSV, Excel (.xlsx), JSON, texto colado ou link
/// do Google Planilhas. Colunas reconhecidas:
///
/// 1. **Exportação da Shopify** (Produtos → Exportar → CSV). Várias linhas
///    por produto, ligadas pelo `Handle`; a 1ª traz título/descrição/fotos.
///    A Nuvemshop e outras plataformas exportam algo muito parecido; colunas
///    equivalentes em português também são reconhecidas.
/// 2. **Planilha simples do app** (pode ser feita no Excel/Google Planilhas):
///    `nome; descricao; categoria; variante; preco; estoque; imagem`.
/// 3. **JSON**: lista de produtos, `{"products": [...]}` (inclusive o
///    products.json da Shopify) ou um produto só.
///
/// Aceita separador `,` ou `;` (o Excel em português salva com `;`) e preço
/// com vírgula ou ponto.
class CatalogImport {
  CatalogImport._();

  static const templateHeader =
      'nome;descricao;categoria;variante;preco;estoque;imagem';

  static const templateExample =
      'Anel Prata;Anel de prata 925;Anéis;16;89,90;10;https://exemplo.com/anel.jpg\n'
      'Anel Prata;;;18;89,90;5;\n'
      'Brinco Pérola;Brinco com pérola;Brincos;Único;59,90;8;';

  static const jsonExample = '[\n'
      '  {"nome": "Anel Prata", "descricao": "Anel de prata 925",\n'
      '   "categoria": "Anéis", "imagens": ["https://exemplo.com/anel.jpg"],\n'
      '   "variantes": [{"nome": "16", "preco": 89.90, "estoque": 10},\n'
      '                 {"nome": "18", "preco": 89.90, "estoque": 5}]},\n'
      '  {"nome": "Brinco Pérola", "preco": 59.90, "estoque": 8}\n'
      ']';

  static String _norm(String s) => s
      .trim()
      .toLowerCase()
      .replaceAll(RegExp('[áàâã]'), 'a')
      .replaceAll(RegExp('[éê]'), 'e')
      .replaceAll('í', 'i')
      .replaceAll(RegExp('[óôõ]'), 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ç', 'c');

  /// Nomes de coluna aceitos para cada campo (já normalizados).
  static const Map<String, List<String>> _aliases = {
    'key': ['handle', 'url handle', 'identificador url', 'sku pai'],
    'name': ['title', 'nome', 'name', 'titulo', 'produto'],
    'description': [
      'body (html)', 'descricao', 'description', 'body', 'body html'
    ],
    'category': [
      'type', 'product category', 'categoria', 'categorias', 'category',
      'product type'
    ],
    'variant': [
      'option1 value', 'variante', 'tamanho', 'valor da variacao 1',
      'variacao', 'option value', 'option1'
    ],
    'price': ['variant price', 'preco', 'price', 'preco promocional', 'valor'],
    'stock': [
      'variant inventory qty', 'estoque', 'quantidade', 'stock', 'inventory',
      'inventory quantity', 'qtd'
    ],
    'image': ['image src', 'imagem', 'image', 'url da imagem', 'foto'],
  };

  /// Arquivo escolhido pelo usuário: decide o formato pela extensão.
  static CatalogImportResult parseFile(String name, Uint8List bytes) {
    final ext = name.toLowerCase().split('.').last;
    if (ext == 'xlsx') {
      try {
        return parseRows(xlsxRows(bytes), 'Excel');
      } catch (_) {
        return CatalogImportResult([], 'Excel', [
          'Não consegui ler esta planilha do Excel. Salve como CSV e tente '
              'de novo.'
        ]);
      }
    }
    if (ext == 'xls') {
      return CatalogImportResult([], 'Excel antigo', [
        'Arquivos .xls (Excel antigo) não são lidos. No Excel, use "Salvar '
            'como" → .xlsx ou CSV.'
      ]);
    }
    String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      // Excel em português costuma salvar CSV em Latin-1.
      text = latin1.decode(bytes);
    }
    return parseText(text.replaceFirst('﻿', ''));
  }

  /// Texto (arquivo CSV/JSON, conteúdo colado ou baixado de um link).
  static CatalogImportResult parseText(String text) {
    final t = text.trimLeft();
    if (t.startsWith('[') || t.startsWith('{')) return parseJson(t);
    return parse(text);
  }

  /// Link do Google Planilhas → endereço que baixa a aba como CSV.
  /// A planilha precisa estar compartilhada como "qualquer pessoa com o
  /// link". Outros links são usados como estão.
  static String sheetCsvUrl(String link) {
    final url = link.trim();
    final m =
        RegExp(r'docs\.google\.com/spreadsheets/d/([\w-]+)').firstMatch(url);
    if (m == null) return url;
    if (url.contains('output=csv') || url.contains('format=csv')) return url;
    final gid = RegExp(r'[#&?]gid=(\d+)').firstMatch(url)?.group(1) ?? '0';
    return 'https://docs.google.com/spreadsheets/d/${m.group(1)}'
        '/export?format=csv&gid=$gid';
  }

  static String _unescapeXml(String s) => s
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&amp;', '&');

  static int _colIndex(String ref) {
    var n = 0;
    for (final ch in ref.replaceAll(RegExp(r'\d'), '').codeUnits) {
      n = n * 26 + (ch - 64);
    }
    return n - 1;
  }

  /// Lê a 1ª aba de um .xlsx (um zip com XML) sem pacote de Excel.
  static List<List<dynamic>> xlsxRows(Uint8List bytes) {
    final zip = ZipDecoder().decodeBytes(bytes);
    String read(String path) {
      final f = zip.findFile(path);
      return f == null ? '' : utf8.decode(f.content);
    }

    final textTag = RegExp(r'<t[^>]*>([\s\S]*?)</t>');
    final shared = <String>[
      for (final si in RegExp(r'<si>([\s\S]*?)</si>')
          .allMatches(read('xl/sharedStrings.xml')))
        _unescapeXml(
            textTag.allMatches(si.group(1)!).map((t) => t.group(1)!).join()),
    ];
    var sheet = read('xl/worksheets/sheet1.xml');
    if (sheet.isEmpty) {
      final any =
          zip.files.where((f) => f.name.startsWith('xl/worksheets/sheet'));
      if (any.isEmpty) return [];
      sheet = utf8.decode(any.first.content);
    }

    final rows = <List<dynamic>>[];
    for (final row
        in RegExp(r'<row[^>]*>([\s\S]*?)</row>').allMatches(sheet)) {
      final cells = <int, String>{};
      for (final c in RegExp(r'<c ([^>]*?)(?:/>|>([\s\S]*?)</c>)')
          .allMatches(row.group(1)!)) {
        final attrs = c.group(1)!;
        final ref = RegExp(r'r="([A-Z]+\d+)"').firstMatch(attrs)?.group(1);
        if (ref == null) continue;
        final type = RegExp(r't="(\w+)"').firstMatch(attrs)?.group(1);
        final body = c.group(2) ?? '';
        final v = RegExp(r'<v>([\s\S]*?)</v>').firstMatch(body)?.group(1);
        final String value;
        if (type == 's' && v != null) {
          value = shared[int.parse(v)];
        } else if (type == 'inlineStr') {
          value = _unescapeXml(textTag.firstMatch(body)?.group(1) ?? '');
        } else {
          value = _unescapeXml(v ?? '');
        }
        cells[_colIndex(ref)] = value;
      }
      if (cells.isEmpty) continue;
      final width = cells.keys.reduce((a, b) => a > b ? a : b) + 1;
      rows.add([for (var i = 0; i < width; i++) cells[i] ?? '']);
    }
    return rows;
  }

  /// JSON → mesmas linhas da planilha do app, e daí o parser comum.
  static CatalogImportResult parseJson(String text) {
    dynamic data;
    try {
      data = jsonDecode(text);
    } on FormatException catch (e) {
      return CatalogImportResult([], 'JSON', ['JSON inválido: ${e.message}']);
    }
    final List<dynamic> list;
    if (data is List) {
      list = data;
    } else if (data is Map && (data['products'] ?? data['produtos']) is List) {
      list = (data['products'] ?? data['produtos']) as List;
    } else if (data is Map) {
      list = [data];
    } else {
      list = const [];
    }

    dynamic field(Map m, String key) {
      final names = [key, ...?_aliases[key]];
      for (final e in m.entries) {
        final k = _norm('${e.key}').replaceAll('_', ' ');
        if (names.contains(k)) return e.value;
      }
      return null;
    }

    String str(dynamic v) => v == null ? '' : '$v';

    final rows = <List<dynamic>>[
      ['nome', 'descricao', 'categoria', 'variante', 'preco', 'estoque', 'imagem'],
    ];
    final warnings = <String>[];
    for (final (i, raw) in list.indexed) {
      if (raw is! Map) {
        warnings.add('Item ${i + 1}: não é um produto, ignorado.');
        continue;
      }
      final name = str(field(raw, 'name')).trim();
      final images = <String>[
        for (final img in (raw['images'] ?? raw['imagens'] ?? const []) as List)
          img is Map ? str(img['src'] ?? img['url']) : str(img),
        if (field(raw, 'image') is String) field(raw, 'image') as String,
      ].where((u) => u.startsWith('http')).toList();
      final variants = ((raw['variants'] ?? raw['variantes']) as List?) ?? [];
      final lines = variants.isEmpty
          ? [
              ['', str(field(raw, 'price')), str(field(raw, 'stock') ?? 0)]
            ]
          : [
              for (final v in variants.whereType<Map>())
                [
                  str(field(v, 'variant') ?? v['title'] ?? field(v, 'name')),
                  str(field(v, 'price')),
                  str(field(v, 'stock') ?? 0),
                ]
            ];
      for (final (j, l) in lines.indexed) {
        rows.add([
          name,
          j == 0 ? str(field(raw, 'description')) : '',
          j == 0 ? str(field(raw, 'category')) : '',
          l[0],
          l[1],
          l[2],
          j < images.length ? images[j] : '',
        ]);
      }
      // Fotos que sobraram (mais fotos que variantes).
      for (final img in images.skip(lines.length)) {
        rows.add([name, '', '', '', '', '', img]);
      }
    }
    final r = parseRows(rows, 'JSON');
    return CatalogImportResult(
        r.products, r.format, [...warnings, ...r.warnings]);
  }

  static CatalogImportResult parse(String text) {
    final firstLine = text.split('\n').first;
    final delimiter = ';'.allMatches(firstLine).length >
            ','.allMatches(firstLine).length
        ? ';'
        : ',';
    return parseRows(CsvDecoder(fieldDelimiter: delimiter).convert(text));
  }

  static CatalogImportResult parseRows(List<List<dynamic>> rows,
      [String? sourceFormat]) {
    if (rows.isEmpty) {
      return CatalogImportResult([], 'vazio', ['A planilha está vazia.']);
    }

    final header = rows.first.map((c) => _norm('$c')).toList();
    final col = <String, int>{};
    _aliases.forEach((field, names) {
      for (final n in names) {
        final i = header.indexOf(n);
        if (i >= 0) {
          col[field] = i;
          break;
        }
      }
    });

    final warnings = <String>[];
    if (!col.containsKey('name') || !col.containsKey('price')) {
      return CatalogImportResult([], 'desconhecido', [
        'Não encontrei as colunas de nome e preço. Use a exportação da '
            'Shopify/Nuvemshop ou o modelo do app ($templateHeader).'
      ]);
    }
    final format =
        sourceFormat ?? (header.contains('handle') ? 'Shopify' : 'planilha');

    String cell(List<dynamic> row, String field) {
      final i = col[field];
      if (i == null || i >= row.length) return '';
      return '${row[i]}'.trim();
    }

    final byKey = <String, ImportedProduct>{};
    ImportedProduct? last;
    for (var r = 1; r < rows.length; r++) {
      final row = rows[r];
      final name = cell(row, 'name');
      final keyCell = cell(row, 'key');
      // Shopify: linhas de variante/foto repetem o Handle sem o título.
      final key = keyCell.isNotEmpty
          ? keyCell
          : name.isNotEmpty
              ? _norm(name)
              : last?.key;
      if (key == null) continue;

      final product = byKey.putIfAbsent(key, () {
        if (name.isEmpty) {
          warnings.add('Linha ${r + 1}: produto sem nome, ignorado.');
        }
        return ImportedProduct(key, name);
      });
      if (product.name.isEmpty) continue;
      last = product;

      final description = cell(row, 'description');
      if (description.isNotEmpty && product.description.isEmpty) {
        product.description =
            description.replaceAll(RegExp(r'<[^>]*>'), ' ').trim();
      }
      final category = cell(row, 'category');
      if (category.isNotEmpty && product.category == 'Outros') {
        product.category = category.split('>').last.trim();
      }
      final image = cell(row, 'image');
      if (image.startsWith('http') && !product.images.contains(image)) {
        product.images.add(image);
      }

      final priceText = cell(row, 'price');
      if (priceText.isEmpty) continue; // linha só de foto (Shopify)
      final variant = cell(row, 'variant');
      final variantName =
          variant.isEmpty || _norm(variant) == 'default title' ? '' : variant;
      product.variants[variantName] = (
        price: _price(priceText),
        stock: int.tryParse(Br.digits(cell(row, 'stock'))) ?? 0,
      );
    }

    final products = byKey.values
        .where((p) => p.name.isNotEmpty && p.variants.isNotEmpty)
        .toList();
    return CatalogImportResult(products, format, warnings);
  }

  /// "89,90", "1.234,56", "R$ 10" ou número do JSON/Excel ("89.9").
  static num _price(String text) {
    final t = text.replaceAll(RegExp(r'[^\d,.\-]'), '');
    // "1.234" / "12.345.678": ponto de milhar (preço não tem 3 decimais).
    if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(t)) {
      return num.parse(t.replaceAll('.', ''));
    }
    if (RegExp(r'^-?\d+(\.\d+)?$').hasMatch(t)) return num.parse(t);
    return Br.parseMoney(text);
  }
}
