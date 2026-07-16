# Pagamentos — estratégia e configuração

Status: v1 — 2026-07-16

## Resumo das suas perguntas

### 1. Dá para usar In-App Purchase do Google (Play Billing)?
**Não para os produtos da loja.** A política do Google Play **proíbe** usar o
Play Billing para vender **bens físicos** (roupas, tênis, anéis...) e serviços
do mundo real. O Play Billing é **só** para conteúdo/serviços **digitais**
consumidos dentro do app (ex.: assinatura premium, moedas de jogo).

➡️ Para vender produtos físicos, o Google **exige** um gateway externo — que é
exatamente o **Mercado Pago (Pix/cartão)**. Ou seja, o caminho certo já é o que
estamos montando. (IAP poderia entrar no futuro só se você vender algo digital,
tipo um "plano premium da loja".)

### 2. Como o cliente paga a loja, com transação direta e eu recebendo minha taxa?
Isso é um **marketplace / split de pagamentos**, e o Mercado Pago suporta
nativamente:

- Cada loja (Ju, Val...) **conecta a própria conta Mercado Pago** ao seu app
  via **OAuth** (uma vez). Você guarda o `access_token`/`user_id` da loja.
- Quando o cliente paga, o dinheiro cai **direto na conta da loja**, e o app
  **retém automaticamente uma taxa** (`application_fee`) — essa é a sua receita
  pelo serviço/transação.
- Você **não** fica com o dinheiro do produto (evita responsabilidade fiscal e
  de repasse); só recebe a taxa. É o modelo "Mercado Pago Marketplace".

```
Cliente paga R$ 100
   │
   ▼ (split automático do Mercado Pago)
Loja recebe R$ 95  ───────────►  conta MP da loja
App (você) recebe R$ 5 (taxa) ─►  sua conta MP
```

A taxa é configurável em `MercadoPagoConfig.marketplaceFeePercent`
(`--dart-define=MP_MARKETPLACE_FEE=5` = 5%).

### 3. Pix via Mercado Pago
Já deixei pré-configurado: `PaymentService.payWithPix(...)` retorna QR +
copia-e-cola. Falta só implementar o `MercadoPagoService` (backend) e ligar.

## Por que precisa de um backend (Cloud Functions)
O **Access Token** do Mercado Pago **nunca** pode ficar no app (qualquer um
descompila e rouba, podendo movimentar sua conta). Então:

- **App**: tokeniza cartão (dado sensível não passa pelo nosso banco), mostra
  Pix/checkout, e chama o backend.
- **Backend (Cloud Functions)**: guarda os tokens das lojas, cria a cobrança no
  MP com o split (`application_fee`), e recebe o **webhook** de confirmação.

## O que já está pronto no app
- `PaymentService` (abstração) com `FakePaymentService` (funciona ponta a ponta
  hoje) e `MercadoPagoService` (esqueleto).
- Métodos `payWithCard` / `payWithPix` já recebem `sellerId` (loja) e
  `feeAmount` (taxa) para o split.
- Config por `--dart-define`: `MP_PUBLIC_KEY`, `MP_BACKEND_URL`,
  `MP_MARKETPLACE_FEE`.
- Cartão salvo guarda só bandeira + últimos 4 (número real é tokenizado).

## Passos para entrar no ar (quando você quiser)
1. Criar conta Mercado Pago e um **aplicativo Marketplace** (pega client_id/
   client_secret + Public Key + Access Token).
2. **Cloud Functions** (Firebase Blaze): `oauthConnectStore` (conecta a conta MP
   de cada loja), `payWithPix`, `payWithCard` (com `application_fee`) e
   `webhook` (confirma pagamento → efetiva o pedido).
3. **App**: tela "Conectar Mercado Pago" no admin da loja (abre o OAuth); trocar
   `FakePaymentService` por `MercadoPagoService` no `main.dart`.
4. Testar com credenciais **sandbox** do MP antes de produção.

> Observação: enquanto o backend não existe, o app segue com pagamento
> **simulado** (o pedido é criado e o estoque baixa), sem cobrança real.
