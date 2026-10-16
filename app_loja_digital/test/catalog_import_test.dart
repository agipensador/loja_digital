import 'package:app_loja_digital/helpers/br_format.dart';
import 'package:app_loja_digital/services/catalog_import.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Importação de catálogo', () {
    test('exportação da Shopify: variantes e fotos pelo Handle', () {
      const csv = 'Handle,Title,Body (HTML),Type,Option1 Name,Option1 Value,'
          'Variant Price,Variant Inventory Qty,Image Src\n'
          'anel-prata,Anel Prata,<p>Prata 925</p>,Anéis,Tamanho,16,89.90,10,'
          'https://cdn.shopify.com/a1.jpg\n'
          'anel-prata,,,,,18,89.90,5,https://cdn.shopify.com/a2.jpg\n'
          'brinco,Brinco Pérola,,Brincos,Title,Default Title,59.90,8,\n';
      final r = CatalogImport.parse(csv);
      expect(r.format, 'Shopify');
      expect(r.products.length, 2);
      final anel = r.products.first;
      expect(anel.name, 'Anel Prata');
      expect(anel.description, 'Prata 925');
      expect(anel.category, 'Anéis');
      expect(anel.images.length, 2);
      expect(anel.variants['16']!.stock, 10);
      expect(anel.variants['18']!.price, 89.90);
      // "Default Title" = produto sem variante.
      expect(r.products.last.variants.keys, ['']);
    });

    test('planilha do app com ; e preço com vírgula', () {
      final csv =
          '${CatalogImport.templateHeader}\n${CatalogImport.templateExample}';
      final r = CatalogImport.parse(csv);
      expect(r.format, 'planilha');
      expect(r.products.length, 2);
      expect(r.products.first.variants.length, 2);
      expect(r.products.first.variants['16']!.price, 89.90);
    });

    test('sem colunas de nome/preço avisa o formato esperado', () {
      final r = CatalogImport.parse('a,b,c\n1,2,3');
      expect(r.products, isEmpty);
      expect(r.warnings.single, contains('nome e preço'));
    });
  });

  group('Formato brasileiro', () {
    test('dinheiro, CEP e CPF', () {
      // intl usa espaço não separável entre "R$" e o valor.
      expect(Br.money(1234.5).replaceAll(' ', ' '), 'R\$ 1.234,50');
      expect(Br.parseMoney('1.234,56'), 1234.56);
      expect(Br.parseMoney('89.90'), 89.90);
      expect(Br.cep('93010000'), '93010-000');
      expect(Br.isValidCpf('529.982.247-25'), isTrue);
      expect(Br.isValidCpf('111.111.111-11'), isFalse);
      expect(Br.isValidCpf('529.982.247-24'), isFalse);
    });
  });
}
