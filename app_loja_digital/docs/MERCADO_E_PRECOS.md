# Mercado, concorrentes e preços

Pesquisa de 2026-10-01 (valores públicos dos sites/blogs das plataformas;
conferir antes de divulgar comparações).

## Quanto cobra quem já está no mercado

| Plataforma | Mensalidade | Tarifa por venda | App nativo próprio? |
|---|---|---|---|
| **Nuvemshop** | Grátis · R$ 69 · R$ 164 · R$ 449 | 0% com Nuvem Pago; 2% / 1% / 0,7% com outro meio | Não (só site) |
| **Shopify** | US$ 19 · 52 · 399 (≈ R$ 105 · 286 · 2.200, + IOF) | 2% / 1% / 0,6% com gateway externo | Não (apps pagos à parte) |
| **Loja Integrada** | Grátis · R$ 54 · R$ 99 · R$ 239 · R$ 1.999 | 0% no nativo; 0,5–0,99% fora | Não |
| **Kyte** (catálogo + PDV) | Grátis · R$ 49,90 · R$ 69,90 · R$ 99,90 | — | App do Kyte, não da loja |
| **The Seven** (app de loja) | App Pro R$ 129,90 (Android) · Premium R$ 249,90 (Android+iOS) | — | **Sim** |
| **Gama Delivery** (white label) | R$ 1.500 de ativação + R$ 60/loja/mês | — | **Sim** |

Gateways (o lojista paga, em qualquer plataforma): Mercado Pago Pix 0,99%,
cartão 4,99% (na hora) a 3,99% (30 dias); Asaas Pix R$ 1,99 por cobrança
(R$ 0,99 nos 3 primeiros meses), cartão 1,99% + R$ 0,49.

## Onde nós estamos

| | Loja Digital (Inforizz) |
|---|---|
| Mensalidade (proposta 2026-10-04) | **Loja única R$ 29,90** · **Multilojas (2) R$ 59,90** · **Multilojas Plus (3–5) R$ 119,90** — preço fixo, sem escada |
| Período grátis | **3 meses** (90 dias); depois, 1ª cobrança por Pix |
| Períodos | mensal · 6 meses −10% · 12 meses −15% |
| Tarifa por pedido | **R$ 0,99 fixo em todos os pedidos pagos**; loja ou cliente paga |
| App nativo | **Sim, Android + iOS + site**, com a marca da loja |

## Pontos fortes
1. **App próprio (Android + iOS) pelo preço de site** — quem vende app
   próprio cobra R$ 130–250/mês; nós cobramos R$ 29,90, com 3 meses grátis.
2. **Home montável** pelo lojista, sem tema/programador.
3. **Entrega local de verdade:** áreas por cidade/bairro com dias e valor,
   motoboy (Uber) estimado pela distância, retirada, Correios — e a loja
   pode propor outra entrega com devolução da diferença.
4. **Multi-lojas** com estoque por unidade e equipe por unidade.
5. **Reposição pelo WhatsApp** com o fornecedor já vinculado ao produto.
6. **Equipe com permissões finas** (gerente/funcionário por toggle).
7. Tarifa por pedido **fixa e baixa** (R$ 0,99) — previsível.

## Pontos fracos (e o que fazer)
1. **Sem gateway próprio**: Nuvemshop/Loja Integrada zeram a tarifa no
   meio nativo. → Nosso R$ 0,99 é menor que os 2% deles fora do nativo;
   comunicar isso.
2. **Sem integrações** (ERP, NF-e, Mercado Livre/Shopee, Bling/Tiny). →
   Importação por CSV já resolve a entrada; integrações ficam no roadmap.
3. **Frete real dos Correios** ainda é valor fixo. → Melhor Envio (Fase B).
4. **Risco Apple 4.2.6** publicando vários apps-loja na mesma conta.
5. **Suporte de um dev só** — o preço baixo atrai volume; precisa de
   onboarding self-service (importação, templates de home) e FAQ.
6. Sem domínio próprio/SEO/blog ainda.

## Estratégia de preço (2026-10-04): custo ≈ 1/4 a 1/3 do preço

