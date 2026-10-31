import { createHmac, timingSafeEqual } from 'node:crypto';

/**
 * Verificação da assinatura do webhook do Mercado Pago.
 *
 * O MP manda o cabeçalho `x-signature: ts=<segundos>,v1=<hmac hex>`, e o hmac
 * é SHA-256, com a *assinatura secreta* do painel, sobre o molde:
 *
 *     id:<data.id>;request-id:<x-request-id>;ts:<ts>;
 *
 * Sem isso qualquer um que descubra a URL pode postar "pagamento aprovado" e
 * liberar pedido sem pagar — por isso a função é separada, pura e testada.
 * Ver docs/MERCADO_PAGO_SETUP.md §5.
 */

export interface VerificacaoAssinatura {
  valida: boolean;
  /** Por que falhou (vai para o log; nunca para a resposta HTTP). */
  motivo?:
    | 'sem-segredo'
    | 'cabecalho-ausente'
    | 'cabecalho-malformado'
    | 'sem-data-id'
    | 'ts-invalido'
    | 'ts-fora-da-janela'
    | 'hmac-diferente';
}

/** Janela de tolerância do `ts` (protege contra reenvio de aviso antigo). */
export const kToleranciaSegundos = 5 * 60;

function parseHeader(header: string): Map<string, string> {
  const partes = new Map<string, string>();
  for (const pedaco of header.split(',')) {
    const separador = pedaco.indexOf('=');
    if (separador <= 0) continue;
    const chave = pedaco.slice(0, separador).trim();
    const valor = pedaco.slice(separador + 1).trim();
    if (chave && valor) partes.set(chave, valor);
  }
  return partes;
}

function hmacIgual(esperado: string, recebido: string): boolean {
  // `timingSafeEqual` exige o mesmo tamanho; comparar antes já vaza só o
  // tamanho do hash, que é público (SHA-256 = 64 hex).
  if (esperado.length !== recebido.length) return false;
  try {
    return timingSafeEqual(
      Buffer.from(esperado, 'utf8'),
      Buffer.from(recebido.toLowerCase(), 'utf8'),
    );
  } catch {
    return false;
  }
}

export function verificarAssinatura(args: {
  /** Cabeçalho `x-signature`. */
  signature: string | undefined;
  /** Cabeçalho `x-request-id`. */
  requestId: string | undefined;
  /** `data.id` do corpo (ou `?data.id=` da query). */
  dataId: string | undefined;
  /** Assinatura secreta do painel do MP (secret `MP_WEBHOOK_SECRET`). */
  secret: string;
  /** Agora, em ms (injetado para o teste não depender do relógio). */
  agoraMs: number;
  toleranciaSegundos?: number;
}): VerificacaoAssinatura {
  if (!args.secret) return { valida: false, motivo: 'sem-segredo' };
  if (!args.signature) return { valida: false, motivo: 'cabecalho-ausente' };

  const partes = parseHeader(args.signature);
  const ts = partes.get('ts');
  const v1 = partes.get('v1');
  if (!ts || !v1) return { valida: false, motivo: 'cabecalho-malformado' };

  if (!args.dataId) return { valida: false, motivo: 'sem-data-id' };

  const tsNumero = Number(ts);
  if (!Number.isFinite(tsNumero) || tsNumero <= 0) {
    return { valida: false, motivo: 'ts-invalido' };
  }
  const tolerancia = args.toleranciaSegundos ?? kToleranciaSegundos;
  // O MP manda `ts` em segundos; alguns avisos antigos vinham em ms.
  const tsMs = ts.length > 11 ? tsNumero : tsNumero * 1000;
  if (Math.abs(args.agoraMs - tsMs) > tolerancia * 1000) {
    return { valida: false, motivo: 'ts-fora-da-janela' };
  }

  // O `request-id` entra no molde só quando o MP o enviou.
  const molde =
    `id:${args.dataId};` +
    (args.requestId ? `request-id:${args.requestId};` : '') +
    `ts:${ts};`;
  const esperado = createHmac('sha256', args.secret)
    .update(molde)
    .digest('hex');

  return hmacIgual(esperado, v1)
    ? { valida: true }
    : { valida: false, motivo: 'hmac-diferente' };
}

/** Só para os testes montarem um cabeçalho válido (não é usado em produção). */
export function assinarParaTeste(args: {
  dataId: string;
  requestId?: string;
  secret: string;
  tsSegundos: number;
}): string {
  const molde =
    `id:${args.dataId};` +
    (args.requestId ? `request-id:${args.requestId};` : '') +
    `ts:${args.tsSegundos};`;
  const v1 = createHmac('sha256', args.secret).update(molde).digest('hex');
  return `ts=${args.tsSegundos},v1=${v1}`;
}
