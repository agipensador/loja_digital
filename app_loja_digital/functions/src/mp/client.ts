import { erroDeNegocio } from '../domain/errors';

/**
 * Cliente do Mercado Pago.
 *
 * É uma INTERFACE de propósito: os testes injetam um duplo e nunca tocam a
 * rede (exigência do aceite da tarefa L2). A implementação de verdade usa
 * `fetch` — o SDK oficial (`mercadopago`) só embala as mesmas chamadas REST
 * e traria uma dependência a mais para manter.
 *
 * O Access Token usado é SEMPRE o da loja (modelo marketplace): o dinheiro
 * cai na conta dela e a plataforma retém `application_fee`. O token nunca
 * vem do app — é lido de `stores/{id}/private/mp`, que as rules fecham.
 */

export interface PagamentoPix {
  tipo: 'pix';
  valor: number;
  /** Taxa da plataforma retida no split. */
  taxaDaPlataforma: number;
  descricao: string;
  /** `storeId:orderId` — como achamos o pedido quando o webhook chega. */
  referenciaExterna: string;
  pagador: { email: string; cpf?: string; nome?: string };
  /** Minutos até o Pix vencer. */
  expiraEmMinutos: number;
  urlDoAviso: string;
  chaveDeIdempotencia: string;
}

export interface PagamentoCartao {
  tipo: 'cartao';
  valor: number;
  taxaDaPlataforma: number;
  descricao: string;
  referenciaExterna: string;
  pagador: { email: string; cpf?: string; nome?: string };
  tokenDoCartao: string;
  parcelas: number;
  urlDoAviso: string;
  chaveDeIdempotencia: string;
}

export interface RespostaDePagamento {
  id: string;
  status: string;
  detalheDoStatus: string;
  /** Pix: o "copia e cola". */
  pixCopiaECola?: string;
  /** Pix: PNG do QR em base64. */
  pixQrBase64?: string;
  /** Pix: quando vence. */
  expiraEm?: string;
}

export interface MercadoPagoApi {
  criarPagamento(
    pedido: PagamentoPix | PagamentoCartao,
    accessToken: string,
  ): Promise<RespostaDePagamento>;

  /**
   * Lê o pagamento no MP. O webhook SEMPRE confirma por aqui: o corpo do
   * aviso não é fonte de verdade para status nem para valor.
   */
  lerPagamento(
    pagamentoId: string,
    accessToken: string,
  ): Promise<RespostaDePagamento>;
}

const kBaseUrl = 'https://api.mercadopago.com';
const kTempoLimiteMs = 20_000;

function corpoDoPagamento(
  pedido: PagamentoPix | PagamentoCartao,
): Record<string, unknown> {
  const pagador: Record<string, unknown> = { email: pedido.pagador.email };
  if (pedido.pagador.cpf) {
    pagador.identification = { type: 'CPF', number: pedido.pagador.cpf };
  }
  if (pedido.pagador.nome) pagador.first_name = pedido.pagador.nome;

  const comum: Record<string, unknown> = {
    transaction_amount: pedido.valor,
    description: pedido.descricao,
    external_reference: pedido.referenciaExterna,
    notification_url: pedido.urlDoAviso,
    statement_descriptor: 'INFORIZZ',
    payer: pagador,
  };
  // O split só entra quando há taxa: `application_fee: 0` o MP recusa.
  if (pedido.taxaDaPlataforma > 0) {
    comum.application_fee = pedido.taxaDaPlataforma;
  }

  if (pedido.tipo === 'pix') {
    return {
      ...comum,
      payment_method_id: 'pix',
      date_of_expiration: new Date(
        Date.now() + pedido.expiraEmMinutos * 60_000,
      ).toISOString(),
    };
  }
  return {
    ...comum,
    token: pedido.tokenDoCartao,
    installments: pedido.parcelas,
    capture: true,
  };
}

function lerResposta(json: Record<string, unknown>): RespostaDePagamento {
  const transacao = (json.point_of_interaction as Record<string, unknown>)
    ?.transaction_data as Record<string, unknown> | undefined;
  return {
    id: String(json.id ?? ''),
    status: String(json.status ?? ''),
    detalheDoStatus: String(json.status_detail ?? ''),
    pixCopiaECola:
      typeof transacao?.qr_code === 'string' ? transacao.qr_code : undefined,
    pixQrBase64:
      typeof transacao?.qr_code_base64 === 'string'
        ? transacao.qr_code_base64
        : undefined,
    expiraEm:
      typeof json.date_of_expiration === 'string'
        ? json.date_of_expiration
        : undefined,
  };
}

export class HttpMercadoPagoApi implements MercadoPagoApi {
  constructor(private readonly baseUrl: string = kBaseUrl) {}

  async criarPagamento(
    pedido: PagamentoPix | PagamentoCartao,
    accessToken: string,
  ): Promise<RespostaDePagamento> {
    const resposta = await this.chamar('POST', '/v1/payments', accessToken, {
      corpo: corpoDoPagamento(pedido),
      chaveDeIdempotencia: pedido.chaveDeIdempotencia,
    });
    return lerResposta(resposta);
  }

  async lerPagamento(
    pagamentoId: string,
    accessToken: string,
  ): Promise<RespostaDePagamento> {
    const resposta = await this.chamar(
      'GET',
      `/v1/payments/${encodeURIComponent(pagamentoId)}`,
      accessToken,
    );
    return lerResposta(resposta);
  }

  private async chamar(
    metodo: 'GET' | 'POST',
    caminho: string,
    accessToken: string,
    opcoes?: {
      corpo?: Record<string, unknown>;
      chaveDeIdempotencia?: string;
    },
  ): Promise<Record<string, unknown>> {
    const cabecalhos: Record<string, string> = {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    };
    if (opcoes?.chaveDeIdempotencia) {
      // Garante que um retry nosso não cria uma segunda cobrança.
      cabecalhos['X-Idempotency-Key'] = opcoes.chaveDeIdempotencia;
    }

    let resposta: Response;
    try {
      resposta = await fetch(`${this.baseUrl}${caminho}`, {
        method: metodo,
        headers: cabecalhos,
        body: opcoes?.corpo ? JSON.stringify(opcoes.corpo) : undefined,
        signal: AbortSignal.timeout(kTempoLimiteMs),
      });
    } catch (e) {
      throw erroDeNegocio(
        'provedor-indisponivel',
        'Não conseguimos falar com o Mercado Pago. Tente de novo.',
      );
    }

    const texto = await resposta.text();
    let json: Record<string, unknown> = {};
    try {
      json = texto ? (JSON.parse(texto) as Record<string, unknown>) : {};
    } catch {
      json = {};
    }

    if (!resposta.ok) {
      // A mensagem do MP é técnica e pode citar dado do pagador: fica no log.
      throw new MercadoPagoHttpError(
        resposta.status,
        String(json.message ?? json.error ?? 'erro sem detalhe'),
        json,
      );
    }
    return json;
  }
}

export class MercadoPagoHttpError extends Error {
  constructor(
    readonly status: number,
    message: string,
    readonly corpo: Record<string, unknown>,
  ) {
    super(message);
    this.name = 'MercadoPagoHttpError';
  }
}
