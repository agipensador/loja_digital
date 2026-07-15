# Integração Loja Digital ↔ A2 Platform

Status deste documento: **v1 — 2026-07-15**
Referência: `A2_Platform_Documento_Mestre_v1.pdf`

---

## 1. A ideia em uma frase

A **Loja Digital** (este app, Firebase) é **uma loja**. O **A2** (app de
relacionamento, backend AWS Amplify) é o **agregador** que mostra ofertas de
**várias lojas** para os casais. Os dois se conectam **só por um contrato
padronizado** (a "Offer"). Nenhum acessa o banco/código do outro.

> Princípio do documento mestre do A2: *"O A2 não depende da implementação de
> nenhuma loja; consome apenas contratos padronizados."*

---

## 2. Como funciona hoje (o que já existe)

```
LOJA DIGITAL (Firebase)                         A2 (AWS Amplify)
────────────────────────                        ─────────────────
Produtos internos (coleção products)
        │
        │  admin abre: Perfil → Publicar no A2
        │  escolhe até 10 produtos
        ▼
coleção  a2_offers   ...................►   [ Adapter "Loja Base" ]  (a construir)
(contrato Offer,                                     │
 status = pending)                                   ▼
        ▲                                     Commerce Hub / Offers
        │                                            │
        │                                     Moderação (você aprova/reprova)
        │                                            │
        └──── status: approved / rejected ◄──────────┘   (a construir)
                                                     │
                                              App A2 só mostra APROVADAS
```

### Já implementado (lado da Loja) — commits até `d11d793`
- **`A2Offer`** (`lib/models/a2_offer.dart`): o contrato. Converte um `Product`
  da loja em oferta padronizada (`A2Offer.fromProduct`) e serializa
  (`toContract`).
- **`A2PublishManager`** (`lib/models/a2_publish_manager.dart`): grava/remove
  ofertas na coleção **`a2_offers`**, com **limite de 10** por loja. Lê de volta
  o `status` de moderação.
- **Tela "Publicar no A2"** (`lib/screens/a2_publish/`): admin liga/desliga um
  switch por produto (para no 10º) e vê o status: **Em análise / Aprovado /
  Rejeitado**. Acesso: **Perfil → (admin) Publicar no A2**.
- Identidade da loja: `--dart-define=A2_STORE_ID=...` (default `loja_digital`).

---

## 3. O contrato "Offer" (a única coisa que os dois precisam concordar)

Cada documento em `a2_offers` tem este formato:

| Campo             | Tipo     | Descrição                                        |
|-------------------|----------|--------------------------------------------------|
| `storeId`         | string   | Identifica a loja de origem (ex: `loja_digital`) |
| `productId`       | string   | Id do produto na loja (referência de origem)     |
| `title`           | string   | Nome exibido                                     |
| `description`     | string   | Descrição                                        |
| `price`           | number   | Preço-base                                       |
| `images`          | string[] | URLs das imagens                                 |
| `category`        | string   | Categoria                                        |
| `metadata`        | object   | Variantes/estoque (configurável, nada hardcoded) |
| `status`          | string   | `pending` \| `approved` \| `rejected` (A2 define)|
| `reviewNote`      | string   | Observação da moderação (A2 preenche)            |
| `source`          | string   | `loja_digital` (origem)                          |
| `contractVersion` | number   | Versão do contrato (hoje `1`)                    |
| `updatedAt`       | ts       | Última atualização                               |

**Regra de ouro:** o A2 lê SÓ estes campos. Se a loja mudar seu modelo interno
`Product`, o contrato continua igual → o A2 não quebra.

---

## 4. O que você precisa criar NO A2 (o que falta)

O A2 usa **AWS Amplify** (`a2_backend/amplify/data` = GraphQL/DynamoDB). São
3 peças:

### 4.1. Modelo de dados no A2 (Amplify Data / GraphQL)
Criar dois modelos no `amplify/data/resource.ts`:

- **`Store`** — cadastro de cada loja parceira:
  `id, name, storeId (chave da loja, ex "loja_digital"), type (fisica/dropshipping),
  active (bool), sourceConfig (como buscar as ofertas dela)`.
- **`Offer`** — a oferta já dentro do A2 (espelho do contrato + moderação):
  `id, storeId, productId, title, description, price, images, category, metadata,
  moderationStatus (PENDING/APPROVED/REJECTED), reviewNote, publishedAt`.

Autorização: casais leem **só** `Offer` com `moderationStatus = APPROVED`; o
admin (você) tem acesso total para moderar.

### 4.2. O Adapter de ingestão (conectar cada loja)
É o que "puxa" as ofertas de cada loja e cria/atualiza `Offer` no A2. Duas
formas — **recomendo a B**:

