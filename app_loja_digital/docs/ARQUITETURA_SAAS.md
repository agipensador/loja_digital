# Arquitetura SaaS — Plataforma Inforizz de Lojas (multi-tenant)

Status: **v1.1 — 2026-09-30** · Documento-mestre do desenvolvimento.
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

## 2. Decisões registradas (2026-07-17, atualizado 2026-09-30)

### 2.0 Entrega (decidido 2026-09-30)
- **Pagamento confirmado:** modelo **Mercado Pago Marketplace com split
  automático** (não a alternativa de "app só cobra mensalidade e loja
  recebe por fora") — mesmo custando mais tempo de desenvolvimento, porque
  dá rastreabilidade completa de cada pedido e habilita o relatório
  financeiro do admin.
- **Motoboy:** deep-link simples para o app/site do Uber (sem API paga,
  sem Uber Direct por agora) — origem é a loja, destino é o endereço do
  pedido.
- **Entrega própria por zona:** feature nova — o lojista cadastra quais
  bairros atende em quais dias da semana (`DeliveryZone`); o checkout
  sugere a próxima data disponível pelo bairro do cliente, que pode trocar
  entre as datas futuras daquela zona. Coexiste com o deep-link do Uber e
  com o frete por CEP (transportadora/Correios) já existente.
- **WhatsApp/distribuidor** (pedido automático a distribuidor quando o
  estoque de um modelo fica baixo, puxando `Product.lowStockThreshold`/
  `isLowStock`) fica para uma fase **futura**, fora da V1.

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
  Atualizado em 2026-10-08: **`loja_gi`** substitui a `loja_val`.

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
· ❓ = decisão pendente do Giovanni

### CHECKLIST CONSOLIDADO (2026-10-01) — tudo o que foi pedido no chat
Ver também: [MERCADO_E_PRECOS.md](MERCADO_E_PRECOS.md) e
[CUSTOS_E_PRECOS.md](CUSTOS_E_PRECOS.md).

**Conta e equipe**
- [x] Login, cadastro com aceite de termos, recuperar senha, verificar e-mail
- [x] Excluir conta (cliente/funcionário); dono pede "Encerrar loja"
- [x] Papéis: Administrador (dono + sócios), Gerente, Funcionário com toggles
- [x] Funcionário vinculado a unidades; não mexe no dono (rules testadas)

**Multi-lojas, estoque e catálogo**
- [x] Unidade física com endereço por CEP; estoque por unidade
- [x] Vitrine "disponível em X", produtos da unidade do cliente primeiro
- [x] Alerta de estoque baixo por unidade + reposição pelo WhatsApp
- [x] Importação de catálogo CSV (Shopify/Nuvemshop/modelo do app)
- [x] Foto por link (ex.: Shopee), sem ocupar armazenamento
- [x] Peso e medidas do produto (base para frete dos Correios)

**Entrega**
- [x] Retirada, área de entrega própria (cidade/bairro, dias, valor fixo),
      motoboy (Uber) e Correios por unidade
- [x] Uber estimado pela distância (BrasilAPI, saída + R$/km); fixo de reserva
- [x] Loja define a data final; propõe outra entrega; cliente aceita/recusa;
      ajuste (devolver/cobrar) registrado e somado
- [ ] 🔒 Correios real: Cloud Function `quoteShipping` com Melhor Envio
      (token na Function; usar peso/medidas; padrão da loja se faltar)
- [ ] Uber Direct (API): **desenvolver quando a 1ª loja chegar a 700
      clientes** (conta empresarial Uber + Function `quoteUber`/`requestUber`;
      até lá, estimativa por distância + deep link)
- [ ] 🔒 Devolução automática da diferença (estorno parcial MP cartão/Pix)

**Formato brasileiro**
- [x] R$ 1.234,56 em todo o app; preço aceita vírgula
- [x] Máscara de CEP e telefone; CPF com máscara e validação (helper pronto)
- [x] Endereço começa pelo CEP (busca e preenche, número obrigatório ou
      "Endereço sem número")
- [ ] CPF do comprador no checkout (o MP pede para Pix/antifraude) — Fase B
      (⚠ nunca usar CPF de teste como padrão — lição do app Chaveiro)

**Imagens, cache e custo**
- [x] Compressão no aparelho (1600 px) + miniatura 480 px + cache de 1 ano
- [x] Cache de imagens no celular (cached_network_image)
- [x] Catálogo incremental por `updatedAt` a partir do cache do Firestore
- [ ] Gerar miniaturas das fotos antigas (antes da compressão) — script único

**Planos, uso e cobrança**
- [x] (2026-10-04) Loja única **29,90** · Multilojas (2) **59,90** ·
      Plus (3–5) **119,90**, preço fixo · máx. 5 lojas · **3 meses grátis**
- [x] Pagamento mensal / 6 meses (-10%) / 12 meses (-15%)
- [x] Taxa R$ 0,99 em **todos** os pedidos pagos (loja absorve; toggle
      repassa ao cliente)
- [x] Trocar de plano dentro do app (tela Assinatura)
- [x] "Quero este plano" abre o WhatsApp da Inforizz com plano, período e
      loja escritos (enquanto o pagamento pelo app não existe)
- [x] Medidor de uso (visitas, produtos, GB) + cobrança extra R$ 5/bloco,
      teto R$ 50, bloqueio de novos produtos no teto
- [x] Termos para Lojistas: planos, taxa, extra, teto, avisos, suspensão,
      **código e software são da Inforizz**, publicação dos apps
- [x] Tela "OPS! O APP X ESTÁ FORA DO AR" para clientes; equipe entra p/ pagar
- [x] Infográfico de uso: 2 GB ≈ 7 mil fotos, por que é leve
- [ ] 🔒 Fim do período grátis → 1ª cobrança por Pix (QR no app); depois
      oferecer Pix Automático/cartão recorrente
- [ ] 🔒 Cobrança real da mensalidade pelo Mercado Pago + webhook
- [ ] 🔒 `subscription` e `active` só pelo backend (hoje o dono ainda
      consegue gravar esses campos pela API: fechar junto com o MP)
- [ ] 🔒 Somar a cobrança extra do mês na mensalidade seguinte
- [ ] 🔒 Job diário: suspender após carência; reativar ao pagar
- [ ] 🔒 Avisos: 10 dias antes (app/e-mail) e WhatsApp nos 3 últimos dias
- [ ] Planos estratégicos (em breve): preço de fundador, anual em destaque,
      implantação assistida, indique e ganhe, vitrine grátis, pacote de avisos

**Flavors, ícone, splash e publicação**
- [x] Gradle cria um flavor por pasta `flavors/<id>/` automaticamente
- [x] `tool/new_flavor.sh`: config, apps Android/iOS no Firebase, site de
      hosting, loja no Firestore, **`--logo` vira o ícone** (Android, iOS,
      web) e `--color` o fundo do ícone
- [x] `tool/build_web_flavor.sh <id> [--base-href /slug/]`: ícones/nome da
      loja na web + build
- [x] `tool/delete_flavor.sh` com confirmação dupla
- [x] Splash nativa igual para todas as lojas: branca com "development by
      inforizz" pequeno embaixo (Android, Android 12+, iOS, web)
- [ ] iOS: scheme/xcconfig por flavor no Xcode (precisa de Mac)
- [ ] Testar `new_flavor.sh` de verdade (⚠ `firebase login --reauth` na
      conta contato@inforizz.com antes)
- [ ] Conta Google Play de **organização** (CNPJ + D-U-N-S): conta pessoal
      nova exige teste fechado com 12 testadores por 14 dias para cada app
- [ ] iPhone: cada loja publica na **própria conta Apple** (regra 4.2.6),
      com a Inforizz como membro da equipe; custo US$ 99/ano é da loja
- [ ] Automatizar builds (GitHub Actions/Codemagic + fastlane) disparados
      pelo painel

**Domínios**
- [x] Grátis: `<projeto>-<id>.web.app` (criado pelo new_flavor.sh)
- [ ] Padrão sugerido: subdomínio `<loja>.inforizz.com` (CNAME no DNS da
      inforizz.com + domínio personalizado no Hosting, HTTPS automático)
- [ ] Domínio da loja (`lojadaju.com.br`): a loja registra no registro.br
      (~R$ 40/ano); conectamos no Hosting (registros TXT + A)
- [ ] `inforizz.com/<loja>`: possível com `--base-href`, mas o site
      inforizz.com está em outro projeto (app-do-chaveiro); exige proxy ou
      mover o site. Melhor redirecionar para o subdomínio
- [ ] Resolver a loja pela URL num build web único (tenant por slug), para
      lojas novas entrarem no ar sem build próprio

**Painel-mestre da plataforma (web admin)**
- [x] Entrada separada `lib/admin/main_admin.dart`; só entra quem tem
      `platform/superadmins/items/{uid}`
- [x] Indicadores: lojas, grátis, pagantes, atraso, suspensas, desativadas,
      receita mensal
- [x] Tabela de lojas: plano, situação, vencimento, visitas, produtos;
      trocar plano, +30 dias grátis, registrar pagamento (+1 mês),
      desativar/reativar
- [x] **Nova loja** pelo painel (3 meses grátis, dono assume pelo e-mail)
- [x] **Produtos de cada loja**: buscar, editar nome/preço/estoque por
      unidade, ocultar/mostrar
- [x] **Usuários**: buscar por e-mail, ver loja, bloquear/desbloquear
      (bloqueado não entra no app; rules impedem desbloqueio próprio)
- [x] Pedidos de encerramento: "Recuperada" ou "Encerrar"
- [x] Avisos da plataforma para todos os lojistas
- [ ] Gráficos (visitas/pedidos por mês, receita), faturas, exportar CSV
- [ ] Hospedar em site separado (`admin.inforizz.com`)

**Notificações**
- [x] Loja → clientes: "Enviar aviso" com cota por plano (8 / 20 / 60)
- [x] Plataforma → lojistas: aba "Da plataforma"
- [x] Sugestão automática "Deseja notificar?" (Sim envia / Editar / Não):
      produto novo, produtos importados, produto de volta ao estoque, nova
      unidade, nova área de entrega, **app atualizado** (1 vez por versão,
      `--dart-define=APP_VERSION`)
- [ ] 🔒 Push de verdade: Function `onCampaignCreated` → FCM por tópico
      `store_<id>` + `firebase_messaging` no app (hoje o aviso aparece só
      dentro do app)
- [ ] Mais gatilhos: promoção/preço baixou, pedido parado há X dias (para a
      equipe), estoque baixo (para a equipe), fim do período grátis

**Atendimento (chat)**
- [x] Menu inicial com as 5 perguntas mais feitas (bloco que abre/fecha),
      ordenado pelos cliques da própria loja
- [x] Botão "Perguntas" com todos os assuntos por categoria
- [x] ~40 tópicos: cliente (pedido, entrega, prazos, pagamento,
      parcelamento, Pix expirado, troca/7 dias, cancelamento, esgotado,
      tamanho, nota fiscal, cupom, atraso, conta, dados), equipe (cadastrar,
      importar, estoque, pedidos, receber vendas, equipe, cores/logo, plano,
      avisos, suporte) e "quero minha loja" (só no app da Inforizz)
- [x] Dúvida específica (nº de pedido, quebrado, cobrança, reclamação,
      "falar com"...) → WhatsApp com a pergunta já escrita
- [x] WhatsApp: loja (se cadastrou celular) ou Inforizz (11) 96706-4898;
      equipe sempre fala com a Inforizz
- [x] "Montar minha loja": plano, nome, cidade, paleta de cores (ou
      código), o que já tem → WhatsApp da Inforizz pronto; lá a pessoa manda
      logo e planilha
- [ ] Respostas rápidas e mensagem de boas-vindas no WhatsApp Business da
      Inforizz (configurar no celular)
- [ ] v2 com IA (Function + modelo de linguagem, só o contexto da loja)

**Cadastro de produtos e inclusão**
- [x] Manual, câmera/galeria, foto por link
- [x] Importar de uma vez: **Excel (.xlsx)**, CSV, **JSON** (inclusive
      products.json da Shopify), **link do Google Planilhas**, texto colado
- [ ] Várias fotos de uma vez (`pickMultiImage`)
- [ ] Acessibilidade: Semantics nos botões só com ícone, contraste AA,
      fonte até 200%, alvos de 48 px, sem depender só de cor

**Idiomas (i18n)**
- [x] Estrutura pronta (pt + en); textos ainda em pt-BR
- [ ] Migrar textos para os .arb quando houver região paga

**Firebase Extensions (encerramento em 31/03/2027)**
- Este app não usa nenhuma extensão (compressão e miniaturas no aparelho).
- [ ] `firebase login --reauth` e rodar `firebase ext:list` em
      jesus-ai-45549, app-do-chaveiro, app-do-chaveiro-dev, popex-site,
      millionaire-wallpaper-6646d

### ✅ CHECKLIST DA 1ª VERSÃO PUBLICÁVEL (v1)

**A. Loja da própria Inforizz (venda dos planos)**
- [x] Tela "Montar minha loja" → WhatsApp da Inforizz
- [x] Chat com as perguntas de quem quer ter uma loja
- [ ] Flavor `inforizz` (STORE_ID `inforizz`) com os planos na vitrine;
      Jesus.ai e Chaveiro só como exemplos do que a Inforizz faz
- [ ] Fluxo de implantação: WhatsApp → painel "Nova loja" → new_flavor.sh
      (logo + cores) → web no ar → Android → iPhone (conta da loja)
- [ ] 🔒 Depois: comprar no app → webhook MP → loja criada sozinha

**B. Bloqueadores técnicos**
- [ ] 🔒 Plano Blaze + Functions: `createCheckout`, `mpWebhook`,
      `expireCheckouts`, `oauthConnectStore`, `cancelOrder` (estorno)
- [ ] 🔒 Checkout no backend (fecha a brecha de `sizes` nas rules)
- [ ] 🔒 Assinatura: 1ª cobrança Pix pós-trial, renovação, suspensão
- [ ] 🔒 Push FCM
- [ ] Deploy das rules/storage + índices compostos
- [ ] Testes no sandbox MP + compra real de R$ 1

**C. Lojas e publicação**
- [ ] Contas: Google Play (organização), Apple, MP Developers, MP de cada loja
- [ ] Rodar `new_flavor.sh` para a 1ª loja
- [ ] Prints e descrição nas lojas
- [ ] Política de privacidade e termos em URL pública
- [ ] Build release Android, teste interno
- [ ] iOS: schemes (Mac), TestFlight

**D. Operação**
- [ ] Painel hospedado + seu usuário em `platform/superadmins`
- [ ] Crashlytics + Analytics com `storeId`
- [ ] Backup do Firestore
- [ ] Alerta de orçamento no Google Cloud
- [ ] Revisar custos com a fatura real dos 2 primeiros meses

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
- [x] Entrega própria por zona/dia da semana configurável pela loja
      (`DeliveryZone`: bairros + dias; checkout sugere e permite troca de
      data) — complementa o frete por CEP existente, não substitui
- [ ] 🔒 Pedido só efetiva após confirmação de pagamento (webhook) — enquanto
      mock, efetiva direto
Entrega e rastreio (tudo V1):
- [x] Bloco `shipping` no pedido (correios/motoboy/retirada, código, link)
- [x] Admin informa transportadora+código ao avançar para "Em transporte"
- [x] Cliente vê código de rastreio com copiar + botão "Rastrear" (abre
      Correios ou link do motoboy)
- [x] Deep-link Uber (sem API paga) para motoboy: botão "Abrir Uber" com
      origem (loja) e destino (cliente) preenchidos
- [ ] 🔒 Notificação push (FCM) ao cliente na mudança de status/envio
- [ ] Integração Melhor Envio (cotação, etiqueta, tracking Correios/Jadlog)
Conta e conformidade:
- [x] Recuperar senha (e-mail) + verificação de e-mail
- [x] Termos de uso + Política de privacidade (LGPD; aceite no cadastro)
- [x] Excluir conta (exigência das lojas Google/Apple)
Relatório financeiro:
- [x] Relatório mensal do admin (receita, nº de pedidos, navegação entre
      meses) — cálculo on-the-fly em `OrdersManager`, sem Cloud Function
Pagamento real (estrutura pronta, ligar depois):
- [ ] 🔒 Cloud Functions: `oauthConnectStore`, `payWithPix`, `payWithCard`,
      `paymentWebhook` (split marketplace: dinheiro na conta MP da loja,
      taxa nossa) — bloqueado até o Giovanni ativar o plano Blaze
- [x] Tela "Conectar Mercado Pago" no admin da loja (UI pronta; só lê
      `mpConnected`, nunca o token — ainda sem Cloud Function por trás)
- [x] `MercadoPagoService` com a camada HTTP completa (chama o backend);
      falta só trocar `FakePaymentService` → `MercadoPagoService` no main
      quando o backend existir
Qualidade:
- [x] Testes de fluxo (billing, `OrderShipping`, `DeliveryZone`) +
      `flutter analyze` limpo (15/15 testes passando em 2026-09-30)
- [ ] Build release Android/iOS testado como se fosse produção

### FASE 2 — Web multi-tenant + painel-mestre
- [ ] PWA em `inforizz.com/<slug>`: resolver storeId pelo path, SEO básico
- [ ] Branding 100% do banco (sem nada hardcoded por loja)
- [x] Painel super-admin (Giovanni) v0: listar lojas, status, plano,
      ativar/suspender, encerramentos, avisos (ver "Painel-mestre" acima)
- [ ] Painel: criar loja (provisionamento), editar produtos, usuários
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
- VS Code: Run → "Loja Ju (dev)" ou "Loja Gi (dev)" (ver `.vscode/launch.json`)
- Terminal: `flutter run --dart-define=STORE_ID=loja_ju`
- Novo tenant de teste: só criar `stores/<id>` (ou logar e usar o bootstrap
  "Tornar-me dono desta loja" no Perfil em modo debug).
