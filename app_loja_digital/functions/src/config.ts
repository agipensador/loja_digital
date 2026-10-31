import { defineSecret, defineString } from 'firebase-functions/params';

/**
 * Segredos e configuração.
 *
 * NADA de credencial no código — regra do `docs/MERCADO_PAGO_SETUP.md` §6 e
 * das REGRAS dos agentes. `defineSecret` guarda o valor no Secret Manager do
 * Google; o dono digita uma vez no terminal:
 *
 *   firebase functions:secrets:set MP_WEBHOOK_SECRET --project loja-digital-ju0714
 *
 * O valor só é visível para a function que o declara em `secrets: [...]`.
 */

/** Assinatura secreta do webhook (painel do MP → Webhooks). */
export const MP_WEBHOOK_SECRET = defineSecret('MP_WEBHOOK_SECRET');

/**
 * Access Token da conta MP da **plataforma** (Inforizz). Não é usado no
 * checkout da loja — ali vale sempre o token da própria loja (marketplace) —
 * mas é o que vai cobrar a mensalidade (Fase 3). Declarado aqui porque o
 * documento de setup pede os três segredos de uma vez.
 */
export const MP_PLATFORM_ACCESS_TOKEN = defineSecret('MP_PLATFORM_ACCESS_TOKEN');

/** Client Secret da aplicação MP — usado pelo OAuth das lojas (tarefa L5). */
export const MP_CLIENT_SECRET = defineSecret('MP_CLIENT_SECRET');

/** Região das functions — São Paulo, como diz o docs/MERCADO_PAGO_SETUP.md. */
export const kRegiao = 'southamerica-east1';

/**
 * URL pública da function `mpWebhook`, mandada ao MP em cada cobrança.
 * Tem padrão para não travar o deploy, e pode ser trocada sem mexer no
 * código (`firebase functions:config` / variável de ambiente).
 */
export const MP_WEBHOOK_URL = defineString('MP_WEBHOOK_URL', {
  default:
    'https://southamerica-east1-loja-digital-ju0714.cloudfunctions.net/mpWebhook',
  description: 'URL da function mpWebhook, informada ao Mercado Pago.',
});
