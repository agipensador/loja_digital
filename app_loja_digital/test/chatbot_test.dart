import 'package:app_loja_digital/core/platform_contact.dart';
import 'package:app_loja_digital/models/order.dart';
import 'package:app_loja_digital/models/plan.dart';
import 'package:app_loja_digital/models/store.dart';
import 'package:app_loja_digital/screens/start_store/start_store_screen.dart';
import 'package:app_loja_digital/services/chatbot.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter_test/flutter_test.dart';

ChatContext ctx({bool team = false, bool platform = false}) => ChatContext(
      storeName: 'Loja Ju',
      locations: const [],
      zones: const [],
      isTeam: team,
      isPlatformStore: platform,
    );

/// Pedido montado como o Firestore entregaria, sem precisar de Firestore.
Order order(String id, Status status,
        {String method = '', String tracking = '', String carrier = ''}) =>
    Order.fromDocument(_Doc(id, {
      'status': status.index,
      'price': 59.9,
      'date': Timestamp.fromDate(DateTime(2026, 10, 5)),
      'shipping': {
        'method': method,
        'trackingCode': tracking,
        'carrier': carrier,
      },
    }));

// ignore: subtype_of_sealed_class
class _Doc implements DocumentSnapshot<Map<String, dynamic>> {
  _Doc(this.id, this._data);
  @override
  final String id;
  final Map<String, dynamic> _data;
  @override
  Map<String, dynamic> data() => _data;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Chatbot', () {
    test('menu inicial tem 5 perguntas, na ordem padrão sem cliques', () {
      final top = Chatbot.top(ctx(), {});
      expect(top.length, 5);
      expect(top.map((i) => i.id).toList(), Chatbot.defaultCustomerTop);
    });

    test('pergunta mais clicada sobe para o topo', () {
      final top = Chatbot.top(ctx(), {'cupom': 40, 'entrega': 3});
      expect(top.first.id, 'cupom');
      expect(top[1].id, 'entrega');
    });

    test('equipe vê o menu do sistema; cliente nunca vê perguntas da equipe',
        () {
      expect(Chatbot.top(ctx(team: true), {}).first.id, 't_produto');
      expect(
          Chatbot.forContext(ctx())
              .any((i) => i.audience != ChatAudience.customer),
          isFalse);
    });

    test('perguntas de "quero minha loja" só no app da Inforizz', () {
      expect(Chatbot.top(ctx(platform: true), {}).first.id, 'p_precos');
      expect(Chatbot.forContext(ctx()).any((i) => i.id == 'p_precos'),
          isFalse);
    });

    test('texto livre encontra a pergunta certa', () {
      final r = Chatbot.reply('Vocês aceitam pix?', ctx());
      expect(r.intent?.id, 'pagamento');
      expect(r.toHuman, isFalse);
      expect(Chatbot.reply('qual o valor do frete', ctx()).intent?.id,
          'entrega');
    });

    test('dúvida específica vai para o WhatsApp', () {
      final quebrado = Chatbot.reply('Meu pedido #1234 veio quebrado', ctx());
      expect(quebrado.toHuman, isTrue);
      expect(quebrado.intent, isNull);
      expect(Chatbot.reply('fui cobrado duas vezes', ctx()).toHuman, isTrue);
      expect(Chatbot.reply('blablabla xyz', ctx()).toHuman, isTrue);
    });