- **A) A2 puxa (pull):** uma Lambda agendada lê as `a2_offers` de cada loja.
  Problema: acopla o A2 ao Firebase da loja. Evitar.
- **B) Loja empurra (push) — recomendado:** a loja chama um **endpoint do A2**
  (AppSync mutation `ingestOffer` ou uma API HTTP) enviando o contrato. Assim:
  - O A2 **não conhece** o Firebase da loja (zero acoplamento de transporte).
  - Cada loja usa uma **API key própria** → o A2 sabe de qual loja veio.
  - Adicionar uma **nova loja** = cadastrar um `Store` + emitir uma key. Nenhum
    código novo por loja (todas falam o mesmo contrato).

  No lado da Loja Digital isso é uma **Cloud Function** que dispara quando um doc
  entra em `a2_offers` e faz o POST para o A2 (essa function eu adiciono quando
  você quiser — hoje a loja só grava em `a2_offers`, o "outbox").

### 4.3. A moderação (aprovar/reprovar)
- Uma tela no A2 (admin) listando `Offer` com `moderationStatus = PENDING`.
- Botões **Aprovar / Reprovar** → uma mutation `moderateOffer(id, status, note)`
  que atualiza o `Offer` no A2.
- **Devolver o status para a loja:** a mesma mutation chama de volta o endpoint
  da loja (ou a loja consulta) para gravar `status`/`reviewNote` na `a2_offers`.
  É isso que faz a tela "Publicar no A2" mostrar "Aprovado/Rejeitado".

---

## 5. Como conectar VÁRIAS lojas diferentes

O modelo já é multi-loja por design:

1. Cada loja tem um **`storeId`** único (Loja Digital = `loja_digital`; a loja da
   Ju poderia ser `loja_ju`, etc.).
2. No A2 você cadastra um **`Store`** por loja (nome, tipo, ativa) e emite uma
   **API key**.
3. Toda oferta que chega traz o `storeId` → o A2 sabe a origem, agrupa,
   filtra e modera por loja.
4. **Nova loja no ar** = novo `Store` + nova key. Como todas falam o **mesmo
   contrato Offer**, **não há código específico por loja** (é o "Adapter
   Manual" do documento mestre).

O carrinho no A2 é **por loja** (o próprio documento define: não há checkout
multi-loja) — então cada oferta aprovada sabe a qual loja pertence para o
checkout acontecer na loja certa.

---

## 6. Fluxo completo (ponta a ponta)

1. Admin da Loja Digital: **Publicar no A2** → escolhe até 10 produtos.
2. Loja grava em `a2_offers` (`status: pending`).
3. (a construir) Cloud Function da loja faz **push** para o A2 (`ingestOffer`).
4. A2 cria/atualiza `Offer` com `moderationStatus: PENDING`.
5. Você modera no A2 (**Aprovar/Reprovar**).
6. A2 atualiza o `Offer` e **devolve o status** para a `a2_offers` da loja.
7. App A2 mostra aos casais **só as ofertas aprovadas**; a Loja Digital mostra
   ao admin o status de cada uma.

---

## 7. Status atual — o que está pronto e o que falta

| Item                                                   | Onde        | Status         |
|--------------------------------------------------------|-------------|----------------|
| Contrato `A2Offer`                                     | Loja        | ✅ Pronto       |
| Publicar até 10 produtos (outbox `a2_offers`)          | Loja        | ✅ Pronto       |
| Tela admin "Publicar no A2" + status                   | Loja        | ✅ Pronto       |
| Cloud Function de push loja → A2                       | Loja        | ⏳ A fazer      |
| Modelos `Store` e `Offer` (Amplify Data)               | A2 backend  | ⏳ A fazer      |
| Endpoint de ingestão (`ingestOffer` + API key p/ loja) | A2 backend  | ⏳ A fazer      |
| Tela de moderação (aprovar/reprovar)                   | A2 app      | ⏳ A fazer      |
| Devolução do status para a loja                        | A2 → Loja   | ⏳ A fazer      |
| App A2 exibindo só ofertas aprovadas                   | A2 app      | ⏳ A fazer      |

---

## 8. Próximos passos sugeridos (sem acoplar os apps)

1. **A2 backend:** criar `Store` + `Offer` no Amplify Data e a mutation
   `ingestOffer` (com autorização por API key de loja).
2. **A2 app:** tela de moderação (lista PENDING → aprovar/reprovar).
3. **Loja:** Cloud Function que faz push de `a2_offers` para o `ingestOffer`.
4. **Volta do status:** `moderateOffer` chama o endpoint da loja para gravar
   `status`/`reviewNote`.

> Tudo isso mantém a regra do documento mestre: **o A2 nunca acessa a loja
> diretamente**; a conversa é sempre pelo contrato Offer, via um endpoint, com
> a loja identificada por `storeId` + API key.
