# 📍 STATUS DO PROJETO — Plataforma Inforizz de Lojas

> **Leia este arquivo primeiro ao retomar o projeto.** Ele diz onde paramos,
> o que já funciona, o que falta e o que só você (Giovanni) precisa fazer.
> Detalhe técnico completo e checklist por fase: [ARQUITETURA_SAAS.md](ARQUITETURA_SAAS.md).

**Última atualização:** 2026-07-17
**Fase atual:** ✅ **FASE 0 concluída** (fundação multi-tenant) · ⏭️ próxima: **FASE 1** (V1 vendável)

---

## 🎯 Em uma frase

Um único código Flutter + Firebase que roda **N lojas** (multi-tenant). A base
para virar SaaS — papéis por loja, planos, assinatura e rastreio de entrega —
**já está montada e testada**. Ainda **não** foi publicada; pagamento é
simulado (mock) de propósito, com a estrutura pronta para o Mercado Pago real.

---

## ✅ O que já está PRONTO (Fase 0)

| Área | Situação |
|---|---|
| **Segurança (Firestore + Storage)** | Regras multi-tenant escritas do zero. Cliente só vê os próprios pedidos; equipe só administra a própria loja; loja suspensa não vende; coleções antigas bloqueadas. |
| **Multi-tenant** | Todos os dados vivem em `stores/{storeId}/...`. Trocar de loja em dev é escolher a config no VS Code (ou `--dart-define=STORE_ID`). |
| **Papéis por loja** | Até **3 admins-master** (o criador é o 1º) e **5 admins**. Tela **Equipe** (só master). Cliente pertence só à loja onde se cadastrou. |
| **Planos + Assinatura** | 4 planos, trial de 60 dias, carência de 5, suspensão automática por data. Tela **Assinatura** (só master) com pagamento **simulado** Pix/cartão. |
| **Taxa de serviço** | R$ 1,99 por pedido no checkout do cliente, com ícone ℹ️ explicando. |
| **Entrega + rastreio** | Admin informa método (Correios/motoboy/transportadora/retirada) + código ao despachar; cliente copia o código e clica em **Rastrear**. |
| **Qualidade** | `flutter analyze` limpo (só avisos herdados) e **11 testes passando** (`test/billing_test.dart`). |

### Os 4 planos (hoje)
| id | Nome | Preço | App? |
|---|---|---|---|
| `mensal_basico` | Mensal Básico | R$ 49,99/mês | site |
| `anual_basico` | Anual Básico | R$ 499,99/ano | site |
| `mensal_app` | Avançado Mensal (com App) | R$ 49,99/mês | **App — PROMO** |
| `anual_app` | Avançado Anual (com App) | R$ 499,99/ano | **App — PROMO** |

> Futuro: níveis **Básico / Médio / Avançado**, cada um com mensal e anual.

---

## 🔴 O que SÓ VOCÊ pode fazer (fora do código)

Estes passos destravam a próxima fase e envolvem console/cobrança — eu não executo:

1. **Ativar o plano Blaze** no console do Firebase (projeto `loja-digital-ju0714`;
   pode renomear o *display name* para "Inforizz Lojas"). Necessário para as
   Cloud Functions e o job de suspensão. *(Envolve cartão → só você.)*
2. **Publicar as regras** depois de criar as lojas de teste:
   ```bash
   firebase deploy --only firestore:rules,storage
   ```
3. **Criar as duas primeiras lojas** (`loja_ju`, `loja_val`): logar com uma conta
   e usar o bootstrap "tornar-me admin-master" (login de teste) — isso cria o
   doc `stores/{id}` com trial de 60 dias. *(Decidido: banco começa limpo, sem
   migração dos dados antigos.)*
4. **Segurança:** senha de conta Apple de cliente **nunca** em texto puro no
   painel — guardar em gerenciador de senhas; no painel, só e-mail/metadados.

---

## ⏭️ PRÓXIMOS PASSOS (Fase 1 — V1 vendável)

Ordem sugerida (detalhes e checklist completo em [ARQUITETURA_SAAS.md](ARQUITETURA_SAAS.md) §3):

1. **Frete configurável por loja** (fixo / por região / grátis acima de X / retirada).
2. **Conta e conformidade:** recuperar senha, verificar e-mail, excluir conta,
   Termos de Uso + Política de Privacidade (LGPD — exigidos pelas lojas).
3. **Backend (precisa do Blaze):** Cloud Functions do Mercado Pago —
   `payWithPix`, `payWithCard`, `paymentWebhook` (com split marketplace) e
   notificação push (FCM) na mudança de status do pedido.
4. **Ligar o pagamento real:** trocar `FakePaymentService` → `MercadoPagoService`.
5. **Build release** Android/iOS testado como produção antes de publicar.

> Combinado: **V1.5 entra na V1** — frete/rastreio real (Melhor Envio) e as
> melhorias de entrega fazem parte da primeira versão publicada.

---

## 🧭 Como rodar e testar agora

```bash
# Loja Ju (padrão) — ou escolha "Loja Ju/Val (dev)" no Run do VS Code
flutter run --dart-define=STORE_ID=loja_ju

# Testes da regra de negócio (planos, assinatura, rastreio)
flutter test
```

Fluxo para experimentar: logar como conta de teste → bootstrap admin-master →
Perfil mostra **Equipe** e **Assinatura** → cadastrar produto → comprar como
cliente (taxa R$1,99 aparece) → no painel de Pedidos, despachar e informar o
código de rastreio.

---

## 🗂️ Mapa dos arquivos-chave (o que olhar)

| Quero entender... | Arquivo |
|---|---|
| Visão, decisões e **checklist por fase** | [docs/ARQUITETURA_SAAS.md](ARQUITETURA_SAAS.md) |
| Pagamentos / Mercado Pago | [docs/PAGAMENTOS.md](PAGAMENTOS.md) |
| Integração com o app A2 | [docs/A2_INTEGRACAO.md](A2_INTEGRACAO.md) |
| Escopo por loja (coração do multi-tenant) | `lib/core/tenant.dart` |
| Regras de segurança | `firestore.rules` · `storage.rules` |
| A conta da loja (equipe, plano, ativa) | `lib/models/store_account.dart` · `lib/models/tenant_manager.dart` |
| Planos e assinatura | `lib/models/plan.dart` · `lib/models/subscription.dart` |
| Papéis (master/admin/cliente) | `lib/models/user_manager.dart` |
| Telas novas | `lib/screens/subscription/` · `lib/screens/team/` |
| Entrega/rastreio | `lib/models/order.dart` · `lib/screens/orders/components/order_tile.dart` |

---

## 🔒 Decisões travadas (resumo)

- **Canais:** web-first (site é o padrão de toda loja); **app nativo só nos
  planos APP** (hoje em promoção). Um app publicado por vez.
- **Firebase:** um único projeto Blaze para a plataforma inteira; apps nativos
  de lojas entram como apps adicionais no mesmo projeto (`com.inforizz.loja_x`).
- **Apps das lojas:** publicados inicialmente na conta do Giovanni; migrar para
  a conta do cliente conforme cresce (atenção à Guideline 4.3 da Apple).
- **Lojas iniciais:** `loja_ju` (mãe, produtos na mão) e `loja_val` (namorada,
  na mão + integração A2).
- **Pagamento:** mock agora, estrutura pronta para Mercado Pago (Pix/cartão) no
  checkout do cliente **e** na assinatura das lojas.
