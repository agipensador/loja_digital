import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { CheckoutDoc } from '../src/data/repository';
import { CheckoutStatus } from '../src/domain/payment_status';
import { assinarParaTeste } from '../src/domain/signature';
import {
  AvisoRecebido,
  DependenciasDoAviso,
  processarAviso,
} from '../src/webhook/processar_aviso';
import { FakeMercadoPago, FakeRepository, semLog } from './fakes';

const segredo = 'segredo-do-painel';
const pagamentoId = '112233445566';
const requestId = 'req-1';
const tsSegundos = 1795000000;
const agora = () => new Date(tsSegundos * 1000);

function checkout(status: CheckoutStatus = 'pending'): CheckoutDoc {
  return {
    id: 'chave-1',
    storeId: 'loja_ju',
    orderId: '7',
    userId: 'uid-cliente',
    status,
    total: 200,
    platformFee: 0.99,
    paymentType: 'pix',
    mpPaymentId: pagamentoId,
    items: [{ pid: 'p1', size: 'M', quantity: 2, locationId: 'principal' }],
  };
}

function aviso(ajustes: Partial<AvisoRecebido> = {}): AvisoRecebido {
  return {
    headers: {
      'x-signature': assinarParaTeste({
        dataId: pagamentoId,
        requestId,
        secret: segredo,
        tsSegundos,
      }),
      'x-request-id': requestId,
    },
    body: {
      id: 987654,
      type: 'payment',
      action: 'payment.updated',
      data: { id: pagamentoId },
    },
    query: {},
    ...ajustes,
  };
}

function deps(
  repo: FakeRepository,
  mp: FakeMercadoPago,
): DependenciasDoAviso {
  return { repo, mp, segredoDoWebhook: segredo, agora, log: semLog() };
}

describe('processarAviso — assinatura', () => {
  it('recusa com 401 e não toca no banco quando a assinatura é inválida', async () => {
    const repo = new FakeRepository({ checkoutPorPagamento: checkout() });
    const mp = new FakeMercadoPago();
    const r = await processarAviso(
      deps(repo, mp),
      aviso({ headers: { 'x-signature': 'ts=1,v1=falsificado' } }),
    );

    assert.equal(r.status, 401);
    // Nada foi lido nem gravado: é o que impede liberar pedido sem pagar.
    assert.deepEqual(repo.nomesChamados(), []);
    assert.deepEqual(mp.leituras, []);
  });

  it('recusa aviso sem assinatura', async () => {
    const repo = new FakeRepository({ checkoutPorPagamento: checkout() });
    const r = await processarAviso(
      deps(repo, new FakeMercadoPago()),
      aviso({ headers: {} }),
    );
    assert.equal(r.status, 401);
    assert.deepEqual(repo.nomesChamados(), []);
  });

  it('recusa aviso assinado para OUTRO pagamento', async () => {
    const repo = new FakeRepository({ checkoutPorPagamento: checkout() });
    const r = await processarAviso(
      deps(repo, new FakeMercadoPago()),
      aviso({
        body: {
          id: 1,
          type: 'payment',
          data: { id: 'outro-pagamento' },
        },
      }),
    );
    assert.equal(r.status, 401);
  });
});

describe('processarAviso — pagamento aprovado', () => {
  it('confirma o pedido lendo o status NO MP, não no corpo do aviso', async () => {
    const repo = new FakeRepository({
      checkoutPorPagamento: checkout('pending'),
      credenciais: { accessToken: 'TEST-token-da-loja' },
    });
    const mp = new FakeMercadoPago({
      ler: { id: pagamentoId, status: 'approved', detalheDoStatus: 'accredited' },
    });

    const r = await processarAviso(
      deps(repo, mp),
      // O corpo mente dizendo "cancelado"; vale o que o MP responde.
      aviso({
        body: {
          id: 987654,
          type: 'payment',
          status: 'cancelled',
          data: { id: pagamentoId },
        },
      }),
    );

    assert.equal(r.status, 200);
    assert.deepEqual(mp.leituras, [pagamentoId]);
    assert.equal(mp.tokensUsados[0], 'TEST-token-da-loja');
    const confirmacao = repo.chamada('confirmarPedido')!;
    assert.equal(confirmacao.storeId, 'loja_ju');
    assert.equal(confirmacao.checkoutId, 'chave-1');
    assert.equal(confirmacao.mpStatus, 'approved');
    assert.equal(repo.chamada('liberarReserva'), undefined);
  });

  it('aceita o data.id vindo na query (formato antigo do MP)', async () => {
    const repo = new FakeRepository({
      checkoutPorPagamento: checkout(),
      credenciais: { accessToken: 'tok' },
    });
    const r = await processarAviso(
      deps(repo, new FakeMercadoPago()),
      aviso({
        body: { id: 5, type: 'payment' },
        query: { 'data.id': pagamentoId },
      }),
    );
    assert.equal(r.status, 200);
    assert.ok(repo.chamada('confirmarPedido'));
  });
});

