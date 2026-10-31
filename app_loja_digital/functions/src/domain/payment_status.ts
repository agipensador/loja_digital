/**
 * Tradução do status do pagamento no Mercado Pago para o que o pedido faz.
 *
 * Os `status` do MP são: pending, approved, authorized, in_process,
 * in_mediation, rejected, cancelled, refunded, charged_back.
 */

/** Status do pedido — ÍNDICE do enum `Status` em lib/models/order.dart. */
export const OrderStatus = {
  canceled: 0,
  preparing: 1,
  transporting: 2,
  delivered: 3,
  pendingPayment: 4,
  readyForPickup: 5,
} as const;

export type CheckoutStatus =
  | 'pending'
  | 'paid'
  | 'failed'
  | 'refunded'
  | 'expired';

export type AcaoDoPagamento =
  /** Confirma o pedido: sai de "aguardando pagamento" para "em separação". */
  | 'confirmar'
  /** Continua esperando (Pix não pago, análise do cartão). */
  | 'aguardar'
  /** Cancela e devolve o estoque. */
  | 'cancelar'
  /** Pago e depois devolvido: cancela, devolve estoque e marca estorno. */
  | 'estornar';

export interface LeituraDoPagamento {
  acao: AcaoDoPagamento;
  checkoutStatus: CheckoutStatus;
  /** Status do MP, guardado no checkout para o lojista e para depuração. */
  mpStatus: string;
}

export function lerStatusDoPagamento(mpStatus: string): LeituraDoPagamento {
  switch (mpStatus) {
    case 'approved':
      return { acao: 'confirmar', checkoutStatus: 'paid', mpStatus };

    // "authorized" é cartão só autorizado (sem captura). O dinheiro ainda não
    // é da loja, então o pedido continua aguardando.
    case 'authorized':
    case 'pending':
    case 'in_process':
    case 'in_mediation':
      return { acao: 'aguardar', checkoutStatus: 'pending', mpStatus };

    case 'refunded':
    case 'charged_back':
      return { acao: 'estornar', checkoutStatus: 'refunded', mpStatus };

    case 'rejected':
    case 'cancelled':
      return { acao: 'cancelar', checkoutStatus: 'failed', mpStatus };

    default:
      // Status novo que não conhecemos: não mexe no pedido (o lojista decide).
      return { acao: 'aguardar', checkoutStatus: 'pending', mpStatus };
  }
}

/**
 * A mudança de estado é idempotente: o mesmo aviso chegando duas vezes (o MP
 * reenvia) não pode confirmar o pedido duas vezes nem devolver estoque duas
 * vezes. Quem decide é o status ATUAL do checkout, não o aviso.
 */
export function deveAplicar(
  atual: CheckoutStatus | undefined,
  novo: CheckoutStatus,
): boolean {
  if (atual === novo) return false;
  switch (atual) {
    // Estados finais: nada reabre um checkout.
    case 'refunded':
      return false;
    case 'failed':
    case 'expired':
      // Só o estorno de um pagamento que chegou depois faz sentido aqui;
      // "pago" depois de falho é aviso fora de ordem, ignora.
      return novo === 'refunded';
    case 'paid':
      return novo === 'refunded';
    case 'pending':
    case undefined:
      return true;
  }
}
