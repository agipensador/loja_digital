import 'package:app_loja_digital/models/item_size.dart';
import 'package:app_loja_digital/models/product.dart';
import 'package:app_loja_digital/models/staff_member.dart';
import 'package:app_loja_digital/models/store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Estoque por unidade', () {
    test('formato antigo (stock único) vira estoque da unidade padrão', () {
      final size = ItemSize.fromMap({'name': 'P', 'price': 10, 'stock': 7});
      expect(size.stockAt(kDefaultLocationId), 7);
      expect(size.stock, 7);
    });

    test('total soma as unidades; nunca fica negativo', () {
      final size = ItemSize(stockByLocation: {'cwb': 3, 'sp': 2});
      expect(size.stock, 5);
      size.setStockAt('sp', -4);
      expect(size.stockAt('sp'), 0);
      expect(size.hasStockAt('cwb'), isTrue);
      expect(size.hasStockAt('ssa'), isFalse);
    });

    test('produto sabe em quais unidades está disponível', () {
      final product = Product(sizes: [
        ItemSize(name: 'P', stockByLocation: {'cwb': 0, 'sp': 4}),
        ItemSize(name: 'M', stockByLocation: {'ssa': 1}),
      ]);
      expect(product.locationsWithStock, {'sp', 'ssa'});
      expect(product.hasStockAt('cwb'), isFalse);
      expect(product.stockAt('sp'), 4);
    });

    test('ida e volta pelo Firestore preserva o estoque por unidade', () {
      final size = ItemSize(name: 'G', price: 5, stockByLocation: {'sp': 9});
      final back = ItemSize.fromMap(size.toMap());
      expect(back.stockAt('sp'), 9);
    });
  });

  group('Unidade física', () {
    test('atende pela cidade/UF ignorando caixa e espaços', () {
      final store = Store(city: 'Curitiba', state: 'PR');
      expect(store.servesCity(' curitiba ', 'pr'), isTrue);
      expect(store.servesCity('São Paulo', 'SP'), isFalse);
    });

    test('unidade sem cidade cadastrada não atende ninguém', () {
      expect(Store(legacyAddress: 'Rua X').servesCity('Curitiba', 'PR'),
          isFalse);
    });
  });

  group('Funcionário', () {
    test('sem unidades vinculadas = trabalha em todas', () {
      final m = StaffMember(uid: 'a');
      expect(m.worksAt('cwb'), isTrue);
      m.locationIds = ['sp'];
      expect(m.worksAt('cwb'), isFalse);
      expect(m.worksAt('sp'), isTrue);
    });

    test('permissões padrão não incluem excluir produto', () {
      expect(StaffMember.defaultPerms.contains(Perm.productsDelete), isFalse);
      expect(StaffMember.defaultPerms.contains(Perm.productsEdit), isTrue);
    });
  });
}
