# Arquitetura SaaS — Plataforma Inforizz de Lojas (multi-tenant)

Status: **v1 — 2026-07-17** · Documento-mestre do desenvolvimento.
Este arquivo guia TODO o desenvolvimento. Cada item do checklist deve ser
marcado quando concluído, e novas decisões devem ser registradas aqui.

---

## 1. Visão

Um **único código-base** (Flutter + Firebase) que roda **N lojas**:

- **Site (PWA)** é o canal padrão de toda loja — um deploy, todas atualizam.
- **App nativo** (Android/iOS) é benefício dos planos "APP" — hoje em
  **promoção** (mesmo preço do básico) para atrair clientes.
- Cada loja é um **tenant**: `stores/{storeId}/...` no Firestore.
- A plataforma (Inforizz) **cobra mensalidade automaticamente** dos
  admins-master e **suspende** a loja que não paga (site e app).
- Primeiras lojas: a da mãe e a da namorada do Giovanni (ambas com app,
  planos APP). A da namorada também vende via integração A2
  (ver `A2_INTEGRACAO.md`).

## 2. Decisões registradas (2026-07-17)

### 2.1 Papéis por loja
| Papel | Limite | Pode |
|---|---|---|
| **Admin-master** | até **3** | Tudo: produtos, home, pedidos, aparência, **equipe** (adicionar/remover masters e admins), **assinatura/pagamento da mensalidade** |
| **Admin** | até **5** | Adicionar/editar/remover produtos, editar a tela inicial, gerenciar pedidos. **Não** mexe em equipe nem assinatura |
| **Cliente** | ∞ | Comprar. Pertence **somente à loja onde se cadastrou** (`users/{uid}.storeId`) |

- Toda loja **nasce com 1 admin-master** — quem cria o cadastro da loja.
- ⚠️ Consequência do Firebase Auth único: **1 e-mail = 1 conta = 1 loja**.
  Se algum dia um cliente quiser comprar em duas lojas, precisará de outro
  e-mail (ou evoluímos para vínculo multi-loja — decisão futura).

### 2.2 Planos e cobrança (mock agora, Mercado Pago depois)
| Plano (id) | Nome exibido | Preço | App incluso? |
|---|---|---|---|
| `mensal_basico` | Mensal Básico | R$ 49,99/mês | Não (só site) |
| `anual_basico` | Anual Básico | R$ 499,99/ano | Não (só site) |
| `mensal_app` | Avançado Mensal (com App) | R$ 49,99/mês | **Sim — PROMOÇÃO** |
| `anual_app` | Avançado Anual (com App) | R$ 499,99/ano | **Sim — PROMOÇÃO** |

> Futuro (decidido 2026-07-17): níveis **Básico / Médio / Avançado**, todos
> com ciclos mensal e anual. Hoje "Avançado" = nível com app, em promoção
> pelo preço do Básico.

- **Trial: 60 dias grátis** a partir da criação da loja; depois começa a pagar.
- Pagamento da mensalidade: **Pix ou cartão de crédito** (pelo admin-master).
- Inadimplência: `overdue` com **carência de 5 dias** → depois `suspended`
  (site e app saem do ar automaticamente — job diário no backend, Fase 3).
- **Taxa de serviço do app: R$ 1,99 por pedido**, paga pelo cliente final no
  checkout (com ícone ℹ️ explicando que cobre custos de transação).
- IDs das lojas iniciais confirmados: **`loja_ju`** e **`loja_val`**.

### 2.3 Firebase / projetos / apps nativos
- **UM projeto Firebase (Blaze) para a plataforma inteira** — não um por loja.
  O atual é `loja-digital-ju0714`; recomendação: renomear o *display name*
  para "Inforizz Lojas" no console (o project-id não muda) e fazer upgrade
  para **Blaze**. ⚠️ *Upgrade/billing só o Giovanni pode fazer no console
  (envolve cartão) — Claude não executa ações financeiras.*
- Cada app nativo de loja = **um app Android + um app iOS registrados no
  MESMO projeto Firebase**, com ids próprios:
  `com.inforizz.loja_<nome>` (Android) / `com.inforizz.loja-<nome>` (iOS).
  Cada flavor recebe seu `google-services.json` / `GoogleService-Info.plist`.
- **Seleção da loja em dev**: `--dart-define=STORE_ID=<id>` (configs prontas
  no `.vscode/launch.json` — basta escolher no Run do VS Code).
- **Flavors** entram quando formos gerar os binários publicáveis (ícone, nome
  e applicationId por loja). Dev usa só dart-define.
