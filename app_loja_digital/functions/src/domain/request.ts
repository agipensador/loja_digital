import { kDefaultLocationId } from './documents';
import { erroDeNegocio } from './errors';
import { ItemRequest, DeliveryRequest } from './pricing';
import { toDate } from './store_status';

/**
 * Tudo que chega do app é desconhecido até passar por aqui. Nada de
 * `as Tipo` em cima do corpo da requisição: sem esta camada um campo a mais
 * no JSON viraria campo a mais no Firestore.
 */

export type PaymentType = 'pix' | 'card';

export interface CheckoutRequest {
  storeId: string;
  /** Id do checkout = chave de idempotência escolhida pelo app. */
  idempotencyKey: string;
  items: ItemRequest[];
  delivery: DeliveryRequest;
  address: Record<string, string>;
  paymentType: PaymentType;
  payerEmail: string;
  payerCpf: string;
  payerName: string;
  /** Token do cartão, gerado no aparelho pelo SDK do MP (cartão só). */
  cardToken: string;
  installments: number;
  /** Rótulo que o app já grava em `Order.payment` (ex.: "Pix"). */
  paymentLabel: string;
}

const kMaxItems = 60;
const kMaxQuantity = 99;
/** Campos do endereço que o pedido guarda (`Address.toMap` no app). */
const kAddressFields = [
  'street',
  'number',
  'complement',
  'district',
  'city',
  'state',
  'zipCode',
  'lat',
  'long',
] as const;

function texto(value: unknown, limite = 120): string {
  if (typeof value !== 'string') return '';
  return value.trim().slice(0, limite);
}

function idSeguro(value: unknown): string {
  // Ids do Firestore não podem ter '/'; o resto restringimos por segurança.
  const bruto = texto(value, 160);
  return /^[A-Za-z0-9_.:-]+$/.test(bruto) ? bruto : '';
}

function parseItem(raw: unknown): ItemRequest {
  if (!raw || typeof raw !== 'object') {
    throw erroDeNegocio('pedido-invalido', 'Item do carrinho inválido.');
  }
  const item = raw as Record<string, unknown>;
  const pid = idSeguro(item.pid);
  const quantidade = Number(item.quantity);
  if (!pid) {
    throw erroDeNegocio('pedido-invalido', 'Item do carrinho sem produto.');
  }
  if (
    !Number.isInteger(quantidade) ||
    quantidade <= 0 ||
    quantidade > kMaxQuantity
  ) {
    throw erroDeNegocio('pedido-invalido', 'Quantidade inválida no carrinho.');
  }
  return {
    pid,
    size: texto(item.size, 60),
    quantity: quantidade,
    locationId: idSeguro(item.locationId) || kDefaultLocationId,
  };
}

function parseDelivery(raw: unknown): DeliveryRequest {
  const delivery = (raw ?? {}) as Record<string, unknown>;
  const quoted = Number(delivery.quotedFee);
  return {
    method: texto(delivery.method, 40),
    zoneId: idSeguro(delivery.zoneId) || undefined,
    quotedFee: Number.isFinite(quoted) && quoted >= 0 ? quoted : undefined,
    preferredDate: toDate(delivery.preferredDate),
  };
}

function parseAddress(raw: unknown): Record<string, string> {
  const bruto = (raw ?? {}) as Record<string, unknown>;
  const address: Record<string, string> = {};
  for (const field of kAddressFields) {
    const valor = bruto[field];
    if (typeof valor === 'string' && valor.trim() !== '') {
      address[field] = texto(valor, 200);
    } else if (typeof valor === 'number' && Number.isFinite(valor)) {
      address[field] = String(valor);
    }
  }
  return address;
}

/** Só dígitos — o MP recusa CPF com pontuação. */
export function somenteDigitos(value: unknown): string {
  return typeof value === 'string' ? value.replace(/\D/g, '') : '';
}

export function parseCheckoutRequest(raw: unknown): CheckoutRequest {
  if (!raw || typeof raw !== 'object') {
    throw erroDeNegocio('pedido-invalido', 'Pedido inválido.');
  }
  const data = raw as Record<string, unknown>;

  const storeId = idSeguro(data.storeId);
  if (!storeId) {
    throw erroDeNegocio('pedido-invalido', 'Loja não informada.');
  }

  const idempotencyKey = idSeguro(data.idempotencyKey);
  if (idempotencyKey.length < 8) {
    throw erroDeNegocio(
      'pedido-invalido',
      'Pedido sem chave de identificação.',
    );
  }

  const itensBrutos = Array.isArray(data.items) ? data.items : [];
  if (itensBrutos.length === 0) {
    throw erroDeNegocio('carrinho-vazio', 'Seu carrinho está vazio.');
  }
  if (itensBrutos.length > kMaxItems) {
    throw erroDeNegocio(
      'pedido-invalido',
      'Carrinho com itens demais para um único pedido.',
    );
  }
  const items = itensBrutos.map(parseItem);

  const paymentType: PaymentType = data.paymentType === 'card' ? 'card' : 'pix';
  const cardToken = idSeguro(data.cardToken);
  if (paymentType === 'card' && !cardToken) {
    throw erroDeNegocio(
      'pedido-invalido',
      'Cartão não validado. Tente escolher a forma de pagamento de novo.',
    );
  }

  const parcelas = Number(data.installments);
  const email = texto(data.payerEmail, 200).toLowerCase();
  if (!email.includes('@')) {
    throw erroDeNegocio('pedido-invalido', 'E-mail do pagador inválido.');
  }

  return {
    storeId,
    idempotencyKey,
    items,
    delivery: parseDelivery(data.delivery),
    address: parseAddress(data.address),
    paymentType,
    payerEmail: email,
    payerCpf: somenteDigitos(data.payerCpf).slice(0, 11),
    payerName: texto(data.payerName, 120),
    cardToken,
    installments:
      Number.isInteger(parcelas) && parcelas >= 1 && parcelas <= 12
        ? parcelas
        : 1,
    paymentLabel: texto(data.paymentLabel, 60),
  };
}

/**
 * O pedido é de UMA unidade (`locationId` do pedido = do 1º item, como o app
 * faz em `Order.fromCartManager`). Misturar unidades num pedido só confunde
 * estoque e entrega, então é recusado.
 */
export function locationIdDoPedido(items: ItemRequest[]): string {
  const primeiro = items[0]?.locationId ?? kDefaultLocationId;
  for (const item of items) {
    if (item.locationId !== primeiro) {
      throw erroDeNegocio(
        'pedido-invalido',
        'Itens de unidades diferentes precisam de pedidos separados.',
      );
    }
  }
  return primeiro;
}
