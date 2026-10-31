import { CheckoutRepository } from '../data/repository';
import { deveAplicar, lerStatusDoPagamento } from '../domain/payment_status';
import { MercadoPagoApi } from '../mp/client';
import { verificarAssinatura } from '../domain/signature';

/**
 * Processamento do aviso (webhook) do Mercado Pago.
 *
 * Três garantias, nesta ordem:
 *  1. **assinatura** — sem HMAC válido não se lê o corpo (senão qualquer um
 *     posta "aprovado" e leva o produto de graça);
 *  2. **fonte de verdade** — o status vem de um GET no MP, não do corpo do
 *     aviso;
 *  3. **idempotência** — o MP reenvia o mesmo aviso; confirmar duas vezes não
 *     pode confirmar o pedido duas vezes nem devolver estoque duas vezes.
 */

export interface AvisoRecebido {
  /** Cabeçalhos (em minúsculas). */
  headers: Record<string, string | undefined>;
  /** Corpo já convertido de JSON. */
  body: Record<string, unknown>;
  /** Parâmetros da query (o MP às vezes manda `data.id` por lá). */
  query: Record<string, string | undefined>;
}

export interface ResultadoDoAviso {
  /** Código HTTP a responder. 2xx faz o MP parar de reenviar. */
  status: number;
  /** Para o log — nunca vai no corpo da resposta. */
  detalhe: string;
}

export interface DependenciasDoAviso {
  repo: CheckoutRepository;
  mp: MercadoPagoApi;
  segredoDoWebhook: string;
  agora: () => Date;
  log: (mensagem: string, dados?: Record<string, unknown>) => void;
}

function pegarDataId(aviso: AvisoRecebido): string {
  const data = aviso.body.data as Record<string, unknown> | undefined;
  const doCorpo = data?.id;
  if (typeof doCorpo === 'string' && doCorpo) return doCorpo;
  if (typeof doCorpo === 'number') return String(doCorpo);
  return aviso.query['data.id'] ?? aviso.query.id ?? '';
}

/** Id do aviso, usado para não processar o mesmo duas vezes. */
function pegarAvisoId(aviso: AvisoRecebido, dataId: string): string {
  const id = aviso.body.id;
  const bruto =
    typeof id === 'string' || typeof id === 'number'
      ? String(id)
      : (aviso.headers['x-request-id'] ?? '');
  const acao = String(aviso.body.action ?? aviso.body.type ?? 'payment');
  // Sem id nenhum, o par (pagamento, ação) ainda evita o reenvio imediato.
  const chave = bruto ? `${bruto}` : `${dataId}-${acao}`;
  return chave.replace(/[^A-Za-z0-9_.:-]/g, '_').slice(0, 200);
}

export async function processarAviso(
  deps: DependenciasDoAviso,
  aviso: AvisoRecebido,
): Promise<ResultadoDoAviso> {
  const dataId = pegarDataId(aviso);

  // 1. Assinatura. Falha aqui = 401 e nada é lido do corpo.
  const assinatura = verificarAssinatura({
    signature: aviso.headers['x-signature'],
    requestId: aviso.headers['x-request-id'],
    dataId,
    secret: deps.segredoDoWebhook,
    agoraMs: deps.agora().getTime(),
  });
  if (!assinatura.valida) {
    deps.log('aviso do MP recusado', { motivo: assinatura.motivo });
    return { status: 401, detalhe: `assinatura: ${assinatura.motivo}` };
  }

  // Só tratamos pagamento; o resto é confirmado para o MP não reenviar.
  const tipo = String(aviso.body.type ?? aviso.body.topic ?? '');
  if (tipo && tipo !== 'payment') {
    deps.log('aviso ignorado (outro tipo)', { tipo });
    return { status: 200, detalhe: `tipo ignorado: ${tipo}` };
  }
  if (!dataId) {
    return { status: 200, detalhe: 'aviso sem data.id' };
  }

  // 3a. Idempotência: o mesmo aviso não roda duas vezes.
  const avisoId = pegarAvisoId(aviso, dataId);
  const primeiraVez = await deps.repo.registrarAviso(avisoId);
  if (!primeiraVez) {
    deps.log('aviso repetido, ignorado', { avisoId });
    return { status: 200, detalhe: 'aviso já processado' };
  }

  const checkout = await deps.repo.checkoutPorPagamento(dataId);
  if (!checkout) {
    // Pode ser pagamento de outra integração (ou a mensalidade, que ainda
    // não existe). 200 para o MP não ficar reenviando para sempre.
    deps.log('pagamento sem checkout correspondente', { dataId });
    return { status: 200, detalhe: 'checkout não encontrado' };
  }

  const credenciais = await deps.repo.credenciaisDaLoja(checkout.storeId);
  const accessToken = credenciais?.accessToken ?? '';
  if (!accessToken) {
    // A loja desconectou o MP: sem token não há como confirmar. 500 para o
    // MP reenviar (o lojista pode reconectar e o aviso volta a funcionar).
    deps.log('loja sem token do MP ao processar aviso', {
      storeId: checkout.storeId,
    });
    return { status: 500, detalhe: 'loja sem token do MP' };
  }

  // 2. Fonte de verdade: o status é lido no MP.
  let pagamento;
  try {
    pagamento = await deps.mp.lerPagamento(dataId, accessToken);
  } catch (erro) {
    deps.log('falha ao ler o pagamento no MP', {
      dataId,
      erro: erro instanceof Error ? erro.message : String(erro),
    });
    return { status: 500, detalhe: 'falha ao ler o pagamento' };
  }

  const leitura = lerStatusDoPagamento(pagamento.status);

  // 3b. Idempotência de verdade: quem decide é o estado atual do checkout.
  if (!deveAplicar(checkout.status, leitura.checkoutStatus)) {
    deps.log('aviso sem efeito', {
      checkoutId: checkout.id,
      de: checkout.status,
      para: leitura.checkoutStatus,
      mpStatus: pagamento.status,
    });
    return { status: 200, detalhe: 'sem mudança de estado' };
  }

  switch (leitura.acao) {
    case 'confirmar':
      await deps.repo.confirmarPedido({
        storeId: checkout.storeId,
        checkoutId: checkout.id,
        mpPaymentId: dataId,
        mpStatus: pagamento.status,
      });
      break;
    case 'cancelar':
    case 'estornar':
      await deps.repo.liberarReserva({
        storeId: checkout.storeId,
        checkoutId: checkout.id,
        status: leitura.checkoutStatus,
        mpStatus: pagamento.status,
      });
      break;
    case 'aguardar':
      break;
  }

  deps.log('aviso do MP aplicado', {
    storeId: checkout.storeId,
    orderId: checkout.orderId,
    acao: leitura.acao,
    mpStatus: pagamento.status,
  });
  return { status: 200, detalhe: `aplicado: ${leitura.acao}` };
}
