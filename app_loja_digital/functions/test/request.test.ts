import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { CheckoutError } from '../src/domain/errors';
import {
  locationIdDoPedido,
  parseCheckoutRequest,
  somenteDigitos,
} from '../src/domain/request';
import { pedidoDeTeste } from './fakes';

function codigoDoErro(fn: () => unknown): string {
  try {
    fn();
  } catch (erro) {
    assert.ok(erro instanceof CheckoutError, `esperava CheckoutError, veio ${erro}`);
    return erro.code;
  }
  assert.fail('esperava um CheckoutError e nada foi lançado');
}

describe('parseCheckoutRequest — nada do app entra sem passar por aqui', () => {
  it('aceita um pedido bem formado', () => {
    const pedido = parseCheckoutRequest(pedidoDeTeste());
    assert.equal(pedido.storeId, 'loja_ju');
    assert.equal(pedido.items.length, 1);
    assert.equal(pedido.items[0].quantity, 2);
    assert.equal(pedido.paymentType, 'pix');
    assert.equal(pedido.payerCpf, '12345678909');
  });

  it('descarta campo que não está no contrato', () => {
    // Sem isto, um campo a mais no JSON viraria campo a mais no Firestore.
    const pedido = parseCheckoutRequest(
      pedidoDeTeste({
        total: 1,
        platformFee: 0,
        items: [
          {
            pid: 'p1',
            size: 'M',
            quantity: 1,
            locationId: 'principal',
            price: 0.01,
          },
        ],
        address: { street: 'Rua A', numero_errado: 'x', number: '10' },
      }),
    );
    assert.equal('total' in pedido, false);
    assert.deepEqual(Object.keys(pedido.items[0]).sort(), [
      'locationId',
      'pid',
      'quantity',
      'size',
    ]);
    assert.deepEqual(Object.keys(pedido.address).sort(), ['number', 'street']);
  });

  it('limpa a pontuação do CPF', () => {
    const pedido = parseCheckoutRequest(
      pedidoDeTeste({ payerCpf: '123.456.789-09' }),
    );
    assert.equal(pedido.payerCpf, '12345678909');
  });

  it('normaliza o e-mail', () => {
    const pedido = parseCheckoutRequest(
      pedidoDeTeste({ payerEmail: '  Cliente@Exemplo.COM ' }),
    );
    assert.equal(pedido.payerEmail, 'cliente@exemplo.com');
  });

  it('recusa e-mail inválido', () => {
    assert.equal(
      codigoDoErro(() => parseCheckoutRequest(pedidoDeTeste({ payerEmail: 'nada' }))),
      'pedido-invalido',
    );
  });

  it('recusa carrinho vazio', () => {
    assert.equal(
      codigoDoErro(() => parseCheckoutRequest(pedidoDeTeste({ items: [] }))),
      'carrinho-vazio',
    );
  });

  it('recusa quantidade zero, negativa, fracionada ou absurda', () => {
    for (const quantity of [0, -1, 1.5, 1000, 'dois', null]) {
      assert.equal(
        codigoDoErro(() =>
          parseCheckoutRequest(
            pedidoDeTeste({
              items: [{ pid: 'p1', size: 'M', quantity, locationId: 'principal' }],
            }),
          ),
        ),
        'pedido-invalido',
        `aceitou quantidade ${quantity}`,
      );
    }
  });

  it('recusa id de produto com caractere de caminho', () => {
    assert.equal(
      codigoDoErro(() =>
        parseCheckoutRequest(
          pedidoDeTeste({
            items: [
              { pid: '../../outro', size: 'M', quantity: 1, locationId: 'principal' },
            ],
          }),
        ),
      ),
      'pedido-invalido',
    );
  });

  it('recusa pedido sem loja ou sem chave de idempotência', () => {
    assert.equal(
      codigoDoErro(() => parseCheckoutRequest(pedidoDeTeste({ storeId: '' }))),
      'pedido-invalido',
    );
    assert.equal(
      codigoDoErro(() => parseCheckoutRequest(pedidoDeTeste({ idempotencyKey: 'curta' }))),
      'pedido-invalido',
    );
  });

  it('recusa cartão sem token', () => {
    assert.equal(
      codigoDoErro(() =>
        parseCheckoutRequest(pedidoDeTeste({ paymentType: 'card', cardToken: '' })),
      ),
      'pedido-invalido',
    );
  });

  it('aceita cartão com token e parcelas', () => {
    const pedido = parseCheckoutRequest(
      pedidoDeTeste({ paymentType: 'card', cardToken: 'tok_123', installments: 3 }),
    );
    assert.equal(pedido.paymentType, 'card');
    assert.equal(pedido.installments, 3);
  });

  it('parcelas fora de 1..12 caem em 1', () => {
    for (const installments of [0, -2, 13, 2.5, 'tres', undefined]) {
      const pedido = parseCheckoutRequest(
        pedidoDeTeste({ paymentType: 'pix', installments }),
      );
      assert.equal(pedido.installments, 1, `aceitou ${installments}`);
    }
  });

  it('forma de pagamento desconhecida vira Pix', () => {
    const pedido = parseCheckoutRequest(pedidoDeTeste({ paymentType: 'boleto' }));
    assert.equal(pedido.paymentType, 'pix');
  });

  it('item sem locationId cai na unidade padrão', () => {
    const pedido = parseCheckoutRequest(
      pedidoDeTeste({ items: [{ pid: 'p1', size: 'M', quantity: 1 }] }),
    );
    assert.equal(pedido.items[0].locationId, 'principal');
  });

  it('recusa carrinho com itens demais', () => {
    const items = Array.from({ length: 61 }, () => ({
      pid: 'p1',
      size: 'M',
      quantity: 1,
      locationId: 'principal',
    }));
    assert.equal(
      codigoDoErro(() => parseCheckoutRequest(pedidoDeTeste({ items }))),
      'pedido-invalido',
    );
  });

  it('recusa corpo que não é objeto', () => {
    for (const corpo of [null, undefined, 'texto', 42]) {
      assert.equal(
        codigoDoErro(() => parseCheckoutRequest(corpo)),
        'pedido-invalido',
        String(corpo),
      );
    }
  });

  it('lê a data preferida de entrega', () => {
    const pedido = parseCheckoutRequest(
      pedidoDeTeste({
        delivery: {
          method: 'entrega_propria',
          zoneId: 'z1',
          preferredDate: '2026-11-05T00:00:00.000Z',
        },
      }),
    );
    assert.equal(
      pedido.delivery.preferredDate?.toISOString(),
      '2026-11-05T00:00:00.000Z',
    );
  });
});

describe('locationIdDoPedido', () => {
  it('usa a unidade do primeiro item', () => {
    assert.equal(
      locationIdDoPedido([
        { pid: 'a', size: 'M', quantity: 1, locationId: 'filial' },
        { pid: 'b', size: 'M', quantity: 1, locationId: 'filial' },
      ]),
      'filial',
    );
  });

  it('recusa itens de unidades diferentes no mesmo pedido', () => {
    assert.equal(
      codigoDoErro(() =>
        locationIdDoPedido([
          { pid: 'a', size: 'M', quantity: 1, locationId: 'principal' },
          { pid: 'b', size: 'M', quantity: 1, locationId: 'filial' },
        ]),
      ),
      'pedido-invalido',
    );
  });
});

describe('somenteDigitos', () => {
  it('tira tudo que não é número', () => {
    assert.equal(somenteDigitos('123.456.789-09'), '12345678909');
    assert.equal(somenteDigitos(undefined), '');
    assert.equal(somenteDigitos(12345), '');
  });
});
