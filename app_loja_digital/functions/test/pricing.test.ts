import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { ProductDoc } from '../src/domain/documents';
import { CheckoutError } from '../src/domain/errors';
import {
  deliveryFeeFor,
  ItemRequest,
  platformFeeFor,
  priceItems,
  priceOrder,
} from '../src/domain/pricing';
import { lojaDeTeste } from './fakes';

function produtos(): Map<string, ProductDoc> {
  return lojaDeTeste().products;
}

function item(ajustes: Partial<ItemRequest> = {}): ItemRequest {
  return { pid: 'p1', size: 'M', quantity: 1, locationId: 'principal', ...ajustes };
}

function codigoDoErro(fn: () => unknown): string {
  try {
    fn();
  } catch (erro) {
    assert.ok(erro instanceof CheckoutError, `esperava CheckoutError, veio ${erro}`);
    return erro.code;
  }
  assert.fail('esperava um CheckoutError e nada foi lançado');
}

describe('priceItems — o preço vem do Firestore', () => {
  it('usa o preço do catálogo e soma pela quantidade', () => {
    const { lines, productsPrice } = priceItems([item({ quantity: 2 })], produtos());
    assert.equal(lines.length, 1);
    assert.equal(lines[0].price, 100);
    assert.equal(lines[0].name, 'Camiseta');
    assert.equal(productsPrice, 200);
  });

  it('ignora qualquer preço que venha do app', () => {
    // O app pode mandar o que quiser no JSON; `ItemRequest` não tem preço e
    // o cálculo só olha o catálogo.
    const comPrecoFalso = {
      ...item({ quantity: 1 }),
      price: 1,
      total: 1,
    } as ItemRequest;
    const { productsPrice } = priceItems([comPrecoFalso], produtos());
    assert.equal(productsPrice, 100);
  });

  it('guarda a miniatura como imagem do item (e cai na foto grande)', () => {
    const semThumb = new Map(produtos());
    semThumb.set('p2', {
      name: 'Boné',
      images: ['grande.jpg'],
      sizes: [{ name: 'U', price: 50, stockByLocation: { principal: 3 } }],
    });
    const { lines } = priceItems(
      [item({ pid: 'p2', size: 'U' })],
      semThumb,
    );
    assert.equal(lines[0].image, 'grande.jpg');
  });

  it('recusa carrinho vazio', () => {
    assert.equal(codigoDoErro(() => priceItems([], produtos())), 'carrinho-vazio');
  });

  it('recusa produto que não existe', () => {
    assert.equal(
      codigoDoErro(() => priceItems([item({ pid: 'nao-existe' })], produtos())),
      'produto-indisponivel',
    );
  });

  it('recusa produto apagado (soft delete)', () => {
    const catalogo = produtos();
    catalogo.set('p1', { ...catalogo.get('p1')!, deleted: true });
    assert.equal(
      codigoDoErro(() => priceItems([item()], catalogo)),
      'produto-indisponivel',
    );
  });

  it('recusa tamanho que o produto não tem', () => {
    assert.equal(
      codigoDoErro(() => priceItems([item({ size: 'GG' })], produtos())),
      'tamanho-indisponivel',
    );
  });

  it('recusa quantidade acima do estoque daquela unidade', () => {
    assert.equal(
      codigoDoErro(() => priceItems([item({ size: 'G', quantity: 2 })], produtos())),
      'estoque-insuficiente',
    );
  });

  it('recusa estoque de outra unidade (o pedido é de uma unidade)', () => {
    assert.equal(
      codigoDoErro(() => priceItems([item({ locationId: 'filial' })], produtos())),
      'estoque-insuficiente',
    );
  });

  it('recusa produto sem preço cadastrado', () => {
    const catalogo = produtos();
    catalogo.set('p3', {
      name: 'Sem preço',
      sizes: [{ name: 'U', price: 0, stockByLocation: { principal: 9 } }],
    });
    assert.equal(
      codigoDoErro(() => priceItems([item({ pid: 'p3', size: 'U' })], catalogo)),
      'produto-indisponivel',
    );
  });

  it('arredonda o subtotal em 2 casas', () => {
    const catalogo = produtos();
    catalogo.set('p4', {
      name: 'Centavos',
      sizes: [{ name: 'U', price: 19.99, stockByLocation: { principal: 9 } }],
    });
    const { productsPrice } = priceItems(
      [item({ pid: 'p4', size: 'U', quantity: 3 })],
      catalogo,
    );
    assert.equal(productsPrice, 59.97);
  });
});

