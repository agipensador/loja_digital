/**
 * Dinheiro sempre com 2 casas — mesma regra do app (`roundMoney` em
 * lib/models/order.dart). Evita gravar 559.4000000000001 no Firestore e
 * garante que o valor enviado ao Mercado Pago é o mesmo que foi gravado.
 */
export function roundMoney(value: number): number {
  return Math.round(value * 100) / 100;
}

/** Centavos inteiros — usado para comparar valores sem erro de ponto flutuante. */
export function toCents(value: number): number {
  return Math.round(value * 100);
}

export function isFiniteMoney(value: unknown): value is number {
  return typeof value === 'number' && Number.isFinite(value) && value >= 0;
}
