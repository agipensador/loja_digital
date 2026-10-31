import {
  kDefaultLocationId,
  LocationDoc,
  ProductDoc,
  SizeDoc,
  StoreDoc,
  ZoneDoc,
  kDefaultServiceFee,
  sizeStockAt,
  withStockAt,
} from './documents';
import { erroDeNegocio } from './errors';
import { roundMoney } from './money';

/**
 * O CORAÇÃO DA TAREFA L2: aqui o servidor recalcula o pedido inteiro a partir
 * do Firestore. Do cliente só vêm *quais* itens e *como* ele quer receber —
 * nunca quanto custa. Enquanto o checkout era feito no app (ver
 * `CartManager.checkout`), um cliente com o app modificado podia mandar o
 * preço que quisesse; é a brecha que estas funções fecham.
 */

/** O que o app manda: identidade do item e quantidade. Sem preço. */
export interface ItemRequest {
  pid: string;
  size: string;
  quantity: number;
  locationId: string;
}

/** Linha do pedido já com o preço do Firestore. */
export interface OrderLine {
  pid: string;
  size: string;
  quantity: number;
  locationId: string;
  name: string;
  /** Preço unitário lido do Firestore. */
  price: number;
  image: string;
}

export interface DeliveryRequest {
  method: string;
  zoneId?: string;
  /** Cotação do app (só o motoboy usa — ver [deliveryFeeFor]). */
  quotedFee?: number;
  preferredDate?: Date | null;
}

export const DeliveryMethods = {
  ownDelivery: 'entrega_propria',
  pickup: 'retirada',
  uber: 'uber',
  correios: 'correios',
} as const;

export interface PricedOrder {
  lines: OrderLine[];
  productsPrice: number;
  deliveryPrice: number;
  /** Parte da taxa que o CLIENTE paga (0 quando a loja absorve). */
  serviceFee: number;
  /** Taxa total da plataforma, retida no split do Mercado Pago. */
  platformFee: number;
  /** Total cobrado do cliente. */
  total: number;
  locationId: string;
}

/** Produto + tamanho pedidos, agrupados por produto (um doc, vários tamanhos). */
export function groupByProduct(
  items: ItemRequest[],
): Map<string, ItemRequest[]> {
  const grouped = new Map<string, ItemRequest[]>();
  for (const item of items) {
    const list = grouped.get(item.pid);
    if (list) list.push(item);
    else grouped.set(item.pid, [item]);
  }
  return grouped;
}

function findSize(product: ProductDoc, name: string): SizeDoc | undefined {
  return (product.sizes ?? []).find((s) => s.name === name);
}

/**
 * Valida os itens contra o catálogo e devolve as linhas com o preço do banco.
 * Lança [CheckoutError] no primeiro problema — a mensagem é a que o cliente vê.
 */
export function priceItems(
  items: ItemRequest[],
  products: Map<string, ProductDoc>,
): { lines: OrderLine[]; productsPrice: number } {
  if (items.length === 0) {
    throw erroDeNegocio('carrinho-vazio', 'Seu carrinho está vazio.');
  }
  const lines: OrderLine[] = [];
  let productsPrice = 0;

  for (const item of items) {
    const product = products.get(item.pid);
    if (!product || product.deleted === true) {
      throw erroDeNegocio('produto-indisponivel', 'Produto indisponível.');
    }
    const nome = product.name ?? '';
    const size = findSize(product, item.size);
    if (!size) {
      throw erroDeNegocio(
        'tamanho-indisponivel',
        `Tamanho "${item.size}" indisponível para ${nome}`,
      );
    }
    const estoque = sizeStockAt(size, item.locationId);
    if (estoque < item.quantity) {
      throw erroDeNegocio(
        'estoque-insuficiente',
        `Estoque insuficiente para ${nome} (${item.size})`,
      );
    }
    const price = typeof size.price === 'number' ? size.price : 0;
    if (price <= 0) {
      throw erroDeNegocio(
        'produto-indisponivel',
        `${nome} está sem preço cadastrado.`,
      );
    }
    lines.push({
      pid: item.pid,
      size: item.size,
      quantity: item.quantity,
      locationId: item.locationId,
      name: nome,
      price,
      image: (product.thumbs ?? [])[0] ?? (product.images ?? [])[0] ?? '',
    });
    productsPrice += price * item.quantity;
  }

  return { lines, productsPrice: roundMoney(productsPrice) };
}

/**
 * Frete: SEMPRE o que a loja cadastrou, com uma exceção justificada.
 *
 * - `retirada`        → 0
 * - `entrega_propria` → `fee` da zona (e a zona tem de ser da unidade)
 * - `correios`        → `shippingFee` da unidade (a cotação real do Melhor
 *                        Envio é outra tarefa: `quoteShipping`)
 * - `uber`            → estimativa por distância, calculada no app
 *                        (`ShippingQuoteService.estimateUber`). Esta é a única
 *                        que o servidor não sabe refazer, então aceita a
 *                        cotação do app **com piso** no `uberFee` da unidade
 *                        (o valor de reserva). Assim o cliente nunca paga
 *                        menos do que a loja configurou; pagar mais, só quando
 *                        a distância pede.
 */
