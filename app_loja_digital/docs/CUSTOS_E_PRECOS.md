# Custos de infraestrutura × preço dos planos

Status: estimativa v2 — 2026-10-01. **Medir de verdade depois do lançamento**
(painel de uso do Firebase) e recalibrar estes números.

## v2 — depois das otimizações (já implementadas)
- Fotos comprimidas no aparelho (até 1600 px, ~150–300 KB) + miniatura de
  480 px (~30–50 KB) nas listas, com cache de 1 ano (celular e navegador).
- Catálogo sincronizado só pelo que mudou (`updatedAt`) a partir do cache
  local: ~0–5 leituras por abertura em vez de ~170.
- **Custo estimado: ~R$ 0,50–1,00 a cada 1.000 visitas** (antes ~R$ 3,30).
- **Taxa por pedido R$ 0,99:** infra por pedido ≈ R$ 0,05 (50 visitas) →
  margem ~20×. Confirmado: dá para cobrar R$ 0,99 em vez de R$ 1,99.
- **Extra por uso** (R$ 5 a cada 1.000 visitas / 100 produtos / 1 GB acima
  do plano, teto R$ 50): ~5× o custo; no teto cobre ~10 mil visitas extras.
- **Preços atuais (2026-10-04):** 29,90 / 59,90 / 119,90. Relação
  custo/preço por plano em MERCADO_E_PRECOS.md ("Estratégia de preço").
- **Plus (R$ 119,90) com muito uso:** 120 mil visitas/mês custariam
  ~R$ 60–120 de infra; com 2% de conversão são ~2.400 pedidos × R$ 0,99 ≈
  R$ 2.376 — a tarifa por pedido paga o crescimento com folga.
- Abaixo: cálculo original (v1), antes das otimizações.

## Premissas

| Item | Valor usado | Observação |
|---|---|---|
| Câmbio | R$ 5,50 / US$ | ajustar |
| Firestore leitura | US$ 0,06 / 100 mil | preço de referência Blaze; região São Paulo costuma ser mais cara — conferir no console |
| Firestore escrita | US$ 0,18 / 100 mil | idem |
| Cloud Storage (download de imagens) | US$ 0,12 / GB | é o maior custo por visita |
| Hosting (download do site) | US$ 0,15 / GB | app web ~3 MB, só no 1º acesso do aparelho |
| Cloud Functions | US$ 0,40 / milhão de chamadas | ~5 chamadas por pedido (MP) — desprezível |
| Faixa gratuita do Firebase | ignorada | é compartilhada por TODAS as lojas; tratar como folga |
| Conversão | 2% das visitas viram pedido | média de e-commerce pequeno |

## Custo por visita (sessão de um cliente)

O app hoje carrega o catálogo inteiro ao abrir. Com ~150 produtos:

- ~170 leituras do Firestore → US$ 0,0001
- ~3 MB de imagens (≈25 fotos vistas) → US$ 0,00036
- ~0,9 MB de site (média, considerando cache) → US$ 0,00014

**≈ US$ 0,0006 por visita ≈ R$ 3,30 a cada 1.000 visitas.**
Por pedido (escritas + Functions) o custo é de centavos de centavo.

Dois custos que NÃO crescem com as vendas e merecem atenção:
1. **Imagens grandes:** são ~60% do custo. Gerar miniaturas (extensão
   "Resize Images" do Firebase) corta esse custo em 5–10×.
2. **Histórico de pedidos:** o painel do admin lê *todos* os pedidos da loja
   ao abrir. Uma loja com 3.000 pedidos paga ~R$ 0,01 por abertura do painel.
   Corrigir com consulta paginada por mês antes de lojas grandes entrarem.

## Cenários por loja (mês)

| Visitas/mês | Pedidos (2%) | Custo infra | Taxa R$ 1,99/pedido (receita sua) |
|---|---|---|---|
| 1.500 | 30 | ~R$ 5 | R$ 60 |
| 5.000 | 100 | ~R$ 17 | R$ 199 |
| 10.000 | 200 | ~R$ 33 | R$ 398 |
| 20.000 | 400 | ~R$ 66 | R$ 796 |
| 60.000 | 1.200 | ~R$ 198 | R$ 2.388 |

## Conclusões

1. **A taxa de R$ 1,99 por pedido já acompanha o crescimento.** Infra por
   pedido ≈ R$ 0,17 (50 visitas × R$ 0,0033); a taxa é ~12× isso. Loja que
   vende muito se paga sozinha, mesmo na mensalidade de entrada.
2. **O risco real é loja com muito tráfego e poucas vendas** (vitrine,
   catálogo enorme, fotos pesadas). É isso que a cláusula de revisão deve
   cobrir — por uso, não por "número de clientes".
3. **O período de R$ 9,90 é a janela de prejuízo possível:** acima de
   ~3.000 visitas/mês *sem pedidos*, a infra passa da mensalidade.
4. Limites sugeridos para os Termos dos Lojistas (com folga ~2× sobre o
   custo, mesmo sem contar a taxa por pedido):

| Plano | Visitas/mês | Produtos | Imagens |
|---|---|---|---|
| Loja única | até 10.000 | até 500 | até 2 GB |
| Multilojas (2 lojas) | até 25.000 | até 1.500 | até 5 GB |
| Multilojas Plus (3–5) | até 60.000 | até 3.000 | até 10 GB |

Acima disso: aviso com 30 dias de antecedência e proposta de novo valor.

## O que falta para isso valer na prática
- **Medir uso por loja.** Hoje não há contagem de visitas por loja. Opções:
  Firebase Analytics com parâmetro `storeId`, ou um contador diário por loja
  gravado pelo app. Sem isso não dá para aplicar os limites.
- Miniaturas de imagem e paginação do painel de pedidos (acima).
- Revisar estes números com a fatura real dos 2–3 primeiros meses.