- Publicação iOS: no início **Giovanni publica pela própria conta** Apple.
  ⚠️ Risco Guideline 4.3 (apps template) — mitigar publicando poucos apps,
  visuais bem distintos; migrar para a conta do cliente conforme crescer.
  ⚠️ **Nunca guardar senha da conta Apple do cliente em texto puro** no
  painel — usar gerenciador de senhas/cofre; no painel guardamos só o e-mail
  da conta e metadados. (Decisão de segurança, não negociável.)

### 2.4 Domínios e custo
- Padrão: `inforizz.com/<slug-da-loja>` — um único Firebase Hosting com a PWA;
  o app web resolve o tenant pelo slug do path. Loja nova = doc novo no banco.
- Domínio próprio (premium/futuro): CNAME do cliente → proxy (Cloud Run ou
  Cloudflare) que mapeia `Host` → `storeId`. Fase 4.
- **Custo**: Hosting cobra por GB armazenado/transferido — para dezenas de
  lojas pequenas é baixo (a PWA é uma só; imagens ficam no Storage). O custo
  real que cresce é **leitura do Firestore**; mitigação: cache local,
  paginação e (Fase 2+) cache HTTP/CDN no site. Firebase segura tranquilo o
  começo; a migração futura fica protegida pela camada de repositórios.

### 2.5 Modelo de dados (alvo)
```
stores/{storeId}
  name, slug, active, createdAt
  ownerUid, masters: [uid] (≤3), admins: [uid] (≤5)
  plan: 'mensal_basico'|'anual_basico'|'mensal_app'|'anual_app'
  subscription: {startedAt, trialEndsAt, paidUntil, lastPaymentAt, lastPaymentMethod}
  config/appearance          ← branding (nome, cores) — ThemeManager
  products/{pid}             ← catálogo e estoque
  home/{sectionId}           ← seções da tela inicial
  orders/{oid}               ← pedidos (com serviceFee, delivery e shipping)
  locations/{id}             ← lojas físicas (o antigo "stores")
  counters/ordercounter
users/{uid}
  name, email, storeId       ← cliente pertence a UMA loja
  cart/ addresses/ cards/ favorites/
a2_offers/{id}               ← outbox global do contrato A2 (tem storeId)
platform/
  superadmins/{uid}          ← Giovanni (painel-mestre)
  (futuro) plans/, invoices/
```

---

## 3. CHECKLIST-MESTRE DE DESENVOLVIMENTO

Legenda: `[x]` feito · `[ ]` a fazer · 🔒 = precisa do backend (Functions/Blaze)

### FASE 0 — Fundação multi-tenant (em andamento)
- [x] `firestore.rules` multi-tenant (papéis, loja ativa, platform) + `firebase.json`
- [x] `storage.rules` escopadas por loja (admins escrevem via cross-service rules)
- [x] Núcleo de tenant (`lib/core/tenant.dart`): `STORE_ID` via dart-define,
      refs centralizadas `stores/{storeId}/...`
- [x] Escopar por loja: produtos, home/seções, aparência, pedidos, contador,
      lojas físicas (`locations`), Storage
- [x] Papéis por loja: masters (≤3) / admins (≤5) no doc da loja;
      `UserManager` resolve papel pela loja; fim da coleção global `admins`
- [x] Cliente pertence a uma loja só (`users/{uid}.storeId`, checagem no login)
- [x] Tela Equipe (master adiciona/remove masters e admins por e-mail)
- [x] Planos + assinatura mock: catálogo, trial 60d, status
      trial/active/overdue/suspended, tela Assinatura (Pix/cartão simulados)
- [x] Configs de run por loja no `.vscode/launch.json`
- [x] Migração de dados antigos: **não haverá** — decidido (2026-07-17)
      começar com o banco limpo; recadastrar produtos nas lojas novas
- [ ] Deploy das regras: `firebase deploy --only firestore:rules,storage`
- [ ] Provisionamento formal de loja (fluxo "criar loja" com slug + master
      inicial) — hoje: bootstrap `claimStoreOwnership` no app
- [ ] Resolver tenant por slug de URL no web (hoje: só dart-define)

### FASE 1 — V1 vendável (loja completa, testada como release)
Checkout/pedido:
- [x] Taxa de serviço R$ 1,99 no carrinho/checkout com ℹ️ explicativo
- [x] Pedido grava `serviceFee` + `deliveryPrice` separados do subtotal
- [ ] Frete configurável pela loja (fixo/por região/grátis acima de X/retirada)
- [ ] 🔒 Pedido só efetiva após confirmação de pagamento (webhook) — enquanto
      mock, efetiva direto
