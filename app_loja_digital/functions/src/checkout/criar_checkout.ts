import { CheckoutRepository } from '../data/repository';
import { CheckoutError, erroDeNegocio } from '../domain/errors';
import { toCents } from '../domain/money';
import { lerStatusDoPagamento } from '../domain/payment_status';
import { priceOrder } from '../domain/pricing';
import { CheckoutRequest, locationIdDoPedido } from '../domain/request';
import { canSell } from '../domain/store_status';
import {
  MercadoPagoApi,
  PagamentoCartao,
  PagamentoPix,
} from '../mp/client';

/** Minutos de validade do Pix — depois disso o estoque volta (`expireCheckouts`). */
export const kPixExpiraEmMinutos = 30;

export interface RespostaDoCheckout {
  orderId: string;
  checkoutId: string;
  /** 'pending' | 'paid' | 'failed' | ... */
  status: string;
  approved: boolean;
  total: number;
  mpStatus: string;
  message: string;
  pixCopyPaste?: string;
  pixQrBase64?: string;
  pixExpiresAt?: string;
}

export interface DependenciasDoCheckout {
  repo: CheckoutRepository;
  mp: MercadoPagoApi;
  /** URL pública da function `mpWebhook`. */
  urlDoAviso: string;
  agora: () => Date;
  log: (mensagem: string, dados?: Record<string, unknown>) => void;
}

function mensagemDoStatus(mpStatus: string, detalhe: string): string {
  switch (mpStatus) {
    case 'approved':
      return 'Pagamento aprovado.';
    case 'pending':
    case 'in_process':
    case 'authorized':
      return 'Aguardando a confirmação do pagamento.';
    case 'rejected':
      return detalhe === 'cc_rejected_insufficient_amount'
        ? 'Cartão sem limite suficiente.'
        : 'Pagamento recusado pelo banco. Tente outro cartão ou use Pix.';
    case 'cancelled':
      return 'Pagamento cancelado.';
    default:
      return 'Pagamento registrado.';
  }
}

/**
 * Fluxo do checkout no servidor:
 *
 *  1. já existe checkout com esta chave? devolve o mesmo (idempotência)
 *  2. a loja pode vender? conectou o Mercado Pago?
 *  3. recalcula o pedido inteiro pelo Firestore (nada de preço do app)
 *  4. reserva: baixa estoque + cria o pedido "aguardando pagamento"
 *  5. cobra no MP com o token da loja e `application_fee` da plataforma
 *  6. falhou a cobrança → devolve o estoque; recusou → cancela o pedido
 *
 * O pedido nasce reservado ANTES da cobrança de propósito: é melhor devolver
 * estoque de uma cobrança que falhou (passo 6) do que vender o que não tem
 * porque duas pessoas pagaram a última peça ao mesmo tempo.
 */