Regra do Giovanni: o custo deve ficar entre 1/4 e 1/3 do preço (ex.: custo
30 → ganho 90 → preço 120). Custo por loja = infra (R$ 0,50–1,00 a cada mil
visitas, ver CUSTOS_E_PRECOS.md) + tarifa do MP sobre a mensalidade (Pix
0,99%) + avisos de cobrança no WhatsApp (~R$ 0,11) + notificações push
(FCM, grátis) + atendimento (robô v1 sem custo).

| Plano | Preço | Custo **no limite** do plano (pior caso) | Custo típico (30% do limite) | Custo/preço |
|---|---|---|---|---|
| Loja única (10 mil visitas, 2 GB) | R$ 29,90 | ~R$ 6–11 | ~R$ 3 | **1/3 no pior caso**, ~1/10 no típico |
| Multilojas (25 mil, 5 GB) | R$ 59,90 | ~R$ 14–26 | ~R$ 6 | ~1/3 (pior caso no teto da estimativa: 0,43) |
| Multilojas Plus (60 mil, 10 GB) | R$ 119,90 | ~R$ 32–62 | ~R$ 13 | ~1/3 (pior caso no teto da estimativa: 0,52) |

Leitura:
- No uso típico o custo fica bem abaixo de 1/4. Só a loja que chega ao
  teto do plano encosta em 1/3. Mesmo assim, quem tem 60 mil visitas vende
  (2% = 1.200 pedidos × R$ 0,99 ≈ R$ 1.188), e a tarifa por pedido cobre o
  excedente com folga.
- O risco é **muito tráfego e quase nenhuma venda**. Para isso existe o
  extra por uso (R$ 5 por bloco, teto R$ 50).
- Se a fatura real dos primeiros meses mostrar custo no teto da estimativa,
  ajustar o **limite** (ex.: Plus 50 mil visitas) antes de mexer no preço.
- 3 meses grátis custam em média **~R$ 9 por loja** (R$ 3/mês × 3),
  basicamente custo de aquisição de cliente. Uma loja que fica 12 meses
  já pagou esse custo.

## Quanto sobra por loja no pior caso (2026-10-04)
Preço − custo de infra no limite do plano − tarifa do MP na mensalidade
(~1%) − imposto (Simples Nacional, ~6% no início; confirmar com o contador):

| Plano | Preço | Infra no limite | MP + imposto | **Sobra (pior caso)** | Sobra típica |
|---|---|---|---|---|---|
| Loja única | 29,90 | 6–11 | ~2,10 | **~R$ 17–22** | ~R$ 25 |
| Multilojas | 59,90 | 14–26 | ~4,20 | **~R$ 30–42** | ~R$ 50 |
| Plus (3–5) | 119,90 | 32–62 | ~8,40 | **~R$ 50–80** | ~R$ 98 |

- O valor é **por empresa (app)**, não por unidade física: no Plus com 5
  unidades, o pior caso dá ~R$ 10–16 por unidade.
- Fica de fora: seu tempo de suporte/implantação, a conta Apple (US$ 99/ano,
  que na regra 4.2.6 deve ser da própria loja) e domínio próprio (da loja).
  Por isso a sugestão de **implantação avulsa** (ex.: R$ 197 com Android +
  site; iPhone quando a loja tiver a conta Apple).
- A taxa de R$ 0,99 por pedido não entra na conta acima e é o que paga o
  crescimento: 100 pedidos/mês = R$ 99 a mais.

## Planos estratégicos (em breve)
1. **Preço de fundador**: as 50 primeiras lojas pagantes travam o preço por
   24 meses. Gera urgência e depoimentos.
2. **Anual em destaque**: Loja única anual = R$ 304,98 (R$ 25,42/mês),
   recebido à vista e com menos cancelamento.
3. **Implantação assistida** (avulsa, ~R$ 149): nós cadastramos o catálogo
   (CSV/planilha) e montamos a home. Receita imediata, com o suporte pago
   à parte.
4. **Indique e ganhe**: 1 mês grátis por loja indicada que virar pagante.
5. **Vitrine grátis** (futuro, só web): catálogo sem checkout, 50
   produtos, 2 mil visitas, com a marca Inforizz. Funciona como funil para
   a Loja única e custa ~R$ 1–2/mês por loja. Só vale com o cadastro 100%
   self-service.
