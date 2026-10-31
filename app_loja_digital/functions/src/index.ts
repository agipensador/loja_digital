import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { onRequest } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions';

import { kRegiao, MP_WEBHOOK_SECRET, MP_WEBHOOK_URL } from './config';
import { criarCheckout } from './checkout/criar_checkout';
import { FirestoreCheckoutRepository } from './data/firestore_repository';
import { CheckoutError } from './domain/errors';
import { parseCheckoutRequest } from './domain/request';
import { HttpMercadoPagoApi } from './mp/client';
import { processarAviso } from './webhook/processar_aviso';

initializeApp();

const db = getFirestore();
const repo = new FirestoreCheckoutRepository(db);
const mp = new HttpMercadoPagoApi();
const agora = () => new Date();

/**
 * `createCheckout` — o checkout saiu do app e veio para cá.
 *
 * O app manda apenas QUAIS itens, COMO quer receber e a forma de pagamento;
 * preço, frete, taxa e estoque são recalculados aqui a partir do Firestore.
 * Ver docs/PAGAMENTOS_BACKEND.md.
 */
export const createCheckout = onCall(
  {
    region: kRegiao,
    secrets: [],
    // O checkout fala com o MP: sem isso o Pix pode estourar o tempo.
    timeoutSeconds: 60,
    memory: '256MiB',
    // Um checkout por vez por instância mantém a cobrança previsível.
    concurrency: 20,
    enforceAppCheck: false,
  },
  async (request) => {
    const userId = request.auth?.uid;
    if (!userId) {
      throw new HttpsError(
        'unauthenticated',
        'Entre na sua conta para finalizar o pedido.',
      );
    }

    try {
      const pedido = parseCheckoutRequest(request.data);
      return await criarCheckout(
        {
          repo,
          mp,
          urlDoAviso: MP_WEBHOOK_URL.value(),
          agora,
          log: (mensagem, dados) => logger.info(mensagem, dados),
        },
        pedido,
        userId,
      );
    } catch (erro) {
      if (erro instanceof CheckoutError) {
        // `failed-precondition` + o código: o app mostra a mensagem e sabe
        // distinguir "sem estoque" de "loja não conectou o Mercado Pago".
        throw new HttpsError('failed-precondition', erro.message, {
          code: erro.code,
        });
      }
      logger.error('falha inesperada no checkout', {
        erro: erro instanceof Error ? erro.message : String(erro),
      });
      throw new HttpsError(
        'internal',
        'Não conseguimos finalizar o pedido agora. Tente de novo.',
      );
    }
  },
);

/**
 * `mpWebhook` — aviso de pagamento do Mercado Pago.
 *
 * Confere a assinatura, lê o status no MP (o corpo do aviso não é fonte de
 * verdade) e aplica uma vez só. URL a cadastrar no painel do MP:
 * docs/MERCADO_PAGO_SETUP.md §5.
 */
export const mpWebhook = onRequest(
  {
    region: kRegiao,
    secrets: [MP_WEBHOOK_SECRET],
    timeoutSeconds: 60,
    memory: '256MiB',
    // O MP posta sem autenticação do Firebase; quem autentica é a assinatura.
    invoker: 'public',
  },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).send('metodo-nao-permitido');
      return;
    }

    const headers: Record<string, string | undefined> = {};
    for (const [chave, valor] of Object.entries(req.headers)) {
      headers[chave.toLowerCase()] = Array.isArray(valor) ? valor[0] : valor;
    }
    const query: Record<string, string | undefined> = {};
    for (const [chave, valor] of Object.entries(req.query ?? {})) {
      query[chave] = Array.isArray(valor) ? String(valor[0]) : String(valor);
    }

    try {
      const resultado = await processarAviso(
        {
          repo,
          mp,
          segredoDoWebhook: MP_WEBHOOK_SECRET.value(),
          agora,
          log: (mensagem, dados) => logger.info(mensagem, dados),
        },
        {
          headers,
          body:
            req.body && typeof req.body === 'object'
              ? (req.body as Record<string, unknown>)
              : {},
          query,
        },
      );
      // O corpo nunca conta o motivo: quem está sondando a URL não aprende
      // nada. O detalhe fica no log.
      res.status(resultado.status).send(resultado.status === 200 ? 'ok' : '');
    } catch (erro) {
      logger.error('falha ao processar aviso do MP', {
        erro: erro instanceof Error ? erro.message : String(erro),
      });
      // 500 faz o Mercado Pago reenviar — é o que queremos num erro nosso.
      res.status(500).send('');
    }
  },
);
