import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import {
  criarCheckout,
  DependenciasDoCheckout,
} from '../src/checkout/criar_checkout';
import { CheckoutDoc } from '../src/data/repository';
import { CheckoutError } from '../src/domain/errors';
import { parseCheckoutRequest } from '../src/domain/request';
import { PagamentoCartao, PagamentoPix } from '../src/mp/client';
import {
  FakeMercadoPago,
  FakeRepository,
  lojaDeTeste,
  pedidoDeTeste,
  semLog,
} from './fakes';

const agora = () => new Date('2026-10-30T06:00:00Z');

function deps(
  repo: FakeRepository,
  mp: FakeMercadoPago,
): DependenciasDoCheckout {
  return {
    repo,
    mp,
    urlDoAviso: 'https://exemplo/mpWebhook',
    agora,
    log: semLog(),
  };
}

async function codigoDoErro(fn: () => Promise<unknown>): Promise<string> {
  try {
    await fn();
  } catch (erro) {
    assert.ok(erro instanceof CheckoutError, `esperava CheckoutError, veio ${erro}`);
    return erro.code;
  }
  assert.fail('esperava um CheckoutError e nada foi lançado');
}

describe('criarCheckout — Pix', () => {
  it('reserva o pedido e devolve o QR do Pix', async () => {
    const repo = new FakeRepository({ dados: lojaDeTeste(), proximoOrderId: '7' });
    const mp = new FakeMercadoPago();
    const resposta = await criarCheckout(
      deps(repo, mp),
      parseCheckoutRequest(pedidoDeTeste()),
      'uid-cliente',
    );

    assert.equal(resposta.orderId, '7');
    assert.equal(resposta.status, 'pending');
    assert.equal(resposta.approved, false);
    assert.equal(resposta.total, 200);
    assert.equal(resposta.pixCopyPaste, '000201...PIX');
    assert.equal(resposta.pixQrBase64, 'QRBASE64');
    assert.deepEqual(repo.nomesChamados(), [
      'buscarCheckout',
      'carregar',
      'reservar',
      'registrarPagamento',
    ]);
  });

  it('cobra no Mercado Pago com o token da LOJA e a taxa da plataforma', async () => {
    const repo = new FakeRepository({ dados: lojaDeTeste() });
    const mp = new FakeMercadoPago();
    await criarCheckout(
      deps(repo, mp),
      parseCheckoutRequest(pedidoDeTeste()),
      'uid-cliente',
    );

    assert.equal(mp.tokensUsados[0], 'TEST-token-da-loja');
    const cobranca = mp.cobrancas[0] as PagamentoPix;
    assert.equal(cobranca.tipo, 'pix');
    assert.equal(cobranca.valor, 200);
    assert.equal(cobranca.taxaDaPlataforma, 0.99);
    assert.equal(cobranca.referenciaExterna, 'loja_ju:7:chave-de-teste-1');
    assert.equal(cobranca.urlDoAviso, 'https://exemplo/mpWebhook');
    assert.equal(cobranca.chaveDeIdempotencia, 'chave-de-teste-1');
    assert.equal(cobranca.pagador.email, 'cliente@exemplo.com');
    assert.equal(cobranca.pagador.cpf, '12345678909');
  });

  it('grava no pedido o preço do Firestore, não o que o app mandou', async () => {
    const repo = new FakeRepository({ dados: lojaDeTeste() });
    const mp = new FakeMercadoPago();
    await criarCheckout(
      deps(repo, mp),
      // O app "diz" que o total é R$ 1; o servidor cobra os R$ 200 do catálogo.
      parseCheckoutRequest(pedidoDeTeste({ total: 1, productsPrice: 1 })),
      'uid-cliente',
    );
    const reserva = repo.chamada('reservar')!;
    assert.equal(reserva.total, 200);
    assert.equal(reserva.productsPrice, 200);
    assert.equal(reserva.platformFee, 0.99);
    assert.equal((mp.cobrancas[0] as PagamentoPix).valor, 200);
  });

  it('soma o frete da zona quando a entrega é da loja', async () => {
    const repo = new FakeRepository({ dados: lojaDeTeste() });
    const mp = new FakeMercadoPago();
    const resposta = await criarCheckout(
      deps(repo, mp),
      parseCheckoutRequest(
        pedidoDeTeste({
          delivery: { method: 'entrega_propria', zoneId: 'z1', quotedFee: 0 },
        }),
      ),
      'uid-cliente',
    );
    assert.equal(resposta.total, 208);
    assert.equal(repo.chamada('reservar')!.deliveryPrice, 8);
  });
});

