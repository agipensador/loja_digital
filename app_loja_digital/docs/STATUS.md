# 📍 STATUS DO PROJETO — Plataforma Inforizz de Lojas

> **Leia este arquivo primeiro ao retomar o projeto.** Ele diz onde paramos,
> o que já funciona, o que falta e o que só você (Giovanni) precisa fazer.
> Detalhe técnico completo e checklist por fase: [ARQUITETURA_SAAS.md](ARQUITETURA_SAAS.md).

**Última atualização:** 2026-10-08
**Fase atual:** ✅ Fase A (fundação, multi-lojas, equipe, entrega) · ✅ painel-mestre v0, avisos, atendimento v1 · ⏭️ próxima: Blaze + Mercado Pago (Fase B) e a loja-exemplo Inforizz
**Checklist da 1ª versão publicável:** ARQUITETURA_SAAS.md → "CHECKLIST DA 1ª VERSÃO PUBLICÁVEL (v1)".

### Rodada 2026-10-08 — Blaze, regras publicadas, lojas loja_ju e loja_gi
- **Blaze confirmado** (faturamento ativo no `loja-digital-ju0714`).
  Nenhum projeto da Inforizz usa Firebase Extensions.
- **Causa do permission-denied:** as regras no ar eram as do modo de teste,
  vencidas em 13/08/2026. **Regras novas publicadas** (Firestore e Storage).
- **Segurança:** a loja só passa para o dono com **e-mail confirmado**
  (antes, quem criasse a conta primeiro com o e-mail do dono assumia);
  lojas só nascem pelo painel ou pelo script (ninguém cria loja sozinho
  pela API). Testado no emulador e publicado.
- **Lojas criadas no ar** (3 meses grátis, até 06/01/2027):
  `loja_ju` → dona gbrrizzardo@gmail.com · `loja_gi` (substitui a
  loja_val) → dono contato@inforizz.com. launch.json atualizado.
- E-mails do Firebase (confirmar e-mail, trocar senha) em português.
- Backup dos dados antigos: `backups/firestore_legacy_2026-10-08.json`
  (30 docs, fora do git).
- Mercado Pago: passo a passo em `docs/MERCADO_PAGO_SETUP.md`.
- **Pendente seu:**
  - [ ] Permissão do Storage ler o Firestore (sem ela, upload de foto é
        negado): `firebase deploy --only storage --project loja-digital-ju0714`
        no seu terminal e responder **Y** quando perguntar.
  - [ ] Apagar os dados antigos do ar (comandos no fim desta seção).
  - [ ] Criar as contas nos apps, confirmar o e-mail e tocar em "Já
        confirmei" no Perfil (vira dono).
  - [ ] Criar a aplicação no Mercado Pago (MERCADO_PAGO_SETUP.md).
- Comandos para apagar os dados antigos (backup já feito):
  ```
  for p in a2_offers admins aux config home orders products stores/0KLF6JDd3A8bXT3Og6gw stores/XRMKV9ubObDu4ddoXCrJ users/JiCin4L5oTPl8YhqDUK96Fh1ulC3 users/tghP1HY77ZSrHU9bVdqfll7HDxG3; do firebase firestore:delete "$p" -r --project loja-digital-ju0714; done
  ```
  Contas de teste (admin@, cliente@, seed_probe@lojadigital.com): apagar no
  console, em Authentication → Usuários.

