import {
  AtualizacaoDePagamento,
  CheckoutDoc,
  CheckoutRepository,
  DadosDoCheckout,
  ReservaPedido,
  ResultadoDaReserva,
} from '../src/data/repository';
import { MpCredentialsDoc } from '../src/domain/documents';
import { CheckoutStatus } from '../src/domain/payment_status';
import {
  MercadoPagoApi,
  PagamentoCartao,
  PagamentoPix,
  RespostaDePagamento,
} from '../src/mp/client';

/**
 * Duplos de teste. O Mercado Pago e o Firestore nunca são tocados — o aceite
 * da tarefa L2 pede exatamente isso ("testes com o SDK mockado").
 */

export class FakeMercadoPago implements MercadoPagoApi {
  constructor(
    private readonly respostas: {
      criar?: RespostaDePagamento | Error;
      ler?: RespostaDePagamento | Error;
    } = {},
  ) {}

  readonly cobrancas: (PagamentoPix | PagamentoCartao)[] = [];
  readonly tokensUsados: string[] = [];
  readonly leituras: string[] = [];

  async criarPagamento(
    pedido: PagamentoPix | PagamentoCartao,
    accessToken: string,
  ): Promise<RespostaDePagamento> {
    this.cobrancas.push(pedido);
    this.tokensUsados.push(accessToken);
    const resposta = this.respostas.criar;
    if (resposta instanceof Error) throw resposta;
    return (
      resposta ?? {
        id: 'mp-1',
        status: 'pending',
        detalheDoStatus: 'pending_waiting_transfer',
        pixCopiaECola: '000201...PIX',
        pixQrBase64: 'QRBASE64',
        expiraEm: '2026-10-30T12:00:00.000-03:00',
      }
    );
  }

  async lerPagamento(
    pagamentoId: string,
    accessToken: string,
  ): Promise<RespostaDePagamento> {
    this.leituras.push(pagamentoId);
    this.tokensUsados.push(accessToken);
    const resposta = this.respostas.ler;
    if (resposta instanceof Error) throw resposta;
    return (
      resposta ?? { id: pagamentoId, status: 'approved', detalheDoStatus: 'accredited' }
    );
  }
}

export interface ChamadaRegistrada {
  nome: string;
  args: Record<string, unknown>;
}

export class FakeRepository implements CheckoutRepository {
  constructor(
    private readonly estado: {
      dados?: DadosDoCheckout;
      checkoutExistente?: CheckoutDoc | null;
      checkoutPorPagamento?: CheckoutDoc | null;
      credenciais?: MpCredentialsDoc | null;
      avisoNovo?: boolean;
      proximoOrderId?: string;
      erroAoCarregar?: Error;
    } = {},
  ) {}

  readonly chamadas: ChamadaRegistrada[] = [];

  nomesChamados(): string[] {
    return this.chamadas.map((c) => c.nome);
  }

  chamada(nome: string): Record<string, unknown> | undefined {
    return this.chamadas.find((c) => c.nome === nome)?.args;
  }

  async carregar(args: {
    storeId: string;
    locationId: string;
    zoneId?: string;
    pids: string[];
  }): Promise<DadosDoCheckout> {
    this.chamadas.push({ nome: 'carregar', args });
    if (this.estado.erroAoCarregar) throw this.estado.erroAoCarregar;
    return (
      this.estado.dados ?? {
        store: {},
        credenciais: null,
        location: {},
        zone: null,
        products: new Map(),
      }
    );
  }

  async buscarCheckout(
    storeId: string,
    checkoutId: string,
  ): Promise<CheckoutDoc | null> {
    this.chamadas.push({ nome: 'buscarCheckout', args: { storeId, checkoutId } });
    return this.estado.checkoutExistente ?? null;
  }

  async reservar(reserva: ReservaPedido): Promise<ResultadoDaReserva> {
    this.chamadas.push({
      nome: 'reservar',
      args: reserva as unknown as Record<string, unknown>,
    });
    return { orderId: this.estado.proximoOrderId ?? '7' };
  }

  async registrarPagamento(
    storeId: string,
    checkoutId: string,
    dados: AtualizacaoDePagamento,
  ): Promise<void> {
    this.chamadas.push({
      nome: 'registrarPagamento',
      args: { storeId, checkoutId, ...dados },
    });
  }

  async liberarReserva(args: {
    storeId: string;
    checkoutId: string;
    status: CheckoutStatus;
    mpStatus?: string;
  }): Promise<void> {
    this.chamadas.push({ nome: 'liberarReserva', args });
  }

  async confirmarPedido(args: {
    storeId: string;
    checkoutId: string;
    mpPaymentId: string;
    mpStatus: string;
  }): Promise<void> {
    this.chamadas.push({ nome: 'confirmarPedido', args });
  }

  async checkoutPorPagamento(mpPaymentId: string): Promise<CheckoutDoc | null> {
    this.chamadas.push({ nome: 'checkoutPorPagamento', args: { mpPaymentId } });
    return this.estado.checkoutPorPagamento ?? null;
  }

  async credenciaisDaLoja(storeId: string): Promise<MpCredentialsDoc | null> {
    this.chamadas.push({ nome: 'credenciaisDaLoja', args: { storeId } });
    return this.estado.credenciais ?? null;
  }

  async registrarAviso(avisoId: string): Promise<boolean> {
    this.chamadas.push({ nome: 'registrarAviso', args: { avisoId } });
    return this.estado.avisoNovo ?? true;
  }
}

/** Loja saudável: trial em curso, MP conectado, taxa padrão de R$ 0,99. */
export function lojaDeTeste(
  ajustes: Partial<DadosDoCheckout> = {},
): DadosDoCheckout {
  return {
    store: {
      name: 'Loja da Ju',
      active: true,
      mpConnected: true,
      serviceFee: { amount: 0.99, paidBy: 'store' },
      subscription: {
        trialEndsAt: new Date('2026-12-31T00:00:00Z'),
      },
    },
    credenciais: { accessToken: 'TEST-token-da-loja', mpUserId: 123 },
    location: {
      offersPickup: true,
      offersShipping: true,
      offersOwnDelivery: true,
      offersUber: true,
      shippingFee: 25,
      uberFee: 12,
    },
    zone: { name: 'Centro', locationId: 'principal', fee: 8, weekdays: [1, 3] },
    products: new Map([
      [
        'p1',
        {
          name: 'Camiseta',
          thumbs: ['thumb.jpg'],
          images: ['foto.jpg'],
          sizes: [
            { name: 'M', price: 100, stockByLocation: { principal: 5 } },
            { name: 'G', price: 120, stockByLocation: { principal: 1 } },
          ],
        },
      ],
    ]),
    ...ajustes,
  };
}

export function pedidoDeTeste(ajustes: Record<string, unknown> = {}) {
  return {
    storeId: 'loja_ju',
    idempotencyKey: 'chave-de-teste-1',
    items: [{ pid: 'p1', size: 'M', quantity: 2, locationId: 'principal' }],
    delivery: { method: 'retirada' },
    address: { zipCode: '01001000', street: 'Praça da Sé', number: '1' },
    paymentType: 'pix',
    payerEmail: 'cliente@exemplo.com',
    payerCpf: '12345678909',
    payerName: 'Cliente',
    cardToken: '',
    installments: 1,
    paymentLabel: 'Pix',
    ...ajustes,
  };
}

export function semLog(): (m: string, d?: Record<string, unknown>) => void {
  return () => {};
}
