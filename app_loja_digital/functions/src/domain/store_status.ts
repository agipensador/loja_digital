import { kGraceDays, StoreDoc } from './documents';

/** Mesmos estados de `SubscriptionStatus` (lib/models/subscription.dart). */
export type SubscriptionStatus = 'trial' | 'active' | 'overdue' | 'suspended';

/**
 * Converte o que vem do Firestore numa data: `Timestamp` do Admin SDK (tem
 * `toDate()`), `Date`, número (ms) ou string ISO. Retorna null se não der.
 */
export function toDate(value: unknown): Date | null {
  if (value instanceof Date) return Number.isNaN(value.getTime()) ? null : value;
  if (
    value &&
    typeof value === 'object' &&
    typeof (value as { toDate?: unknown }).toDate === 'function'
  ) {
    const date = (value as { toDate: () => Date }).toDate();
    return date instanceof Date && !Number.isNaN(date.getTime()) ? date : null;
  }
  if (typeof value === 'number' && Number.isFinite(value)) return new Date(value);
  if (typeof value === 'string') {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }
  return null;
}

function addDays(date: Date, days: number): Date {
  return new Date(date.getTime() + days * 24 * 60 * 60 * 1000);
}

/**
 * Situação da assinatura calculada pelas DATAS, igual ao app
 * (`Subscription.statusAt`) — nunca um campo gravado "na mão".
 *
 * Sem `trialEndsAt` no documento tratamos como suspensa: loja sem assinatura
 * registrada não vende. (O app assume trial de 60 dias nesse caso porque lá
 * o objeto nasce com `Subscription.startTrial()`; aqui, do lado do dinheiro,
 * o padrão seguro é o contrário.)
 */
export function subscriptionStatus(
  store: StoreDoc,
  now: Date,
): SubscriptionStatus {
  const trialEndsAt = toDate(store.subscription?.trialEndsAt);
  const paidUntil = toDate(store.subscription?.paidUntil);
  if (!trialEndsAt && !paidUntil) return 'suspended';

  if (trialEndsAt && now < trialEndsAt && (!paidUntil || now > paidUntil)) {
    return 'trial';
  }
  const covered =
    paidUntil && trialEndsAt
      ? paidUntil > trialEndsAt
        ? paidUntil
        : trialEndsAt
      : (paidUntil ?? trialEndsAt!);
  if (now < covered) return 'active';
  if (now < addDays(covered, kGraceDays)) return 'overdue';
  return 'suspended';
}

/** A loja pode vender? — igual a `StoreAccount.canSell`. */
export function canSell(store: StoreDoc, now: Date): boolean {
  const active = store.active ?? true;
  return active && subscriptionStatus(store, now) !== 'suspended';
}
