import 'package:app_loja_digital/models/delivery_option.dart';
import 'package:app_loja_digital/models/delivery_zone.dart';
import 'package:app_loja_digital/models/item_size.dart';
import 'package:app_loja_digital/models/order.dart';
import 'package:app_loja_digital/models/product.dart';
import 'package:app_loja_digital/models/staff_member.dart';
import 'package:app_loja_digital/models/store.dart';
import 'package:app_loja_digital/models/supplier.dart';
import 'package:app_loja_digital/services/shipping_quote_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Opções de entrega da unidade', () {
    final loja = Store(
      id: 'principal',
      name: 'Loja Ju',
      city: 'Novo Hamburgo',
      state: 'RS',
      offersPickup: true,
      offersShipping: true,
      shippingFee: 20,
      offersOwnDelivery: true,
      offersUber: true,
      uberFee: 15,
    );
    final saoLeopoldo = DeliveryZone(
        name: 'São Leopoldo', fee: 10, districts: ['São Leopoldo']);

    test('mostra entrega própria só quando há área para o endereço', () {
      final sem = DeliveryOption.forLocation(loja, null);
      expect(sem.map((o) => o.method),
          isNot(contains(DeliveryMethods.ownDelivery)));
      final com = DeliveryOption.forLocation(loja, saoLeopoldo);
      expect(com.first.method, DeliveryMethods.ownDelivery);
      expect(com.first.fee, 10);
    });

    test('valores fixos: retirada grátis, Uber e Correios da unidade', () {
      final options = {
        for (final o in DeliveryOption.forLocation(loja, null)) o.method: o.fee
      };
      expect(options[DeliveryMethods.pickup], 0);
      expect(options[DeliveryMethods.uber], 15);
      expect(options[DeliveryMethods.correios], 20);
    });

    test('área cobre por cidade ou por bairro, sem acento', () {
      expect(saoLeopoldo.covers(district: 'Centro', city: 'sao leopoldo'),
          isTrue);
      final bairros = DeliveryZone(districts: ['Rio Branco']);
      expect(bairros.covers(district: 'Rio Branco', city: 'Novo Hamburgo'),
          isTrue);
      expect(bairros.covers(district: 'Centro', city: 'Novo Hamburgo'),
          isFalse);
    });
  });

  group('Estimativa do motoboy', () {
    test('Novo Hamburgo → São Leopoldo: ~9 km, saída + valor por km × 1,3', () {
      const nh = (lat: -29.6783, lng: -51.1306);
      const sl = (lat: -29.7600, lng: -51.1472);
      final km = ShippingQuoteService.distanceKm(nh, sl);
      expect(km, inInclusiveRange(8, 11));
      final loja = Store(uberBaseFee: 7, uberPerKm: 1.8);
      final fee = ShippingQuoteService.uberFromDistance(loja, km);
      expect(fee, closeTo(7 + 1.8 * km * 1.3, 0.01));
    });
  });

  group('Troca de entrega proposta pela loja', () {
    test('Correios R\$ 20 → entrega da loja R\$ 10 devolve R\$ 10', () {
      final change = DeliveryChange(
        method: 'entrega_propria',
        fee: 10,
        previousMethod: 'correios',
        previousFee: 20,
      );
      expect(change.difference, -10);
      final adj = OrderAdjustment(amount: -change.difference);
      expect(adj.isRefund, isTrue);
      expect(adj.amount, 10);
    });

    test('duas trocas: devolver 10 e depois pagar 5 = devolver 5', () {
      final pendente = OrderAdjustment(amount: 10);
      final segunda = DeliveryChange(
          method: 'uber', fee: 15, previousMethod: 'entrega_propria',
          previousFee: 10);
      expect(roundMoney(pendente.amount - segunda.difference), 5);
    });

    test('troca mais cara vira diferença a pagar', () {
      final change = DeliveryChange(
          method: 'uber', fee: 25, previousMethod: 'retirada', previousFee: 0);
      expect(OrderAdjustment(amount: -change.difference).isRefund, isFalse);
    });
  });

  test('dinheiro com 2 casas', () {
    expect(roundMoney(559.4000000000001), 559.4);
    expect(roundMoney(0.1 + 0.2), 0.3);
  });

  group('Linha do tempo', () {
    test('status novos entram no fim (gravado por índice)', () {
      expect(Status.canceled.index, 0);
      expect(Status.delivered.index, 3);
      expect(Status.pendingPayment.index, 4);
      expect(Status.readyForPickup.index, 5);
    });
  });

  group('Reposição pelo WhatsApp', () {
    test('número sem DDI ganha 55; mensagem lista só quantidades > 0', () {
      final s = Supplier(name: 'Distribuidora X', whatsapp: '(51) 99999-0000',
          contact: 'Carla');
      expect(s.waNumber, '5551999990000');
      final text = RestockMessage.text(
        supplier: s,
        storeName: 'Loja Ju',
        locationName: 'Centro',
        items: [
          RestockItem(label: 'Anel A (16)', quantity: 100),
          RestockItem(label: 'Anel B', quantity: 0),
        ],
      );
      expect(text, contains('Olá, Carla!'));
      expect(text, contains('Anel A (16): 100 un.'));
      expect(text, isNot(contains('Anel B')));
      expect(RestockMessage.link(s, text).toString(),
          startsWith('https://wa.me/5551999990000?text='));
    });

    test('precisa repor quando o estoque da unidade chega no limite', () {
      final p = Product(lowStockThreshold: 3, sizes: [
        ItemSize(name: 'U', stockByLocation: {'a': 3, 'b': 10}),
      ]);
      expect(p.needsRestockAt('a'), isTrue);
      expect(p.needsRestockAt('b'), isFalse);
    });
  });

  group('Papéis', () {
    test('gerente começa com tudo; funcionário com o básico', () {
      final gerente = StaffMember(uid: 'g', role: StaffRole.manager);
      final func = StaffMember(uid: 'f');
      expect(gerente.perms, Perm.values.toSet());
      expect(func.can(Perm.productsDelete), isFalse);
      expect(func.role.label, 'Funcionário');
    });
  });
}