export function deliveryFeeFor(
  delivery: DeliveryRequest,
  location: LocationDoc,
  zone: ZoneDoc | null,
  locationId: string,
): number {
  switch (delivery.method) {
    case DeliveryMethods.pickup:
      if (location.offersPickup === false) {
        throw erroDeNegocio(
          'entrega-invalida',
          'Esta loja não oferece retirada.',
        );
      }
      return 0;

    case DeliveryMethods.ownDelivery: {
      if (!location.offersOwnDelivery) {
        throw erroDeNegocio(
          'entrega-invalida',
          'Esta loja não faz entrega própria.',
        );
      }
      if (!zone) {
        throw erroDeNegocio(
          'entrega-invalida',
          'Área de entrega não encontrada para este endereço.',
        );
      }
      if ((zone.locationId ?? kDefaultLocationId) !== locationId) {
        throw erroDeNegocio(
          'entrega-invalida',
          'Esta área de entrega é de outra unidade.',
        );
      }
      return roundMoney(typeof zone.fee === 'number' ? zone.fee : 0);
    }

    case DeliveryMethods.correios: {
      if (location.offersShipping === false) {
        throw erroDeNegocio('entrega-invalida', 'Esta loja não envia pelos Correios.');
      }
      return roundMoney(
        typeof location.shippingFee === 'number' ? location.shippingFee : 0,
      );
    }

    case DeliveryMethods.uber: {
      if (!location.offersUber) {
        throw erroDeNegocio('entrega-invalida', 'Esta loja não oferece motoboy.');
      }
      const piso =
        typeof location.uberFee === 'number' ? location.uberFee : 0;
      const cotado = delivery.quotedFee;
      const fee =
        typeof cotado === 'number' && Number.isFinite(cotado) && cotado > piso
          ? cotado
          : piso;
      return roundMoney(fee);
    }

    default:
      throw erroDeNegocio(
        'entrega-invalida',
        'Escolha como quer receber o pedido.',
      );
  }
}

/**
 * Taxa da plataforma: valor sempre o da loja (`serviceFee.amount`); quem paga
 * define se entra no total do cliente. Igual a `ServiceFeeConfig` no app.
 */
export function platformFeeFor(store: StoreDoc): {
  platformFee: number;
  serviceFee: number;
} {
  const config = store.serviceFee ?? {};
  const amount =
    typeof config.amount === 'number' && config.amount >= 0
      ? config.amount
      : kDefaultServiceFee;
  const platformFee = roundMoney(amount);
  const serviceFee = config.paidBy === 'customer' ? platformFee : 0;
  return { platformFee, serviceFee };
}

/** Monta o pedido inteiro com os valores do Firestore. */
export function priceOrder(args: {
  items: ItemRequest[];
  products: Map<string, ProductDoc>;
  store: StoreDoc;
  location: LocationDoc;
  zone: ZoneDoc | null;
  delivery: DeliveryRequest;
  locationId: string;
}): PricedOrder {
  const { lines, productsPrice } = priceItems(args.items, args.products);
  const deliveryPrice = deliveryFeeFor(
    args.delivery,
    args.location,
    args.zone,
    args.locationId,
  );
  const { platformFee, serviceFee } = platformFeeFor(args.store);
  return {
    lines,
    productsPrice,
    deliveryPrice,
    serviceFee,
    platformFee,
    total: roundMoney(productsPrice + deliveryPrice + serviceFee),
    locationId: args.locationId,
  };
}

/**
 * Novo array de `sizes` de um produto com o estoque dos itens baixado.
 * Revalida o estoque (a transação lê de novo antes de escrever, então é aqui
 * que uma compra simultânea é pega).
 */
export function decrementStock(
  product: ProductDoc,
  items: ItemRequest[],
): SizeDoc[] {
  const sizes = [...(product.sizes ?? [])];
  for (const item of items) {
    const index = sizes.findIndex((s) => s.name === item.size);
    if (index < 0) {
      throw erroDeNegocio(
        'tamanho-indisponivel',
        `Tamanho "${item.size}" indisponível para ${product.name ?? ''}`,
      );
    }
    const estoque = sizeStockAt(sizes[index], item.locationId);
    if (estoque < item.quantity) {
      throw erroDeNegocio(
        'estoque-insuficiente',
        `Estoque insuficiente para ${product.name ?? ''} (${item.size})`,
      );
    }
    sizes[index] = withStockAt(
      sizes[index],
      item.locationId,
      estoque - item.quantity,
    );
  }
  return sizes;
}

/**
 * Devolve o estoque (Pix não pago, pagamento recusado, estorno). Nunca lança:
 * devolver estoque não pode falhar por causa de um tamanho que o lojista
 * renomeou depois da compra — o que não encontrar, ignora e segue.
 */
export function restoreStock(
  product: ProductDoc,
  items: Pick<ItemRequest, 'size' | 'quantity' | 'locationId'>[],
): SizeDoc[] {
  const sizes = [...(product.sizes ?? [])];
  for (const item of items) {
    const index = sizes.findIndex((s) => s.name === item.size);
    if (index < 0) continue;
    const estoque = sizeStockAt(sizes[index], item.locationId);
    sizes[index] = withStockAt(
      sizes[index],
      item.locationId,
      estoque + item.quantity,
    );
  }
  return sizes;
}