    test('equipe da loja fala com a Inforizz, com a pergunta e o nome da loja',
        () {
      final url = ctx(team: true).humanUrl('Como cadastro produto?')!;
      expect(url, startsWith('https://wa.me/${PlatformContact.whatsapp}?text='));
      expect(Uri.decodeComponent(url), contains('[Loja Loja Ju — suporte]'));
    });
  });

  group('WhatsApp por unidade', () {
    final centro = Store(id: 'centro', name: 'Centro', phone: '(11) 91111-1111');
    final norte = Store(id: 'norte', name: 'Norte', phone: '(11) 92222-2222');
    final semFone = Store(id: 'sul', name: 'Sul');

    ChatContext cliente(List<Store> unidades, String atendendo) => ChatContext(
          storeName: 'Loja Ju',
          locations: unidades,
          zones: const [],
          isTeam: false,
          attendingLocationId: atendendo,
        );

    test('vai para o WhatsApp da unidade que atende o cliente', () {
      expect(cliente([centro, norte], 'centro').humanUrl('oi'),
          startsWith('https://wa.me/5511911111111'));
      final c = cliente([centro, norte], 'norte');
      expect(c.humanUrl('oi'), startsWith('https://wa.me/5511922222222'));
      expect(c.humanName, 'Loja Ju (Norte)');
    });

    test('unidade que atende sem número: vai para a que tem', () {
      expect(cliente([semFone, norte], 'sul').humanUrl('oi'),
          startsWith('https://wa.me/5511922222222'));
    });

    test('nenhuma com número: sem WhatsApp e sem cair na Inforizz', () {
      final c = cliente([semFone], 'sul');
      expect(c.hasHuman, isFalse);
      expect(c.humanUrl('oi'), isNull);
      expect(Chatbot.byId('falar_loja')!.answer(c).text,
          ChatContext.whatsappUnavailable);
    });

    test('todas as respostas montam sem erro', () {
      for (final i in Chatbot.intents) {
        expect(i.answer(ctx(team: true, platform: true)).text, isNotEmpty);
      }
    });
  });

  group('Consulta de pedido', () {
    final pronto = order('123', Status.readyForPickup, method: 'retirada');
    final pago = order('124', Status.transporting,
        method: 'correios', tracking: 'BR123', carrier: 'SEDEX');

    test('número no texto devolve a situação daquele pedido', () {
      final a = Chatbot.orderAnswer('em que pé está o pedido 123?',
          [pago, pronto], loggedIn: true)!;
      expect(a, contains('#000123'));
      expect(a, contains('Pronto para retirada'));
      expect(a, contains('Já pode retirar'));
    });

    test('aceita #000124 e mostra rastreio', () {
      final a = Chatbot.orderAnswer('cadê o #000124', [pago, pronto],
          loggedIn: true)!;
      expect(a, contains('Em transporte'));
      expect(a, contains('Rastreio (SEDEX): BR123'));
    });

    test('pedido de outra pessoa (fora da lista) não é encontrado', () {
      final a = Chatbot.orderAnswer('pedido nº 999', [pronto], loggedIn: true)!;
      expect(a, contains('Não achei o pedido #000999'));
    });

    test('"status do meu pedido" sem número lista os recentes', () {
      final a = Chatbot.orderAnswer('qual o status do meu pedido',
          [pago, pronto], loggedIn: true)!;
      expect(a, contains('#000124 — Em transporte'));
      expect(a, contains('#000123 — Pronto para retirada'));
    });

    test('sem login pede para entrar', () {
      expect(Chatbot.orderAnswer('pedido 123', [], loggedIn: false),
          contains('entre na sua conta'));
    });

    test('pergunta geral não vira consulta de pedido', () {
      for (final q in [
        'qual a forma de pagamento do pedido?',
        'como faço um pedido?',
        'posso retirar na loja?',
      ]) {
        expect(Chatbot.orderAnswer(q, [pronto], loggedIn: true), isNull,
            reason: q);
      }
    });
  });

  test('mensagem "quero este plano" leva plano, cores e materiais', () {
    final msg = StartStoreScreen.message(
      plan: PlanCatalog.multilojas,
      period: BillingPeriod.monthly,
      storeName: 'Loja da Ju',
      city: 'Campinas/SP',
      colors: [StartStoreScreen.palette.first],
      customColors: '',
      hasLogo: true,
      hasCatalog: true,
      hasMercadoPago: false,
    );
    expect(msg, contains('Quero este plano: *Multilojas*'));
    expect(msg, contains('Vermelho (#E53935)'));
    expect(msg, contains('logotipo e planilha de produtos'));
    expect(msg, contains('ainda não tenho'));
  });
}
