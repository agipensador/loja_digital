# Mercado Pago: criar a aplicação e vincular à plataforma

Passo a passo para o Giovanni (feito uma vez, na conta Mercado Pago da
**Inforizz**). As lojas não criam aplicação: cada uma só toca em "Conectar
Mercado Pago" no app e autoriza (OAuth).

> ⚠ Credenciais (Access Token, Client Secret, assinatura do webhook) **nunca**
> vão no código, no chat ou em print. Elas entram só como *secrets* do
> Firebase (passo 6), digitadas por você no terminal.

## URLs que o Mercado Pago vai pedir

As Cloud Functions ficam na região de São Paulo (`southamerica-east1`) do
projeto `loja-digital-ju0714`, então as URLs já são fixas:

| Para quê | URL |
|---|---|
| Redirecionamento do OAuth (loja conecta a conta) | `https://southamerica-east1-loja-digital-ju0714.cloudfunctions.net/oauthConnectStore` |
| Webhook (aviso de pagamento) | `https://southamerica-east1-loja-digital-ju0714.cloudfunctions.net/mpWebhook` |

## 1. Conta da Inforizz no Mercado Pago
- De preferência conta **PJ** (CNPJ da Inforizz): é ela que recebe a taxa de
  R$ 0,99 por pedido e as mensalidades.
- Ative a conta (dados, documento, conta bancária para saque).

## 2. Criar a aplicação
1. Acesse https://www.mercadopago.com.br/developers/panel/app e entre com a
   conta da Inforizz.
2. **Criar aplicação**:
   - Nome: `Inforizz Lojas`
   - Tipo de solução: **Pagamentos online**
   - Plataforma de e-commerce: **Não**
   - Produto: **Checkout Pro** (cartão pela página do MP). O Pix é feito
     pela API de pagamentos com o mesmo app.
   - Modelo: **Marketplace** (se o painel perguntar), porque o dinheiro vai
     para a conta de cada loja e a Inforizz retém a taxa.
3. Aceite os termos e crie.

(Os nomes dos menus mudam de vez em quando; se algum não bater, procure
pela opção equivalente.)

## 3. Configurar o OAuth
Em **Suas integrações → Inforizz Lojas → Detalhes da aplicação → Editar**:
- **URLs de redirecionamento**: cole a URL do OAuth da tabela acima
  (idêntica, sem barra no final).
- **PKCE**: pode ativar (o backend vai usar).

Anote (só para você):
- **Client ID** (= App ID): é público, vai no app.
- **Client Secret**: secreto, vai para o passo 6.

## 4. Credenciais e contas de teste
1. Em **Credenciais de teste**, anote a **Public Key** de teste (vai no
   app) e o **Access Token** de teste (secreto, passo 6).
2. Em **Contas de teste**, crie duas contas:
   - **Vendedor** (faz o papel de uma loja, ex.: Loja Ju)
   - **Comprador** (faz o papel do cliente)
   Guarde usuário e senha delas num gerenciador de senhas. Os testes de
   ponta a ponta usam essas contas, nunca cartão real.

## 5. Webhook
Em **Suas integrações → Inforizz Lojas → Webhooks → Configurar
notificações**:
- URL de **modo de teste** e de **produção**: a URL do webhook da tabela.
- Eventos: **Pagamentos** (e **Planos e assinaturas**, para a mensalidade).
- Salve e revele a **assinatura secreta**: ela confirma que o aviso veio
  mesmo do Mercado Pago (cabeçalho `x-signature`, HMAC-SHA256 sobre
  `id:<data.id>;request-id:<x-request-id>;ts:<ts>;`).

## 6. Guardar os segredos no Firebase (você digita, ninguém vê)
No terminal, na pasta do app (`app_loja_digital`), um por vez. O comando
pede o valor sem mostrar na tela:

```bash
firebase functions:secrets:set MP_CLIENT_SECRET --project loja-digital-ju0714
firebase functions:secrets:set MP_WEBHOOK_SECRET --project loja-digital-ju0714
firebase functions:secrets:set MP_PLATFORM_ACCESS_TOKEN --project loja-digital-ju0714
```

- `MP_CLIENT_SECRET`: do passo 3
- `MP_WEBHOOK_SECRET`: do passo 5
- `MP_PLATFORM_ACCESS_TOKEN`: o Access Token **de teste** por enquanto
  (cobra as mensalidades na conta da Inforizz). Troca pelo de produção no
  lançamento.

E me passe só os dados **públicos**: Client ID e Public Key de teste. Eles
vão no app por `--dart-define` (`MP_CLIENT_ID`, `MP_PUBLIC_KEY`).

## 7. O que eu faço depois disso
1. Cloud Functions (TypeScript, `functions/`), testadas no emulador:
   - `oauthConnectStore`: troca o `code` pelos tokens da loja, guarda em
     `stores/{id}/private/mp` (ninguém lê pelo app) e marca `mpConnected`
   - `refreshMpTokens` (agendada): renova antes de vencer (180 dias)
   - `createCheckout`: preço e estoque calculados no servidor, Pix (QR)
     ou Checkout Pro, com `marketplace_fee` de R$ 0,99 para a Inforizz
   - `mpWebhook`: valida a assinatura, confirma o pedido ou libera o estoque
   - `expireCheckouts` (agendada): Pix vencido devolve o estoque
   - `cancelOrder`: estorno pelo MP
2. App: troca o pagamento simulado pelo real e a tela de Pix (QR +
   copia e cola).
3. Teste completo com as contas de teste: loja conecta, cliente paga Pix e
   cartão, Pix expira, estorno, taxa de R$ 0,99 aparecendo na conta da
   Inforizz.
4. Só então: credenciais de produção e uma compra real de R$ 1.

Fontes: [OAuth do Mercado Pago](https://www.mercadopago.com.br/developers/pt/docs/security/oauth/creation) ·
[Webhooks e assinatura](https://www.mercadopago.com.br/developers/pt/docs/checkout-api/additional-content/your-integrations/notifications/webhooks)