describe('criarCheckout — idempotência', () => {
  it('a mesma chave devolve o mesmo pedido, sem cobrar de novo', async () => {
    const existente: CheckoutDoc = {
      id: 'chave-de-teste-1',
      storeId: 'loja_ju',
      orderId: '7',
      userId: 'uid-cliente',
      status: 'pending',
      total: 200,
      platformFee: 0.99,
      paymentType: 'pix',
      mpPaymentId: 'mp-1',
      mpStatus: 'pending',
      pixCopyPaste: '000201...PIX',
      items: [{ pid: 'p1', size: 'M', quantity: 2, locationId: 'principal' }],
    };
    const repo = new FakeRepository({ checkoutExistente: existente });
    const mp = new FakeMercadoPago();

    const resposta = await criarCheckout(
      deps(repo, mp),
      parseCheckoutRequest(pedidoDeTeste()),
      'uid-cliente',
    );

    assert.equal(resposta.orderId, '7');
    assert.equal(resposta.pixCopyPaste, '000201...PIX');
    // Nem reserva de novo, nem cobra de novo.
    assert.deepEqual(repo.nomesChamados(), ['buscarCheckout']);
    assert.equal(mp.cobrancas.length, 0);
  });

  it('checkout já pago devolve aprovado', async () => {
    const repo = new FakeRepository({
      checkoutExistente: {
        id: 'chave-de-teste-1',
        storeId: 'loja_ju',
        orderId: '7',
        userId: 'uid-cliente',
        status: 'paid',
        total: 200,
        platformFee: 0.99,
        paymentType: 'card',
        items: [],
      },
    });
    const resposta = await criarCheckout(
      deps(repo, new FakeMercadoPago()),
      parseCheckoutRequest(pedidoDeTeste()),
      'uid-cliente',
    );
    assert.equal(resposta.approved, true);
    assert.equal(resposta.status, 'paid');
  });

  it('chave de outra pessoa não devolve o pedido dela', async () => {
    const repo = new FakeRepository({
      checkoutExistente: {
        id: 'chave-de-teste-1',
        storeId: 'loja_ju',
        orderId: '7',
        userId: 'outro-uid',
        status: 'pending',
        total: 200,
        platformFee: 0.99,
        paymentType: 'pix',
        items: [],
      },
    });
    const codigo = await codigoDoErro(() =>
      criarCheckout(
        deps(repo, new FakeMercadoPago()),
        parseCheckoutRequest(pedidoDeTeste()),
        'uid-cliente',
      ),
    );
    assert.equal(codigo, 'pedido-invalido');
  });
});

describe('criarCheckout — quando não pode vender', () => {
  it('loja suspensa não vende', async () => {
    const dados = lojaDeTeste();
    dados.store.subscription = {
      trialEndsAt: new Date('2026-01-01T00:00:00Z'),
      paidUntil: new Date('2026-05-01T00:00:00Z'),
    };
    const repo = new FakeRepository({ dados });
    const codigo = await codigoDoErro(() =>
      criarCheckout(
        deps(repo, new FakeMercadoPago()),
        parseCheckoutRequest(pedidoDeTeste()),
        'uid-cliente',
      ),
    );
    assert.equal(codigo, 'loja-indisponivel');
    assert.equal(repo.chamada('reservar'), undefined);
  });

  it('loja desativada pela plataforma não vende', async () => {
    const dados = lojaDeTeste();
    dados.store.active = false;
    const codigo = await codigoDoErro(() =>
      criarCheckout(
        deps(new FakeRepository({ dados }), new FakeMercadoPago()),
        parseCheckoutRequest(pedidoDeTeste()),
        'uid-cliente',
      ),
    );
    assert.equal(codigo, 'loja-indisponivel');
  });

  it('loja sem Mercado Pago conectado não vende (e não reserva estoque)', async () => {
    const dados = lojaDeTeste({ credenciais: null });
    const repo = new FakeRepository({ dados });
    const codigo = await codigoDoErro(() =>
      criarCheckout(
        deps(repo, new FakeMercadoPago()),
        parseCheckoutRequest(pedidoDeTeste()),
        'uid-cliente',
      ),
    );
    assert.equal(codigo, 'mp-nao-conectado');
    assert.equal(repo.chamada('reservar'), undefined);
  });

  it('item sem estoque não reserva nem cobra', async () => {
    const repo = new FakeRepository({ dados: lojaDeTeste() });
    const codigo = await codigoDoErro(() =>
      criarCheckout(
        deps(repo, new FakeMercadoPago()),
        parseCheckoutRequest(
          pedidoDeTeste({
            items: [{ pid: 'p1', size: 'G', quantity: 5, locationId: 'principal' }],
          }),
        ),
        'uid-cliente',
      ),
    );
    assert.equal(codigo, 'estoque-insuficiente');
    assert.equal(repo.chamada('reservar'), undefined);
  });

  it('recusa pedido cujo total não cobre a taxa da plataforma', async () => {
    const dados = lojaDeTeste();
    dados.store.serviceFee = { amount: 100, paidBy: 'store' };
    dados.products.set('p1', {
      name: 'Chaveiro',
      sizes: [{ name: 'U', price: 2, stockByLocation: { principal: 9 } }],
    });
    const codigo = await codigoDoErro(() =>
      criarCheckout(
        deps(new FakeRepository({ dados }), new FakeMercadoPago()),
        parseCheckoutRequest(
          pedidoDeTeste({
            items: [{ pid: 'p1', size: 'U', quantity: 1, locationId: 'principal' }],
          }),
        ),
        'uid-cliente',
      ),
    );
    assert.equal(codigo, 'pedido-invalido');
  });
});