describe('deliveryFeeFor — frete é o que a loja cadastrou', () => {
  const loja = lojaDeTeste();

  it('retirada não custa nada', () => {
    const fee = deliveryFeeFor(
      { method: 'retirada' },
      loja.location,
      null,
      'principal',
    );
    assert.equal(fee, 0);
  });

  it('entrega própria cobra a taxa da zona, não a do app', () => {
    const fee = deliveryFeeFor(
      { method: 'entrega_propria', zoneId: 'z1', quotedFee: 0 },
      loja.location,
      loja.zone,
      'principal',
    );
    assert.equal(fee, 8);
  });

  it('entrega própria sem zona é recusada', () => {
    assert.equal(
      codigoDoErro(() =>
        deliveryFeeFor(
          { method: 'entrega_propria' },
          loja.location,
          null,
          'principal',
        ),
      ),
      'entrega-invalida',
    );
  });

  it('recusa zona de outra unidade', () => {
    assert.equal(
      codigoDoErro(() =>
        deliveryFeeFor(
          { method: 'entrega_propria', zoneId: 'z1' },
          loja.location,
          { ...loja.zone!, locationId: 'filial' },
          'principal',
        ),
      ),
      'entrega-invalida',
    );
  });

  it('Correios cobra o `shippingFee` da unidade', () => {
    const fee = deliveryFeeFor(
      { method: 'correios', quotedFee: 1 },
      loja.location,
      null,
      'principal',
    );
    assert.equal(fee, 25);
  });

  it('motoboy aceita a estimativa do app quando é MAIOR que a reserva', () => {
    const fee = deliveryFeeFor(
      { method: 'uber', quotedFee: 19.5 },
      loja.location,
      null,
      'principal',
    );
    assert.equal(fee, 19.5);
  });

  it('motoboy nunca cobra menos que o `uberFee` da unidade', () => {
    const fee = deliveryFeeFor(
      { method: 'uber', quotedFee: 0.01 },
      loja.location,
      null,
      'principal',
    );
    assert.equal(fee, 12);
  });

  it('recusa método que a unidade não oferece', () => {
    const semUber = { ...loja.location, offersUber: false };
    assert.equal(
      codigoDoErro(() =>
        deliveryFeeFor({ method: 'uber' }, semUber, null, 'principal'),
      ),
      'entrega-invalida',
    );
  });

  it('recusa método desconhecido (ou vazio)', () => {
    assert.equal(
      codigoDoErro(() =>
        deliveryFeeFor({ method: '' }, loja.location, null, 'principal'),
      ),
      'entrega-invalida',
    );
    assert.equal(
      codigoDoErro(() =>
        deliveryFeeFor({ method: 'drone' }, loja.location, null, 'principal'),
      ),
      'entrega-invalida',
    );
  });
});

describe('platformFeeFor — a taxa é sempre retida; quem paga muda', () => {
  it('loja absorve: cliente não paga nada, plataforma recebe', () => {
    const { platformFee, serviceFee } = platformFeeFor({
      serviceFee: { amount: 0.99, paidBy: 'store' },
    });
    assert.equal(platformFee, 0.99);
    assert.equal(serviceFee, 0);
  });

  it('cliente paga: entra no total dele', () => {
    const { platformFee, serviceFee } = platformFeeFor({
      serviceFee: { amount: 0.99, paidBy: 'customer' },
    });
    assert.equal(platformFee, 0.99);
    assert.equal(serviceFee, 0.99);
  });

  it('loja sem configuração usa o padrão da plataforma', () => {
    const { platformFee, serviceFee } = platformFeeFor({});
    assert.equal(platformFee, 0.99);
    assert.equal(serviceFee, 0);
  });

  it('valor negativo no banco cai no padrão', () => {
    const { platformFee } = platformFeeFor({
      serviceFee: { amount: -5, paidBy: 'customer' },
    });
    assert.equal(platformFee, 0.99);
  });
});

describe('priceOrder — o pedido inteiro', () => {
  it('soma produtos + frete + taxa do cliente', () => {
    const loja = lojaDeTeste();
    loja.store.serviceFee = { amount: 0.99, paidBy: 'customer' };
    const preco = priceOrder({
      items: [item({ quantity: 2 })],
      products: loja.products,
      store: loja.store,
      location: loja.location,
      zone: loja.zone,
      delivery: { method: 'entrega_propria', zoneId: 'z1' },
      locationId: 'principal',
    });
    assert.equal(preco.productsPrice, 200);
    assert.equal(preco.deliveryPrice, 8);
    assert.equal(preco.serviceFee, 0.99);
    assert.equal(preco.platformFee, 0.99);
    assert.equal(preco.total, 208.99);
  });

  it('quando a loja absorve a taxa, ela sai do total do cliente', () => {
    const loja = lojaDeTeste();
    const preco = priceOrder({
      items: [item()],
      products: loja.products,
      store: loja.store,
      location: loja.location,
      zone: null,
      delivery: { method: 'retirada' },
      locationId: 'principal',
    });
    assert.equal(preco.total, 100);
    assert.equal(preco.platformFee, 0.99);
    assert.equal(preco.serviceFee, 0);
  });
});