describe('processarAviso — idempotência', () => {
  it('aviso repetido (mesmo id) não processa de novo', async () => {
    const repo = new FakeRepository({
      avisoNovo: false,
      checkoutPorPagamento: checkout(),
      credenciais: { accessToken: 'tok' },
    });
    const mp = new FakeMercadoPago();
    const r = await processarAviso(deps(repo, mp), aviso());

    assert.equal(r.status, 200);
    assert.deepEqual(repo.nomesChamados(), ['registrarAviso']);
    assert.deepEqual(mp.leituras, []);
  });

  it('pagamento aprovado duas vezes confirma só uma (checkout já pago)', async () => {
    const repo = new FakeRepository({
      checkoutPorPagamento: checkout('paid'),
      credenciais: { accessToken: 'tok' },
    });
    const r = await processarAviso(deps(repo, new FakeMercadoPago()), aviso());

    assert.equal(r.status, 200);
    assert.equal(r.detalhe, 'sem mudança de estado');
    assert.equal(repo.chamada('confirmarPedido'), undefined);
  });

  it('estorno depois de pago é aplicado (devolve o estoque)', async () => {
    const repo = new FakeRepository({
      checkoutPorPagamento: checkout('paid'),
      credenciais: { accessToken: 'tok' },
    });
    const mp = new FakeMercadoPago({
      ler: { id: pagamentoId, status: 'refunded', detalheDoStatus: 'refunded' },
    });
    const r = await processarAviso(deps(repo, mp), aviso());

    assert.equal(r.status, 200);
    assert.equal(repo.chamada('liberarReserva')!.status, 'refunded');
  });

  it('estorno avisado duas vezes devolve o estoque só uma', async () => {
    const repo = new FakeRepository({
      checkoutPorPagamento: checkout('refunded'),
      credenciais: { accessToken: 'tok' },
    });
    const mp = new FakeMercadoPago({
      ler: { id: pagamentoId, status: 'refunded', detalheDoStatus: 'refunded' },
    });
    const r = await processarAviso(deps(repo, mp), aviso());
    assert.equal(repo.chamada('liberarReserva'), undefined);
    assert.equal(r.detalhe, 'sem mudança de estado');
  });

  it('Pix recusado cancela o pedido', async () => {
    const repo = new FakeRepository({
      checkoutPorPagamento: checkout('pending'),
      credenciais: { accessToken: 'tok' },
    });
    const mp = new FakeMercadoPago({
      ler: { id: pagamentoId, status: 'cancelled', detalheDoStatus: 'expired' },
    });
    const r = await processarAviso(deps(repo, mp), aviso());

    assert.equal(r.status, 200);
    assert.equal(repo.chamada('liberarReserva')!.status, 'failed');
  });

  it('Pix ainda pendente não mexe no pedido', async () => {
    const repo = new FakeRepository({
      checkoutPorPagamento: checkout('pending'),
      credenciais: { accessToken: 'tok' },
    });
    const mp = new FakeMercadoPago({
      ler: { id: pagamentoId, status: 'pending', detalheDoStatus: 'waiting' },
    });
    const r = await processarAviso(deps(repo, mp), aviso());
    assert.equal(r.status, 200);
    assert.equal(repo.chamada('confirmarPedido'), undefined);
    assert.equal(repo.chamada('liberarReserva'), undefined);
  });
});

describe('processarAviso — casos de borda', () => {
  it('aviso de outro tipo (assinatura da mensalidade) é confirmado e ignorado', async () => {
    const repo = new FakeRepository({ checkoutPorPagamento: checkout() });
    const r = await processarAviso(
      deps(repo, new FakeMercadoPago()),
      aviso({
        body: {
          id: 1,
          type: 'subscription_preapproval',
          data: { id: pagamentoId },
        },
      }),
    );
    assert.equal(r.status, 200);
    assert.deepEqual(repo.nomesChamados(), []);
  });

  it('pagamento sem checkout nosso responde 200 (o MP para de reenviar)', async () => {
    const repo = new FakeRepository({ checkoutPorPagamento: null });
    const r = await processarAviso(deps(repo, new FakeMercadoPago()), aviso());
    assert.equal(r.status, 200);
    assert.equal(r.detalhe, 'checkout não encontrado');
  });

  it('loja sem token responde 500 para o MP reenviar depois', async () => {
    const repo = new FakeRepository({
      checkoutPorPagamento: checkout(),
      credenciais: null,
    });
    const r = await processarAviso(deps(repo, new FakeMercadoPago()), aviso());
    assert.equal(r.status, 500);
    assert.equal(repo.chamada('confirmarPedido'), undefined);
  });

  it('falha ao ler o pagamento no MP responde 500 e não mexe no pedido', async () => {
    const repo = new FakeRepository({
      checkoutPorPagamento: checkout(),
      credenciais: { accessToken: 'tok' },
    });
    const mp = new FakeMercadoPago({ ler: new Error('timeout') });
    const r = await processarAviso(deps(repo, mp), aviso());

    assert.equal(r.status, 500);
    assert.equal(repo.chamada('confirmarPedido'), undefined);
    assert.equal(repo.chamada('liberarReserva'), undefined);
  });

  it('status novo do MP não mexe no pedido', async () => {
    const repo = new FakeRepository({
      checkoutPorPagamento: checkout(),
      credenciais: { accessToken: 'tok' },
    });
    const mp = new FakeMercadoPago({
      ler: { id: pagamentoId, status: 'coisa_nova', detalheDoStatus: '' },
    });
    const r = await processarAviso(deps(repo, mp), aviso());
    assert.equal(r.status, 200);
    assert.equal(repo.chamada('confirmarPedido'), undefined);
    assert.equal(repo.chamada('liberarReserva'), undefined);
  });
});