describe('criarCheckout — falha e recusa devolvem o estoque', () => {
  it('se a cobrança no MP falhar, a reserva é liberada', async () => {
    const repo = new FakeRepository({ dados: lojaDeTeste() });
    const mp = new FakeMercadoPago({ criar: new Error('MP fora do ar') });

    const codigo = await codigoDoErro(() =>
      criarCheckout(
        deps(repo, mp),
        parseCheckoutRequest(pedidoDeTeste()),
        'uid-cliente',
      ),
    );

    assert.equal(codigo, 'provedor-indisponivel');
    const liberacao = repo.chamada('liberarReserva')!;
    assert.equal(liberacao.status, 'failed');
    assert.equal(liberacao.mpStatus, 'erro-na-cobranca');
    assert.equal(repo.chamada('registrarPagamento'), undefined);
  });

  it('cartão recusado cancela o pedido e devolve o estoque', async () => {
    const repo = new FakeRepository({ dados: lojaDeTeste() });
    const mp = new FakeMercadoPago({
      criar: {
        id: 'mp-9',
        status: 'rejected',
        detalheDoStatus: 'cc_rejected_insufficient_amount',
      },
    });

    const resposta = await criarCheckout(
      deps(repo, mp),
      parseCheckoutRequest(
        pedidoDeTeste({ paymentType: 'card', cardToken: 'tok_1', installments: 2 }),
      ),
      'uid-cliente',
    );

    assert.equal(resposta.status, 'failed');
    assert.equal(resposta.approved, false);
    assert.equal(resposta.message, 'Cartão sem limite suficiente.');
    assert.equal(repo.chamada('liberarReserva')!.status, 'failed');
    // O id do pagamento recusado fica registrado para o lojista entender.
    assert.equal(repo.chamada('registrarPagamento')!.mpPaymentId, 'mp-9');
  });

  it('cartão aprovado na hora confirma o pedido sem esperar o webhook', async () => {
    const repo = new FakeRepository({ dados: lojaDeTeste() });
    const mp = new FakeMercadoPago({
      criar: { id: 'mp-2', status: 'approved', detalheDoStatus: 'accredited' },
    });

    const resposta = await criarCheckout(
      deps(repo, mp),
      parseCheckoutRequest(
        pedidoDeTeste({ paymentType: 'card', cardToken: 'tok_1', installments: 3 }),
      ),
      'uid-cliente',
    );

    assert.equal(resposta.approved, true);
    assert.equal(resposta.status, 'paid');
    const cobranca = mp.cobrancas[0] as PagamentoCartao;
    assert.equal(cobranca.tipo, 'cartao');
    assert.equal(cobranca.tokenDoCartao, 'tok_1');
    assert.equal(cobranca.parcelas, 3);
    assert.equal(repo.chamada('confirmarPedido')!.mpPaymentId, 'mp-2');
    assert.equal(repo.chamada('liberarReserva'), undefined);
  });

  it('cartão em análise não confirma nem cancela', async () => {
    const repo = new FakeRepository({ dados: lojaDeTeste() });
    const mp = new FakeMercadoPago({
      criar: { id: 'mp-3', status: 'in_process', detalheDoStatus: 'pending_review' },
    });
    const resposta = await criarCheckout(
      deps(repo, mp),
      parseCheckoutRequest(pedidoDeTeste({ paymentType: 'card', cardToken: 'tok_1' })),
      'uid-cliente',
    );
    assert.equal(resposta.status, 'pending');
    assert.equal(repo.chamada('confirmarPedido'), undefined);
    assert.equal(repo.chamada('liberarReserva'), undefined);
  });
});
