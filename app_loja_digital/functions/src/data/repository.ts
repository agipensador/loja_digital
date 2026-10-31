import {
  LocationDoc,
  MpCredentialsDoc,
  ProductDoc,
  SizeDoc,
  StoreDoc,
  ZoneDoc,
} from '../domain/documents';
import { CheckoutStatus } from '../domain/payment_status';
import { ItemRequest, OrderLine } from '../domain/pricing';

/**
 * Contrato de persistência do checkout. Existe para o handler ser testável
 * sem Firestore (e para trocar de banco um dia sem tocar na regra — ver
 * REGRAS dos agentes, "troca de backend sempre atrás de uma interface").
 */

export interface DadosDoCheckout {
  store: StoreDoc;
  /** Token da conta MP da loja; null quando ela não conectou ainda. */
  credenciais: MpCredentialsDoc | null;
  location: LocationDoc;
  zone: ZoneDoc | null;
  products: Map<string, ProductDoc>;
}

export interface CheckoutDoc {
  id: string;
  storeId: string;
  orderId: string;
  userId: string;
  status: CheckoutStatus;
  total: number;
  platformFee: number;
  paymentType: string;
  mpPaymentId?: string;
  mpStatus?: string;
  pixCopyPaste?: string;
  pixQrBase64?: string;
  pixExpiresAt?: string;
  items: Pick<ItemRequest, 'pid' | 'size' | 'quantity' | 'locationId'>[];
}

export interface ReservaPedido {
  storeId: string;
  checkoutId: string;
  userId: string;
  lines: OrderLine[];
  items: ItemRequest[];
  productsPrice: number;
  deliveryPrice: number;
  serviceFee: number;
  platformFee: number;
  total: number;
  locationId: string;
  address: Record<string, string>;
  paymentLabel: string;
  paymentType: string;
  shipping: {
    method: string;
    zoneId: string;
    preferredDate: Date | null;
  };
}

export interface ResultadoDaReserva {
  orderId: string;
}

export interface AtualizacaoDePagamento {
  mpPaymentId: string;
  mpStatus: string;
  checkoutStatus: CheckoutStatus;
  pixCopyPaste?: string;
  pixQrBase64?: string;
  pixExpiresAt?: string;
}

export interface CheckoutRepository {
  /** Lê tudo que o cálculo precisa, numa só ida ao banco por documento. */
  carregar(args: {
    storeId: string;
    locationId: string;
    zoneId?: string;
    pids: string[];
  }): Promise<DadosDoCheckout>;

  /** Checkout já criado com esta chave de idempotência (ou null). */
  buscarCheckout(storeId: string, checkoutId: string): Promise<CheckoutDoc | null>;

  /**
   * Transação: baixa o estoque, pega o número do pedido no contador e cria
   * o pedido como "aguardando pagamento" junto do checkout.
   */
  reservar(reserva: ReservaPedido): Promise<ResultadoDaReserva>;

  /** Guarda no checkout o que o MP respondeu (id do pagamento, QR do Pix). */
  registrarPagamento(
    storeId: string,
    checkoutId: string,
    dados: AtualizacaoDePagamento,
  ): Promise<void>;

  /**
   * Desfaz a reserva: devolve o estoque, cancela o pedido e marca o checkout.
   * Usado quando o MP recusa, o Pix vence ou a chamada ao MP falha.
   */
  liberarReserva(args: {
    storeId: string;
    checkoutId: string;
    status: CheckoutStatus;
    mpStatus?: string;
  }): Promise<void>;

  /** Confirma o pedido pago (aguardando pagamento → em separação). */
  confirmarPedido(args: {
    storeId: string;
    checkoutId: string;
    mpPaymentId: string;
    mpStatus: string;
  }): Promise<void>;

  /** Acha o checkout pelo id do pagamento no MP (o webhook só tem isso). */
  checkoutPorPagamento(mpPaymentId: string): Promise<CheckoutDoc | null>;

  /** Access token da conta MP da loja. */
  credenciaisDaLoja(storeId: string): Promise<MpCredentialsDoc | null>;

  /**
   * Marca o aviso como processado. Devolve false se JÁ estava — é o que faz
   * o webhook ser idempotente contra o reenvio do Mercado Pago.
   */
  registrarAviso(avisoId: string): Promise<boolean>;
}

/** Resultado puro do planejamento da transação de reserva. */
export interface PlanoDaReserva {
  proximoNumero: number;
  /** pid → novo array de `sizes` com o estoque já baixado. */
  novosSizes: Map<string, SizeDoc[]>;
}