Entrega e rastreio (tudo V1):
- [x] Bloco `shipping` no pedido (correios/motoboy/retirada, código, link)
- [x] Admin informa transportadora+código ao avançar para "Em transporte"
- [x] Cliente vê código de rastreio com copiar + botão "Rastrear" (abre
      Correios ou link do motoboy)
- [ ] 🔒 Notificação push (FCM) ao cliente na mudança de status/envio
- [ ] Integração Melhor Envio (cotação, etiqueta, tracking Correios/Jadlog)
Conta e conformidade:
- [ ] Recuperar senha (e-mail) + verificação de e-mail
- [ ] Termos de uso + Política de privacidade (LGPD; link no cadastro)
- [ ] Excluir conta (exigência das lojas Google/Apple)
Pagamento real (estrutura pronta, ligar depois):
- [ ] 🔒 Cloud Functions: `payWithPix`, `payWithCard`, `paymentWebhook`
      (split marketplace: dinheiro na conta MP da loja, taxa nossa)
- [ ] 🔒 OAuth "Conectar Mercado Pago" no admin da loja
- [ ] Trocar `FakePaymentService` → `MercadoPagoService` no main
Qualidade:
- [ ] Testes de fluxo (checkout, estoque, papéis) + `flutter analyze` limpo
- [ ] Build release Android/iOS testado como se fosse produção

### FASE 2 — Web multi-tenant + painel-mestre
- [ ] PWA em `inforizz.com/<slug>`: resolver storeId pelo path, SEO básico
- [ ] Branding 100% do banco (sem nada hardcoded por loja)
- [ ] Painel super-admin (Giovanni): listar lojas, status de pagamento,
      plano, ativar/suspender, criar loja (provisionamento)
- [ ] 🔒 Function `provisionStore` (cria doc, slug, convida master)
- [ ] Gate global de loja suspensa (site e app mostram "loja indisponível")

### FASE 3 — SaaS automático (cobrança de verdade)
- [ ] 🔒 Assinaturas Mercado Pago (preapproval) por loja: mensal/anual, Pix/cartão
- [ ] 🔒 `subscriptionWebhook` → atualiza `subscription` no doc da loja
- [ ] 🔒 Job diário (Scheduler): trial vencido/não pago + 5 dias → `active=false`
- [ ] 🔒 Reativação automática ao pagar
- [ ] Faturas em `platform/invoices` + histórico no painel-mestre
- [ ] E-mails de aviso (trial acabando, fatura, suspensão)

### FASE 4 — Premium e escala
- [ ] Flavors Android/iOS por loja-app (ícone, nome, applicationId,
      google-services por flavor) + pipeline de build
- [ ] Registrar apps das lojas no projeto Firebase (Android+iOS por loja)
- [ ] Domínio próprio do cliente (proxy Host→storeId, verificação DNS)
- [ ] Entitlements por plano no app (features premium só nos planos maiores)
- [ ] Cloud Function push `a2_offers` → A2 (ver `A2_INTEGRACAO.md`)
- [ ] Avaliar migração de partes do Firebase se custo/limites apertarem
      (protegido pela camada de repositórios)

---

## 4. Fluxos principais

### 4.1 Assinatura da loja (mock hoje / MP depois)
```
Criou a loja ──► trial (60 dias) ──► venceu? ──► overdue (5 dias de carência)
                     │ pagou (Pix/cartão)              │ não pagou
                     ▼                                 ▼
                  active (paidUntil += 1 mês/1 ano)  suspended → site/app fora
```
Status é **calculado por datas** (`trialEndsAt`, `paidUntil`) — nunca "na mão".
O job da Fase 3 só materializa `active=false`; o cálculo é o mesmo.

### 4.2 Pedido do cliente
```
Carrinho (subtotal) + Entrega + Taxa de serviço R$1,99 = Total
  └► checkout transacional: baixa estoque + contador + cria pedido
       └► admin: Em separação → [dialog: método+código de rastreio]
            → Em transporte → Entregue
       └► cliente: acompanha timeline + rastreia (Correios/motoboy)
```

## 5. Como rodar cada loja (dev)
- VS Code: Run → "Loja Ju (dev)" ou "Loja Val (dev)" (ver `.vscode/launch.json`)
- Terminal: `flutter run --dart-define=STORE_ID=loja_ju`
- Novo tenant de teste: só criar `stores/<id>` (ou logar e usar o bootstrap
  "Tornar-me dono desta loja" no Perfil em modo debug).
