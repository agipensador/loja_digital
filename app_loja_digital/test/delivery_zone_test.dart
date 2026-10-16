import 'package:app_loja_digital/models/delivery_zone.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeliveryZone.coversDistrict', () {
    test('casa bairro ignorando acento e caixa', () {
      final zone = DeliveryZone(districts: ['São João', 'Centro']);
      expect(zone.coversDistrict('sao joao'), isTrue);
      expect(zone.coversDistrict('SÃO JOÃO'), isTrue);
      expect(zone.coversDistrict('Centro'), isTrue);
      expect(zone.coversDistrict('Outro bairro'), isFalse);
    });
  });

  group('DeliveryZone.nextDates', () {
    test('retorna apenas os dias da semana configurados', () {
      // segunda(1) e quinta(4)
      final zone = DeliveryZone(weekdays: [1, 4]);
      final dates = zone.nextDates(count: 4);
      expect(dates.length, 4);
      for (final d in dates) {
        expect([1, 4], contains(d.weekday));
      }
      // datas em ordem crescente
      for (var i = 1; i < dates.length; i++) {
        expect(dates[i].isAfter(dates[i - 1]), isTrue);
      }
    });

    test('sem dias configurados, não há datas', () {
      final zone = DeliveryZone();
      expect(zone.nextDates(), isEmpty);
    });
  });
}
