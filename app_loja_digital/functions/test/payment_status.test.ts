import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import {
  CheckoutStatus,
  deveAplicar,
  lerStatusDoPagamento,
  OrderStatus,
} from '../src/domain/payment_status';

describe('lerStatusDoPagamento', () => {
  it('aprovado confirma o pedido', () => {
    const r = lerStatusDoPagamento('approved');
    assert.equal(r.acao, 'confirmar');
    assert.equal(r.checkoutStatus, 'paid');
  });

  it('Pix esperando e cartão em análise continuam aguardando', () => {
    for (const status of ['pending', 'in_process', 'in_mediation']) {
      const r = lerStatusDoPagamento(status);
      assert.equal(r.acao, 'aguardar', status);
      assert.equal(r.checkoutStatus, 'pending', status);
    }
  });

  it('cartão só AUTORIZADO (sem captura) não confirma o pedido', () => {
    // O dinheiro ainda não é da loja — confirmar aqui entregaria o produto
    // antes de receber.
    const r = lerStatusDoPagamento('authorized');
    assert.equal(r.acao, 'aguardar');
  });

  it('recusado e cancelado devolvem o estoque', () => {
    for (const status of ['rejected', 'cancelled']) {
      const r = lerStatusDoPagamento(status);
      assert.equal(r.acao, 'cancelar', status);
      assert.equal(r.checkoutStatus, 'failed', status);
    }
  });

  it('estorno e chargeback cancelam e marcam estornado', () => {
    for (const status of ['refunded', 'charged_back']) {
      const r = lerStatusDoPagamento(status);
      assert.equal(r.acao, 'estornar', status);
      assert.equal(r.checkoutStatus, 'refunded', status);
    }
  });

  it('status desconhecido não mexe no pedido', () => {
    const r = lerStatusDoPagamento('status_que_o_mp_inventou');
    assert.equal(r.acao, 'aguardar');
    assert.equal(r.mpStatus, 'status_que_o_mp_inventou');
  });
});

describe('deveAplicar — idempotência do webhook', () => {
  it('o mesmo aviso repetido não tem efeito', () => {
    const estados: CheckoutStatus[] = ['pending', 'paid', 'failed', 'refunded'];
    for (const estado of estados) {
      assert.equal(deveAplicar(estado, estado), false, estado);
    }
  });

  it('pendente aceita qualquer resultado', () => {
    assert.equal(deveAplicar('pending', 'paid'), true);
    assert.equal(deveAplicar('pending', 'failed'), true);
    assert.equal(deveAplicar('pending', 'refunded'), true);
  });

  it('checkout novo (sem status) aceita o primeiro resultado', () => {
    assert.equal(deveAplicar(undefined, 'paid'), true);
  });

  it('pago só muda para estornado', () => {
    assert.equal(deveAplicar('paid', 'refunded'), true);
    assert.equal(deveAplicar('paid', 'failed'), false);
    assert.equal(deveAplicar('paid', 'pending'), false);
  });

  it('estornado é final: nada reabre', () => {
    assert.equal(deveAplicar('refunded', 'paid'), false);
    assert.equal(deveAplicar('refunded', 'pending'), false);
    assert.equal(deveAplicar('refunded', 'failed'), false);
  });

  it('falho/vencido não volta a pago (aviso fora de ordem)', () => {
    // O estoque já voltou para o catálogo; "pagar" depois não pode ressuscitar
    // o pedido sem alguém conferir.
    assert.equal(deveAplicar('failed', 'paid'), false);
    assert.equal(deveAplicar('expired', 'paid'), false);
    // Mas um estorno depois da falha é registrado.
    assert.equal(deveAplicar('failed', 'refunded'), true);
  });
});

describe('OrderStatus', () => {
  it('bate com os índices do enum Status do app', () => {
    // lib/models/order.dart: a ordem é gravada por ÍNDICE no Firestore.
    assert.deepEqual(OrderStatus, {
      canceled: 0,
      preparing: 1,
      transporting: 2,
      delivered: 3,
      pendingPayment: 4,
      readyForPickup: 5,
    });
  });
});