### Rodada 2026-10-07 — chat: consulta de pedido, menu em acordeão, WhatsApp por unidade
- **Consulta de pedido:** "em que pé está o pedido 123?", "cadê o #000124",
  "pedido nº 123" → situação, data, total, entrega, data confirmada,
  rastreio e o que fazer em cada situação. Sem número ("status do meu
  pedido") lista os 3 últimos. Usa a lista que o `OrdersManager` já
  carregou: cliente só acha os próprios pedidos; equipe acha os da loja.
  Sem login, pede para entrar. (`Chatbot.orderAnswer`)
- **Menu das mais tocadas em acordeão:** a resposta abre no próprio item,
  só um aberto por vez, e conta o toque. "Ver todos os assuntos" continua
  mandando a pergunta para a conversa.
- **WhatsApp por unidade (cliente):** vai para a unidade que atende
  (`StoresManager.currentLocationId`); se ela não tem número, para a que
  tem; nenhuma com número → "No momento o WhatsApp da loja não está
  disponível" (antes caía na Inforizz). Equipe e "quero minha loja"
  continuam na Inforizz. Com várias outras com número, escolhe a 1ª.
- **Decidido:** por ora o chat fica só com regras (sem IA). Plano com IA
  (OpenAI, a mesma do Nubank), custos e fluxos com e sem IA no documento
  compartilhado "Chat de atendimento — como funciona":
  https://claude.ai/code/artifact/7999f2d2-01eb-49e4-ba7f-201e9f4b465c
- 66 testes passando (9 novos de chat), analyze sem erros nos arquivos do chat.
- **Testado no Moto E20 (APK release):** abre, mas **toda leitura do
  Firestore dá `permission-denied`** (catálogo, loja `loja_ju`, unidades,
  aparência). Causa provável: o `firestore.rules` multi-loja local nunca foi
  publicado no `loja-digital-ju0714`. Sem isso o chat abre sem nome da loja,
  entregas, unidades e pedidos.
- **Pendente seu para gerar a versão:**
  - [ ] `firebase login --reauth` (sessão do Firebase CLI expirada)
  - [ ] autorizar publicar as regras (comparar com as do ar antes)
  - [ ] criar conta + pedido de teste para validar a consulta de pedido
  - [ ] commitar: nada desta rodada nem das de 04/10 está no git

### Rodada 2026-10-04 (noite) — chat, "quero minha loja", painel completo, importação, splash
- **Regras novas:** 3 meses grátis; taxa R$ 0,99 em **todos** os pedidos;
  todas as lojas pagam o valor normal; termos dizem que o código é da
  Inforizz (cláusula 9) e como os apps são publicados (cláusula 10).
- **Chat:** menu inicial com as 5 perguntas mais feitas, botão com todos os
  assuntos (~40 tópicos), dúvida específica vai para o WhatsApp com a
  pergunta escrita. WhatsApp da Inforizz: (11) 96706-4898
  (`lib/core/platform_contact.dart`).
- **"Montar minha loja"** (`/start_store`): plano, cores (paleta ou
  código), o que já tem → WhatsApp da Inforizz pronto. Na Assinatura,
  "Quero este plano" também vai para o WhatsApp.
- **Notificações sugeridas:** produto novo/importado, volta ao estoque,
  nova unidade, nova área de entrega, app atualizado → "Deseja notificar?".
- **Importação:** Excel .xlsx, CSV, JSON, link do Google Planilhas, colar.
- **Painel-mestre:** Nova loja, produtos de cada loja (editar/ocultar),
  usuários (bloquear), registrar pagamento. Testado no navegador.
- **Splash** branca com "development by inforizz"; **ícone por loja** com
  `new_flavor.sh --logo`; `tool/build_web_flavor.sh`.
- 57 testes passando, analyze sem erros, rules testadas (bloqueio,
  criação de loja, versão anunciada).
- Pendente seu: `firebase login --reauth` (sessão expirada) e confirmar o
  e-mail de contato (usei mail.inforizz@gmail.com).

### Rodada 2026-10-04 — preços, painel-mestre, avisos, atendimento, i18n
- **Preços novos (fixos):** Loja única R$ 29,90 · Multilojas R$ 59,90 ·
  Plus R$ 119,90; (atualizado na rodada seguinte: 3 meses grátis, taxa em todo pedido) taxa R$ 0,99 só depois de R$ 50
  vendidos no mês. Estratégia custo ≈ 1/4–1/3 e planos estratégicos em
  MERCADO_E_PRECOS.md. Termos para Lojistas atualizados.
- **Painel-mestre (web):** `lib/admin/main_admin.dart` + `admin_dashboard.dart`
  — indicadores, tabela de lojas (plano/situação/visitas/produtos), trocar
  plano, +30 dias grátis, desativar/reativar, encerramentos, avisos da
  plataforma. Rodar: `flutter run -d chrome -t lib/admin/main_admin.dart`.
  Acesso: criar o doc `platform/superadmins/items/<seu uid>` no console.
- **Notificações:** loja envia avisos aos clientes com cota por plano
  (8/20/60 por mês); caixa "Notificações" com aba "Da plataforma" para a
  equipe. Push real (FCM) fica para a Fase B.
- **Atendimento (robô v1):** menu com as perguntas mais tocadas,
  respostas com as configs da loja, botão WhatsApp; só fala da própria
  loja. Para a equipe, explica como usar o sistema.
- **i18n:** estrutura gen-l10n pronta (pt + en), textos ainda em pt-BR.
- **Infográfico de uso:** 2 GB ≈ 7 mil fotos e por que o app é leve.
- **Firebase Extensions** encerram em 31/03/2027; este app não usa
  nenhuma (ver ARQUITETURA_SAAS.md).
- Uber Direct: desenvolver quando a 1ª loja chegar a 700 clientes.
- `flutter analyze` sem erros (só avisos antigos de `Radio`), 42 testes
  passando, rules compiladas no emulador.

### Sessão 2026-09-30
- **Conta:** recuperação de senha, verificação de e-mail (banner + reenvio),
  exclusão de conta, Termos de Uso + Política de Privacidade (com aceite
  obrigatório no cadastro) — tudo em `lib/screens/legal/`,
  `lib/models/user_manager.dart`, `lib/screens/profile/profile_screen.dart`.
- **Entrega própria por zona/dia:** novo modelo `DeliveryZone`
  (`lib/models/delivery_zone.dart`) — admin cadastra bairros + dias da
  semana em **Perfil → Zonas de entrega**; checkout sugere a próxima data
  disponível pelo bairro do cliente, com opção de troca.
- **Motoboy via Uber:** botão "Abrir Uber" no pedido (quando método =
  motoboy) monta um deep-link com origem (loja) e destino (cliente)
  preenchidos — sem API paga (`lib/helpers/uber_link_helper.dart`).
- **Relatório financeiro mensal:** **Perfil → Relatório financeiro** —
  receita e nº de pedidos por mês, navegável entre meses, tabela por dia
  (`lib/screens/reports/`, cálculo on-the-fly em `OrdersManager`).
- **Mercado Pago:** tela "Conectar Mercado Pago" (OAuth, só mostra status)
  em `lib/screens/mp_connect/`; `MercadoPagoService` completo do lado HTTP
  (chama `payWithCard`/`payWithPix` do backend) — **ainda não ativado**
  (`FakePaymentService` continua em uso em `main.dart`) porque as Cloud
  Functions (`oauthConnectStore`, `payWithPix`, `payWithCard`,
  `paymentWebhook`) dependem do upgrade para o plano **Blaze**, que só o
  Giovanni pode fazer (envolve cartão).
- `firestore.rules` atualizado com a nova subcoleção `deliveryZones`
  (ainda pendente de deploy, ver abaixo).
- `flutter analyze` limpo e `flutter test` com 15/15 testes passando
  (12 antigos + 3 novos de `DeliveryZone`).

### Rodada 2026-10-01 (noite) — formato BR, CEP, imagens, uso, importação, flavors
Checklist completo e atualizado: ARQUITETURA_SAAS.md → "CHECKLIST
CONSOLIDADO". Pesquisa de mercado: MERCADO_E_PRECOS.md.
- R$ 1.234,56 no app inteiro; máscaras de CEP/telefone; helper de CPF.
- Endereço (entrega, endereços salvos, unidade) começa pelo CEP e preenche
  sozinho; número obrigatório ou "Endereço sem número".
- Fotos comprimidas no aparelho + miniaturas + cache de 1 ano; foto por
  link; catálogo incremental por `updatedAt` (cache do Firestore).
- Medidor de uso na Assinatura; extra R$ 5/bloco com teto de R$ 50;
  períodos mensal/6m(-10%)/12m(-15%); taxa por pedido agora R$ 0,99.
- Tela "fora do ar" para clientes quando a loja está suspensa.
- Importação de catálogo CSV (Shopify/Nuvemshop/modelo).
- Motoboy estimado pela distância (BrasilAPI); peso/medidas no produto.
- `tool/new_flavor.sh`, `tool/delete_flavor.sh`, `tool/provision_store.js`
  e flavors automáticos no Gradle — **ainda não executados de verdade**.
- Testado na web com emuladores; 44 testes; rules compilam no emulador.

### Rodada 2026-10-01 (tarde) — entrega, papéis, preços, reposição
- **Entrega:** unidade oferece retirada (grátis), Correios (valor fixo),
  Motoboy/Uber (valor fixo estimado) e entrega própria por ÁREA (cidades
  ou bairros, dias da semana, valor fixo; só no mesmo estado da unidade).
  Cliente escolhe no checkout (+ dia preferido); **a loja define a data
  final** e pode **propor outra entrega** → cliente aceita/recusa → loja
  aplica → ajuste registrado (devolver/cobrar a diferença; ajustes somam).
  Status novos no fim do enum: `pendingPayment`, `readyForPickup`
  (retirada: separação → pronto p/ retirar → retirado).
- **Papéis:** Administrador (dono + sócios), Gerente, Funcionário. Gerente
  e funcionário = mesmos toggles; gerente começa com tudo ligado.
- **Planos:** Loja única 9,90 → 29,90 (mês 7) → 59,90 (mês 13);
  Multilojas (2 lojas) 19,90 → 49,90 → 99,90; Plus (3–5) 199,90. Máx. 5.
- **Termos para Lojistas** (`/store_terms`, link na Assinatura) com planos,
  taxa, limites de uso e cláusula de revisão. Análise em
  `docs/CUSTOS_E_PRECOS.md`.
- **Fornecedores + reposição pelo WhatsApp:** cadastro (nome, contato,
  WhatsApp), produto vinculado ao fornecedor, alerta de estoque baixo por
  unidade no Perfil, tela de reposição que monta a mensagem e abre o
  wa.me.
- **Emuladores:** `firebase.json` com auth/firestore/storage; app aceita
  `--dart-define=USE_EMULATORS=true`. Firebase CLI exige Java 21: JDK
  portátil em `C:\Users\giova\tools\jdk-21.0.12.1+1` (o JDK 17 do sistema
  continua para os builds Android). Rodar com
  `PATH=/c/Users/giova/tools/jdk-21.0.12.1+1/bin:$PATH firebase emulators:start`.
- **Testado na web (emuladores):** login, vitrine com estoque por unidade,
  carrinho, checkout com as 4 opções, pedido gravado (taxa 1,99 só na
  plataforma), proposta de troca → aceite → aplicação → devolução,
  alertas e reposição pelo WhatsApp, equipe. Regras testadas por REST:
  cliente e funcionário bloqueados no que não podem (403).
- ⚠️ Pendente da Fase B: cliente ainda pode gravar `sizes` (estoque) porque
  o checkout roda no app.

### Plano v2 — Fase A concluída (2026-10-01)
Modelo novo (detalhe no plano v2, resumo em ARQUITETURA_SAAS.md):
- **Multi-lojas:** unidade física com CEP/cidade/UF e formas de entrega
  próprias (retirada, Correios, entrega própria + taxa); 1ª unidade tem id
  fixo `principal`. **Estoque por unidade** (`sizes[].stockByLocation`;
  formato antigo `stock` é lido como estoque da `principal`). Vitrine
  mostra "disponível na loja X / em Y — envio ou retirada", produtos da
  unidade do cliente primeiro, troca manual de unidade.
- **Equipe:** `staff/{uid}` com toggles de permissão (adicionar / editar /
  excluir produto, estoque, pedidos, home, aparência, zonas, unidades) e
  unidades em que trabalha. Substitui o array `admins`.
- **Dono não se exclui:** "Encerrar loja" cria
  `platform/closureRequests/requests/{storeId}` para o Giovanni decidir.
- **Planos:** Essencial R$ 99,90 (3 primeiros meses R$ 29,90, após o trial
  de 60 dias); Multilojas com preço PROVISÓRIO R$ 199,90 (a definir).
- **Taxa de serviço R$ 1,99:** loja absorve por padrão; toggle do dono
  repassa ao consumidor (`stores/{id}.serviceFee`).
- **Rules** reescritas (permissões, unidades, `private/` para tokens MP,
  `checkouts/` só leitura). ⚠️ Não validadas no emulador: o Firebase CLI
  exige **Java 21** (máquina tem 17).
- ⚠️ **O app não compilava** com o Flutter 3.44 (`font_awesome_flutter`
  10.x estende `IconData`, que virou `final`). Atualizado para 11.0.0;
  `flutter build web` volta a passar.

### Revisão 2026-10-01
- ⚠️ **Descoberta:** o checkout do CLIENTE **não chama** nenhum
  `PaymentService` — só grava o rótulo da forma de pagamento e já cria o
  pedido + baixa estoque. O mock só é usado na assinatura da loja. Ligar o
  Mercado Pago exige: status novo "aguardando pagamento", pedido nasce
  pendente, webhook confirma, Pix expirado devolve estoque.
- ⚠️ Cartão salvo no app não serve para o MP (token do MP é de uso único).
  Para lançar rápido: **Pix (API) + cartão via Checkout Pro** (página do MP).
- Corrigido: contas de teste só em debug; exclusão de conta pede senha,
  apaga subcoleções e bloqueia o único admin-master; aviso de e-mail com
  "Já verifiquei"; aceite dos termos gravado (versão + data); zona de
  entrega não era detectada no checkout (provider lazy); despacho apagava
  data/zona do pedido; data de entrega agora aparece no pedido; botão Uber
  só para admin; relatório separa receita da loja da taxa da plataforma;
  OAuth do MP usa `state` (redirect_uri tem que ser fixo).

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

Itens já implementados em código nesta sessão (2026-09-30): conta completa
(reset de senha, verificação de e-mail, exclusão de conta, Termos/Privacidade),
zonas de entrega própria + deep-link Uber, relatório financeiro mensal, e a
tela/camada de preparação do Mercado Pago. Falta:

1. **Deploy das regras atualizadas** (inclui a nova `deliveryZones`):
   ```bash
   firebase deploy --only firestore:rules,storage
   ```
2. **Backend (precisa do Blaze — só o Giovanni pode ativar):** Cloud
   Functions do Mercado Pago — `oauthConnectStore`, `payWithPix`,
   `payWithCard`, `paymentWebhook` (com split marketplace) e notificação
   push (FCM) na mudança de status do pedido.
3. **Ligar o pagamento real:** trocar `FakePaymentService` →
   `MercadoPagoService` em `main.dart` (ambos já prontos; é troca de uma
   linha depois que o backend existir).
4. **Build release** Android/iOS testado como produção antes de publicar.
5. **Fora desta fase (futuro):** WhatsApp para pedido a distribuidor,
   cadastro/vínculo de distribuidores, integração A2 (push de ofertas),
   Melhor Envio.

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
