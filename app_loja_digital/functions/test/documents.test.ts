import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { sizeStockAt, withStockAt } from '../src/domain/documents';
import { restoreStock } from '../src/domain/pricing';
import { canSell, subscriptionStatus, toDate } from '../src/domain/store_status';

describe('estoque por unidade', () => {
  it('lê o formato novo (stockByLocation)', () => {
    const size = { name: 'M', price: 10, stockByLocation: { principal: 4, filial: 2 } };
    assert.equal(sizeStockAt(size, 'principal'), 4);
    assert.equal(sizeStockAt(size, 'filial'), 2);
    assert.equal(sizeStockAt(size, 'nao-existe'), 0);
  });

  it('lê o formato antigo (stock único) como estoque da unidade padrão', () => {
    const size = { name: 'M', price: 10, stock: 7 };
    assert.equal(sizeStockAt(size, 'principal'), 7);
    assert.equal(sizeStockAt(size, 'filial'), 0);
  });

  it('ao gravar, migra o formato antigo para stockByLocation', () => {
    const migrado = withStockAt({ name: 'M', price: 10, stock: 7 }, 'principal', 5);
    assert.deepEqual(migrado, {
      name: 'M',
      price: 10,
      stockByLocation: { principal: 5 },
    });
    // O campo antigo sai, igual ao que o app grava em `ItemSize.toMap`.
    assert.equal('stock' in migrado, false);
  });

  it('ao gravar, preserva as outras unidades', () => {
    const atualizado = withStockAt(
      { name: 'M', price: 10, stockByLocation: { principal: 4, filial: 2 } },
      'principal',
      1,
    );
    assert.deepEqual(atualizado.stockByLocation, { principal: 1, filial: 2 });
  });

  it('nunca grava estoque negativo', () => {
    const atualizado = withStockAt({ name: 'M', price: 10 }, 'principal', -3);
    assert.equal(atualizado.stockByLocation!.principal, 0);
  });
});

describe('restoreStock — devolver o estoque', () => {
  it('devolve a quantidade de cada item', () => {
    const sizes = restoreStock(
      {
        name: 'Camiseta',
        sizes: [
          { name: 'M', price: 100, stockByLocation: { principal: 3 } },
          { name: 'G', price: 120, stockByLocation: { principal: 0 } },
        ],
      },
      [
        { size: 'M', quantity: 2, locationId: 'principal' },
        { size: 'G', quantity: 1, locationId: 'principal' },
      ],
    );
    assert.equal(sizes[0].stockByLocation!.principal, 5);
    assert.equal(sizes[1].stockByLocation!.principal, 1);
  });

  it('ignora tamanho que o lojista renomeou depois da compra', () => {
    // Devolver estoque não pode falhar: o resto do pedido tem de voltar.
    const sizes = restoreStock(
      { name: 'Camiseta', sizes: [{ name: 'M', price: 100, stockByLocation: { principal: 1 } }] },
      [
        { size: 'M', quantity: 1, locationId: 'principal' },
        { size: 'tamanho-que-nao-existe-mais', quantity: 9, locationId: 'principal' },
      ],
    );
    assert.equal(sizes.length, 1);
    assert.equal(sizes[0].stockByLocation!.principal, 2);
  });
});

describe('toDate', () => {
  it('entende Timestamp do Admin SDK, Date, número e texto', () => {
    const data = new Date('2026-10-30T06:00:00Z');
    assert.deepEqual(toDate({ toDate: () => data }), data);
    assert.deepEqual(toDate(data), data);
    assert.deepEqual(toDate(data.getTime()), data);
    assert.deepEqual(toDate('2026-10-30T06:00:00.000Z'), data);
  });

  it('devolve null para o que não é data', () => {
    for (const valor of [null, undefined, '', 'ontem', {}, NaN]) {
      assert.equal(toDate(valor), null, String(valor));
    }
  });
});

describe('subscriptionStatus / canSell — loja suspensa não vende', () => {
  const hoje = new Date('2026-10-30T12:00:00Z');
  const dias = (n: number) =>
    new Date(hoje.getTime() + n * 24 * 3600 * 1000);

  it('trial em curso vende', () => {
    const store = { subscription: { trialEndsAt: dias(10) } };
    assert.equal(subscriptionStatus(store, hoje), 'trial');
    assert.equal(canSell(store, hoje), true);
  });

  it('mensalidade paga vende', () => {
    const store = {
      subscription: { trialEndsAt: dias(-30), paidUntil: dias(15) },
    };
    assert.equal(subscriptionStatus(store, hoje), 'active');
    assert.equal(canSell(store, hoje), true);
  });

  it('venceu mas está na carência de 5 dias: ainda vende', () => {
    const store = {
      subscription: { trialEndsAt: dias(-30), paidUntil: dias(-2) },
    };
    assert.equal(subscriptionStatus(store, hoje), 'overdue');
    assert.equal(canSell(store, hoje), true);
  });

  it('passou da carência: suspensa, não vende', () => {
    const store = {
      subscription: { trialEndsAt: dias(-30), paidUntil: dias(-6) },
    };
    assert.equal(subscriptionStatus(store, hoje), 'suspended');
    assert.equal(canSell(store, hoje), false);
  });

  it('loja desativada pela plataforma não vende, mesmo paga', () => {
    const store = {
      active: false,
      subscription: { trialEndsAt: dias(-30), paidUntil: dias(15) },
    };
    assert.equal(canSell(store, hoje), false);
  });

  it('loja sem assinatura registrada não vende (padrão seguro)', () => {
    assert.equal(subscriptionStatus({}, hoje), 'suspended');
    assert.equal(canSell({}, hoje), false);
  });
});
