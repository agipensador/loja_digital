import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { ProductDoc, sizeStockAt } from '../src/domain/documents';
import { CheckoutError } from '../src/domain/errors';
import { ItemRequest } from '../src/domain/pricing';
import { planejarReserva } from '../src/domain/reserva';

/**
 * O que roda DENTRO da transação: é aqui que uma compra simultânea tem de ser
 * barrada, senão a última peça é vendida duas vezes.
 */

function camiseta(estoqueM = 5, estoqueG = 1): ProductDoc {
  return {
    name: 'Camiseta',
    sizes: [
      { name: 'M', price: 100, stockByLocation: { principal: estoqueM, filial: 3 } },
      { name: 'G', price: 120, stockByLocation: { principal: estoqueG } },
    ],
  };
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

describe('planejarReserva', () => {
  it('numera o pedido a partir do contador', () => {
    const plano = planejarReserva({
      items: [item()],
      products: new Map([['p1', camiseta()]]),
      numeroAtual: 41,
    });
    assert.equal(plano.proximoNumero, 42);
  });

  it('a primeira venda da loja é o pedido 1', () => {
    const plano = planejarReserva({
      items: [item()],
      products: new Map([['p1', camiseta()]]),
      numeroAtual: 0,
    });
    assert.equal(plano.proximoNumero, 1);
  });

  it('baixa o estoque só da unidade comprada', () => {
    const plano = planejarReserva({
      items: [item({ quantity: 2 })],
      products: new Map([['p1', camiseta()]]),
      numeroAtual: 0,
    });
    const sizes = plano.novosSizes.get('p1')!;
    assert.equal(sizeStockAt(sizes[0], 'principal'), 3);
    assert.equal(sizeStockAt(sizes[0], 'filial'), 3);
  });

  it('baixa vários tamanhos do mesmo produto numa só escrita', () => {
    const plano = planejarReserva({
      items: [item({ quantity: 2 }), item({ size: 'G', quantity: 1 })],
      products: new Map([['p1', camiseta()]]),
      numeroAtual: 0,
    });
    assert.equal(plano.novosSizes.size, 1);
    const sizes = plano.novosSizes.get('p1')!;
    assert.equal(sizeStockAt(sizes[0], 'principal'), 3);
    assert.equal(sizeStockAt(sizes[1], 'principal'), 0);
  });

  it('barra a compra quando o estoque mudou desde o cálculo (venda simultânea)', () => {
    // O cálculo viu 1 peça; na hora da transação outra pessoa já levou.
    assert.equal(
      codigoDoErro(() =>
        planejarReserva({
          items: [item({ size: 'G', quantity: 1 })],
          products: new Map([['p1', camiseta(5, 0)]]),
          numeroAtual: 0,
        }),
      ),
      'estoque-insuficiente',
    );
  });

  it('barra produto apagado entre o cálculo e a transação', () => {
    assert.equal(
      codigoDoErro(() =>
        planejarReserva({
          items: [item()],
          products: new Map([['p1', { ...camiseta(), deleted: true }]]),
          numeroAtual: 0,
        }),
      ),
      'produto-indisponivel',
    );
  });

  it('barra produto que sumiu entre o cálculo e a transação', () => {
    assert.equal(
      codigoDoErro(() =>
        planejarReserva({
          items: [item()],
          products: new Map([['p1', null]]),
          numeroAtual: 0,
        }),
      ),
      'produto-indisponivel',
    );
  });

  it('barra tamanho renomeado entre o cálculo e a transação', () => {
    assert.equal(
      codigoDoErro(() =>
        planejarReserva({
          items: [item({ size: 'M' })],
          products: new Map([
            ['p1', { name: 'Camiseta', sizes: [{ name: 'Médio', price: 100 }] }],
          ]),
          numeroAtual: 0,
        }),
      ),
      'tamanho-indisponivel',
    );
  });

  it('não altera o documento original (só devolve o novo array)', () => {
    const produto = camiseta();
    planejarReserva({
      items: [item({ quantity: 2 })],
      products: new Map([['p1', produto]]),
      numeroAtual: 0,
    });
    assert.equal(sizeStockAt(produto.sizes![0], 'principal'), 5);
  });
});
