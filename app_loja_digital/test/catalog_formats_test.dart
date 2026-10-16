import 'dart:convert';
import 'dart:typed_data';

import 'package:app_loja_digital/services/catalog_import.dart';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

/// Monta um .xlsx mínimo (zip com sharedStrings + sheet1).
Uint8List _xlsx(List<List<Object>> rows) {
  final strings = <String>[];
  int sid(String s) {
    final i = strings.indexOf(s);
    if (i >= 0) return i;
    strings.add(s);
    return strings.length - 1;
  }

  final sheet = StringBuffer('<worksheet><sheetData>');
  for (var r = 0; r < rows.length; r++) {
    sheet.write('<row r="${r + 1}">');
    for (var c = 0; c < rows[r].length; c++) {
      final ref = '${String.fromCharCode(65 + c)}${r + 1}';
      final v = rows[r][c];
      if (v is num) {
        sheet.write('<c r="$ref"><v>$v</v></c>');
      } else {
        sheet.write('<c r="$ref" t="s"><v>${sid('$v')}</v></c>');
      }
    }
    sheet.write('</row>');
  }
  sheet.write('</sheetData></worksheet>');
  final shared =
      '<sst>${strings.map((s) => '<si><t>${s.replaceAll('&', '&amp;')}</t></si>').join()}</sst>';

  final archive = Archive()
    ..addFile(ArchiveFile.bytes(
        'xl/sharedStrings.xml', utf8.encode(shared)))
    ..addFile(ArchiveFile.bytes(
        'xl/worksheets/sheet1.xml', utf8.encode(sheet.toString())));
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  test('JSON simples em português, com variantes e imagens', () {
    final r = CatalogImport.parseText(CatalogImport.jsonExample);
    expect(r.format, 'JSON');
    expect(r.products.length, 2);
    final anel = r.products.first;
    expect(anel.name, 'Anel Prata');
    expect(anel.category, 'Anéis');
    expect(anel.variants.keys, ['16', '18']);
    expect(anel.variants['16']!.price, 89.9);
    expect(anel.variants['18']!.stock, 5);
    expect(anel.images, ['https://exemplo.com/anel.jpg']);
    expect(r.products[1].variants['']!.price, 59.9);
  });

  test('JSON no formato products.json da Shopify', () {
    final r = CatalogImport.parseText(jsonEncode({
      'products': [
        {
          'title': 'Camiseta',
          'body_html': '<p>Algodão</p>',
          'product_type': 'Roupas',
          'variants': [
            {'option1': 'P', 'price': '49.90', 'inventory_quantity': 3},
            {'option1': 'M', 'price': '49.90', 'inventory_quantity': 0},
          ],
          'images': [
            {'src': 'https://cdn.shopify.com/a.jpg'},
            {'src': 'https://cdn.shopify.com/b.jpg'},
            {'src': 'https://cdn.shopify.com/c.jpg'},
          ],
        }
      ]
    }));
    final p = r.products.single;
    expect(p.description, 'Algodão');
    expect(p.category, 'Roupas');
    expect(p.variants['P']!.price, 49.9);
    expect(p.variants['P']!.stock, 3);
    expect(p.images.length, 3);
  });

  test('JSON inválido avisa em vez de quebrar', () {
    final r = CatalogImport.parseText('[{"nome": ');
    expect(r.products, isEmpty);
    expect(r.warnings.single, startsWith('JSON inválido'));
  });

  test('Excel (.xlsx) com textos e números', () {
    final bytes = _xlsx([
      ['nome', 'categoria', 'variante', 'preco', 'estoque'],
      ['Bolsa Couro', 'Bolsas', 'Única', 199.9, 4],
      ['Cinto & Fivela', 'Acessórios', 'M', 79.5, 10],
    ]);
    final r = CatalogImport.parseFile('produtos.xlsx', bytes);
    expect(r.format, 'Excel');
    expect(r.products.length, 2);
    expect(r.products.first.variants['Única']!.price, 199.9);
    expect(r.products.first.variants['Única']!.stock, 4);
    expect(r.products[1].name, 'Cinto & Fivela');
  });

  test('.xls antigo explica como salvar', () {
    final r = CatalogImport.parseFile('antigo.xls', Uint8List(0));
    expect(r.products, isEmpty);
    expect(r.warnings.single, contains('.xlsx'));
  });

  test('link do Google Planilhas vira download em CSV', () {
    expect(
      CatalogImport.sheetCsvUrl(
          'https://docs.google.com/spreadsheets/d/1AbC-xyz_9/edit#gid=123'),
      'https://docs.google.com/spreadsheets/d/1AbC-xyz_9/export?format=csv&gid=123',
    );
    expect(
      CatalogImport.sheetCsvUrl(
          'https://docs.google.com/spreadsheets/d/1AbC/edit?usp=sharing'),
      endsWith('/export?format=csv&gid=0'),
    );
    expect(CatalogImport.sheetCsvUrl('https://exemplo.com/produtos.csv'),
        'https://exemplo.com/produtos.csv');
  });

  test('preço com ponto decimal (Excel/JSON) e com vírgula (BR)', () {
    final csv = CatalogImport.parseText(
        'nome;preco;estoque\nA;89.90;1\nB;1.234,56;1\nC;1.234;1');
    expect(csv.products[0].variants['']!.price, 89.9);
    expect(csv.products[1].variants['']!.price, 1234.56);
    expect(csv.products[2].variants['']!.price, 1234);
  });
}