6. **Pacote de avisos**: notificações push por mês incluídas por plano
   (8 / 20 / 60). Push custa ~zero, então a cota serve para não incomodar o
   cliente final e pode ser vendida como pacote extra mais tarde.

## Recomendação final
- Lançar com **29,90 / 59,90 / 119,90 + 3 meses grátis + taxa R$ 0,99 em
  todos os pedidos**. Todas as lojas pagam o valor normal.
  oferecem app próprio e próximo do preço de quem vende só site.
- **R$ 0,99 por pedido**: confirmado (ver CUSTOS_E_PRECOS.md). Cobre a
  infraestrutura com folga (~20×) e é menor que a tarifa por venda dos
  concorrentes fora do gateway nativo.

## Cobrança da mensalidade (assinatura das lojas)
- **Mercado Pago** para tudo (uma integração só, que já fazemos para as
  vendas): **Pix Automático** (mensal) e **cartão recorrente**
  (assinaturas/preapproval); semestral e anual por Pix ou cartão à vista.
- Por que não Asaas para a mensalidade: Pix a R$ 1,99 por cobrança é ~7%
  de uma mensalidade de R$ 29,90 (no MP, Pix 0,99% ≈ R$ 0,30).
- **Fim dos 3 meses grátis:** a 1ª cobrança é um Pix comum (QR no app,
  com aviso 10 dias antes). Depois de pago, o app oferece ativar o Pix
  Automático ou o cartão recorrente.
- Preço fixo: o Pix Automático só precisa de nova autorização quando o
  lojista **muda de plano**, e o app avisa antes.
- Assinar e trocar de plano **dentro do app** (tela Assinatura): já está na
  interface; a cobrança real entra na fase Mercado Pago.

## Avisos de cobrança
- 10 dias antes do vencimento (se não for automático): aviso no app e
  e-mail; nos 3 últimos dias, **WhatsApp** diário.
- WhatsApp oficial (Meta Cloud API): mensagem de utilidade ≈ R$ 0,035 →
  3 avisos ≈ R$ 0,11 por loja/mês. Exige conta Meta Business verificada,
  número dedicado e template aprovado. Disparo por função agendada (Fase B).

## Fontes
- Nuvemshop: https://www.nuvemshop.com.br/planos-e-precos · https://estocometro.com/planos-nuvemshop-2026/
- Shopify: https://base.com/pt-BR/blog/quanto-custa-shopify/ · https://litextension.com/pt/blog/shopify-pricing
- Loja Integrada: https://lojaintegrada.com.br/compare/ · https://litextension.com/pt/blog/loja-integrada-pricing-plans
- Kyte: https://www.kyte.com.br/planos
- App próprio white label: https://www.applojavirtual.com.br/en/revenda-de-loja-virtual-com-app/ · https://gamadelivery.app/revenda.html
- Mercado Pago taxas: https://sellsync.ai/pt/blog/taxa-mercado-pago-2026-guia-completo/
- Asaas taxas: https://www.asaas.com/precos-e-taxas · https://blog.asaas.com/taxas-asaas/
- Pix Automático: https://docs.asaas.com/docs/pix-automatico · https://www.mercadopago.com.br/blog/pix-automatico-vender-pacotes-assinaturas
- WhatsApp API: https://www.zappy.chat/novos-precos-whatsapp-api-outubro-2026-zappy/
- Melhor Envio API: https://docs.melhorenvio.com.br/reference/introducao-api-melhor-envio
- Uber Direct Brasil: https://gazzconecta.com.br/gazz-conecta/uber-direct-mira-expansao-no-brasil-e-lanca-recurso-para-pequenas-e-medias-empresas/
- Shopify CSV: https://help.shopify.com/en/manual/products/import-export/common-import-issues
- Resize Images (encerramento das Extensions em 31/03/2027): https://extensions.dev/extensions/firebase/storage-resize-images
- Migração das Extensions para function kits: https://firebase.google.com/docs/extensions/users/migrate