export async function criarCheckout(
  deps: DependenciasDoCheckout,
  pedido: CheckoutRequest,
  userId: string,
): Promise<RespostaDoCheckout> {
  const { repo, mp } = deps;

  // 1. Idempotência: mesma chave = mesmo checkout, nunca um segundo pedido.
  const existente = await repo.buscarCheckout(pedido.storeId, pedido.idempotencyKey);
  if (existente) {
    if (existente.userId !== userId) {
      throw erroDeNegocio('pedido-invalido', 'Pedido inválido.');
    }
    deps.log('checkout reaproveitado', {
      storeId: pedido.storeId,
      checkoutId: existente.id,
      status: existente.status,
    });
    return {
      orderId: existente.orderId,
      checkoutId: existente.id,
      status: existente.status,
      approved: existente.status === 'paid',
      total: existente.total,
      mpStatus: existente.mpStatus ?? '',
      message:
        existente.status === 'paid'
          ? 'Pagamento aprovado.'
          : 'Aguardando a confirmação do pagamento.',
      pixCopyPaste: existente.pixCopyPaste,
      pixQrBase64: existente.pixQrBase64,
      pixExpiresAt: existente.pixExpiresAt,
    };
  }

  const locationId = locationIdDoPedido(pedido.items);
  const dados = await repo.carregar({
    storeId: pedido.storeId,
    locationId,
    zoneId: pedido.delivery.zoneId,
    pids: [...new Set(pedido.items.map((i) => i.pid))],
  });

  // 2. Loja suspensa não vende (mesma regra do app, calculada por datas).
  if (!canSell(dados.store, deps.agora())) {
    throw erroDeNegocio(
      'loja-indisponivel',
      'Esta loja está temporariamente indisponível.',
    );
  }
  const accessToken = dados.credenciais?.accessToken ?? '';
  if (!accessToken) {
    throw erroDeNegocio(
      'mp-nao-conectado',
      'Esta loja ainda não conectou o Mercado Pago. Fale com a loja.',
    );
  }

  // 3. Preço: tudo recalculado a partir do banco.
  const preco = priceOrder({
    items: pedido.items,
    products: dados.products,
    store: dados.store,
    location: dados.location,
    zone: dados.zone,
    delivery: pedido.delivery,
    locationId,
  });
  if (toCents(preco.total) <= 0) {
    throw erroDeNegocio('pedido-invalido', 'Total do pedido inválido.');
  }
  // O split não pode comer o pedido inteiro (nem o MP aceitaria).
  if (toCents(preco.platformFee) >= toCents(preco.total)) {
    throw erroDeNegocio(
      'pedido-invalido',
      'Valor do pedido menor que a taxa de serviço.',
    );
  }

  // 4. Reserva (transação: estoque + contador + pedido + checkout).
  const { orderId } = await repo.reservar({
    storeId: pedido.storeId,
    checkoutId: pedido.idempotencyKey,
    userId,
    lines: preco.lines,
    items: pedido.items,
    productsPrice: preco.productsPrice,
    deliveryPrice: preco.deliveryPrice,
    serviceFee: preco.serviceFee,
    platformFee: preco.platformFee,
    total: preco.total,
    locationId,
    address: pedido.address,
    paymentLabel: pedido.paymentLabel,
    paymentType: pedido.paymentType,
    shipping: {
      method: pedido.delivery.method,
      zoneId: pedido.delivery.zoneId ?? '',
      preferredDate: pedido.delivery.preferredDate ?? null,
    },
  });

  // 5. Cobrança no Mercado Pago, com o token da LOJA e a taxa da plataforma.
  const comum = {
    valor: preco.total,
    taxaDaPlataforma: preco.platformFee,
    descricao: `${dados.store.name ?? 'Loja'} - pedido ${orderId}`,
    referenciaExterna: `${pedido.storeId}:${orderId}:${pedido.idempotencyKey}`,
    pagador: {
      email: pedido.payerEmail,
      cpf: pedido.payerCpf || undefined,
      nome: pedido.payerName || undefined,
    },
    urlDoAviso: deps.urlDoAviso,
    chaveDeIdempotencia: pedido.idempotencyKey,
  };

  const cobranca: PagamentoPix | PagamentoCartao =
    pedido.paymentType === 'card'
      ? {
          ...comum,
          tipo: 'cartao',
          tokenDoCartao: pedido.cardToken,
          parcelas: pedido.installments,
        }
      : { ...comum, tipo: 'pix', expiraEmMinutos: kPixExpiraEmMinutos };

  let resposta;
  try {
    resposta = await mp.criarPagamento(cobranca, accessToken);
  } catch (erro) {
    // 6. Não cobrou: o estoque tem de voltar, senão some do catálogo sem venda.
    await repo.liberarReserva({
      storeId: pedido.storeId,
      checkoutId: pedido.idempotencyKey,
      status: 'failed',
      mpStatus: 'erro-na-cobranca',
    });
    deps.log('falha ao cobrar no Mercado Pago', {
      storeId: pedido.storeId,
      orderId,
      erro: erro instanceof Error ? erro.message : String(erro),
    });
    if (erro instanceof CheckoutError) throw erro;
    throw erroDeNegocio(
      'provedor-indisponivel',
      'Não conseguimos gerar a cobrança agora. Tente de novo em instantes.',
    );
  }

  const leitura = lerStatusDoPagamento(resposta.status);
  await repo.registrarPagamento(pedido.storeId, pedido.idempotencyKey, {
    mpPaymentId: resposta.id,
    mpStatus: resposta.status,
    checkoutStatus: leitura.checkoutStatus,
    pixCopyPaste: resposta.pixCopiaECola,
    pixQrBase64: resposta.pixQrBase64,
    pixExpiresAt: resposta.expiraEm,
  });

  if (leitura.acao === 'confirmar') {
    // Cartão aprovado na hora: não há por que esperar o webhook.
    await repo.confirmarPedido({
      storeId: pedido.storeId,
      checkoutId: pedido.idempotencyKey,
      mpPaymentId: resposta.id,
      mpStatus: resposta.status,
    });
  } else if (leitura.acao === 'cancelar' || leitura.acao === 'estornar') {
    await repo.liberarReserva({
      storeId: pedido.storeId,
      checkoutId: pedido.idempotencyKey,
      status: leitura.checkoutStatus,
      mpStatus: resposta.status,
    });
  }

  deps.log('checkout criado', {
    storeId: pedido.storeId,
    orderId,
    mpStatus: resposta.status,
    total: preco.total,
  });

  return {
    orderId,
    checkoutId: pedido.idempotencyKey,
    status: leitura.checkoutStatus,
    approved: leitura.acao === 'confirmar',
    total: preco.total,
    mpStatus: resposta.status,
    message: mensagemDoStatus(resposta.status, resposta.detalheDoStatus),
    pixCopyPaste: resposta.pixCopiaECola,
    pixQrBase64: resposta.pixQrBase64,
    pixExpiresAt: resposta.expiraEm,
  };
}
