/**
 * Forma dos documentos do Firestore que o checkout lê.
 *
 * Espelha os modelos do app — manter em sintonia com:
 *   `lib/models/item_size.dart`      → [SizeDoc]
 *   `lib/models/product.dart`        → [ProductDoc]
 *   `lib/models/store.dart`          → [LocationDoc] (unidade física)
 *   `lib/models/store_account.dart`  → [StoreDoc]   (o tenant)
 *   `lib/models/delivery_zone.dart`  → [ZoneDoc]
 *
 * Tudo opcional: o backend nunca pode assumir que um campo existe, porque
 * documento antigo (anterior ao multi-unidade) não tem os campos novos.
 */

export const kDefaultLocationId = 'principal';

export interface SizeDoc {
  name?: string;
  price?: number;
  stockByLocation?: Record<string, number>;
  /** Formato antigo (estoque único, pré multi-unidade). */
  stock?: number;
}

export interface ProductDoc {
  name?: string;
  images?: string[];
  thumbs?: string[];
  deleted?: boolean;
  sizes?: SizeDoc[];
}

export interface LocationDoc {
  name?: string;
  address?: string;
  offersPickup?: boolean;
  offersShipping?: boolean;
  offersOwnDelivery?: boolean;
  offersUber?: boolean;
  shippingFee?: number;
  uberFee?: number;
}

export interface ZoneDoc {
  name?: string;
  locationId?: string;
  fee?: number;
  weekdays?: number[];
}

export interface ServiceFeeDoc {
  amount?: number;
  /** 'store' (padrão, a loja absorve) ou 'customer'. */
  paidBy?: string;
}

export interface SubscriptionDoc {
  trialEndsAt?: unknown;
  paidUntil?: unknown;
}

export interface StoreDoc {
  name?: string;
  active?: boolean;
  mpConnected?: boolean;
  serviceFee?: ServiceFeeDoc;
  subscription?: SubscriptionDoc;
}

/** stores/{storeId}/private/mp — gravado só pelo backend (OAuth). */
export interface MpCredentialsDoc {
  accessToken?: string;
  /** `user_id` da conta Mercado Pago da loja (o vendedor do split). */
  mpUserId?: string | number;
  expiresAt?: unknown;
}

/** Valor padrão da taxa da plataforma — `PlatformBilling.serviceFee` no app. */
export const kDefaultServiceFee = 0.99;

/** Dias de carência antes de suspender — `PlatformBilling.graceDays`. */
export const kGraceDays = 5;

export function sizeStockAt(size: SizeDoc, locationId: string): number {
  const byLocation = size.stockByLocation;
  if (byLocation && typeof byLocation === 'object') {
    const value = byLocation[locationId];
    return typeof value === 'number' ? Math.trunc(value) : 0;
  }
  // Documento no formato antigo: o estoque único é o da unidade padrão.
  if (locationId === kDefaultLocationId && typeof size.stock === 'number') {
    return Math.trunc(size.stock);
  }
  return 0;
}

/**
 * Grava o estoque de uma unidade preservando o formato do documento: se ele
 * ainda é do formato antigo (`stock`), migra para `stockByLocation`, que é o
 * que o app escreve hoje (`ItemSize.toMap`).
 */
export function withStockAt(
  size: SizeDoc,
  locationId: string,
  value: number,
): SizeDoc {
  const stock = value < 0 ? 0 : Math.trunc(value);
  const byLocation: Record<string, number> = {};
  if (size.stockByLocation && typeof size.stockByLocation === 'object') {
    for (const [key, qty] of Object.entries(size.stockByLocation)) {
      if (typeof qty === 'number') byLocation[key] = Math.trunc(qty);
    }
  } else if (typeof size.stock === 'number') {
    byLocation[kDefaultLocationId] = Math.trunc(size.stock);
  }
  byLocation[locationId] = stock;
  return {
    name: size.name ?? '',
    price: typeof size.price === 'number' ? size.price : 0,
    stockByLocation: byLocation,
  };
}
