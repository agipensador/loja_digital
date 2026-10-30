# Publicar o site de uma loja (PWA no Firebase Hosting)

> **Estado em 30/10/2026:** o build da PWA está pronto e testado, os alvos de
> hosting estão configurados e a esteira do GitHub está escrita. **Nada foi
> para o ar** — o site da `loja_ju` ainda não existe. O que falta é só o que
> depende de conta/cartão/senha, e está marcado com **(você)** abaixo.

O site é o canal padrão de toda loja (`ARQUITETURA_SAAS.md` §1): o cliente
abre o link e compra, sem instalar nada. O app nativo é benefício dos planos
com App.

---

## 1. Como funciona

Um código, N lojas. O que muda em cada site:

| O que | Onde é decidido |
|---|---|
| Dados da loja (produtos, pedidos, equipe) | `--dart-define=STORE_ID=<loja>` → `lib/core/tenant.dart` |
| Nome e cores **dentro** do app | Firestore: `stores/<loja>/config/appearance` (o admin edita) |
| Título da aba, nome do atalho, descrição, ícone | `tool/web/lojas_web.dart` (o navegador precisa disso **antes** de o app carregar) |
| Endereço do site | alvo de hosting no `firebase.json` + `.firebaserc` |

A pasta `web/` é **a mesma para todas as lojas** — nunca escreva o nome de uma
loja ali (há teste cobrando isso). Quem põe a marca de cada loja é o
`tool/build_web.dart`, e só dentro de `build/web_<loja>/`.

Hoje cada loja tem o **seu** build. Um build único que descobre a loja pela URL
(`inforizz.com/<slug>`) é a Fase 2 do `ARQUITETURA_SAAS.md`.

---

## 2. Compilar o site de uma loja (na sua máquina)

```bash
cd app_loja_digital
dart run tool/build_web.dart loja_ju
```

Sai em `build/web_loja_ju`. Para ver antes de mandar para o ar:

```bash
cd build/web_loja_ju && python -m http.server 8000
# abre http://localhost:8000
```

Opções:

```bash
# Testar outro nome sem commitar nada
dart run tool/build_web.dart loja_ju --nome "Loja da Ju"

# Site servido numa subpasta (inforizz.com/loja-ju/)
dart run tool/build_web.dart loja_ju --base-href /loja-ju/

# Só trocar a marca de um build que já existe (não recompila)
dart run tool/build_web.dart loja_ju --sem-build

# Pela tag de release, igual à esteira faz
dart run tool/build_web.dart --tag web-loja_ju-v1.0.0
```

### Ícone da loja **(você)**

Sem logotipo o site vai para o ar com o **ícone padrão do Flutter** — na tela
inicial do celular do cliente. Coloque um PNG **quadrado**, de preferência
≥ 512 px, em:

- `flavors/lojaju/icon.png` → loja_ju
- `flavors/lojagi/icon.png` → loja_gi

É o mesmo arquivo que o `tool/new_flavor.sh` usa para o ícone do app nativo:
um logotipo por loja, nada duplicado. O build gera sozinho os 5 PNGs da PWA
(192, 512, os dois *maskable* e o favicon).

> O ícone *maskable* ocupa 56% do quadrado de propósito: o Android recorta o
> ícone em círculo e só garante os 80% centrais. Logotipo maior que isso sai
> com as pontas cortadas.

---

## 3. Criar o site no Firebase **(você — uma vez por loja)**

Os alvos já estão escritos no `.firebaserc`:

| Loja | Alvo | Site | Endereço grátis |
|---|---|---|---|
| loja_ju | `loja_ju` | `loja-digital-ju0714-lojaju` | https://loja-digital-ju0714-lojaju.web.app |
| loja_gi | `loja_gi` | `loja-digital-ju0714-lojagi` | https://loja-digital-ju0714-lojagi.web.app |

Falta criar o site (o agente não cria nada no Firebase):

```bash
firebase login                     # conta contato@inforizz.com
firebase hosting:sites:create loja-digital-ju0714-lojaju \
  --project loja-digital-ju0714
```

Quer um endereço mais bonito? O nome do site é livre (minúsculas, números e
hífen, até 30 caracteres) — crie com o nome que preferir e troque a linha
correspondente no `.firebaserc`. O teste `test/web_pwa_test.dart` confere que
catálogo, `firebase.json` e `.firebaserc` continuem combinando.

O endereço definitivo previsto é `<loja>.inforizz.com` (CNAME no DNS da
inforizz.com + domínio personalizado no Hosting, HTTPS automático) — item
aberto em `ARQUITETURA_SAAS.md` → "Domínios".

### Mandar para o ar da sua máquina

```bash
cd app_loja_digital
dart run tool/build_web.dart loja_ju
firebase deploy --only hosting:loja_ju --project loja-digital-ju0714
```

⚠️ **Sempre com `hosting:<loja>`.** `--only hosting` sem o alvo manda **todas**
as lojas do `firebase.json` — e a loja que não tiver sido compilada vai para o
ar com a pasta vazia, ou seja, sai do ar.

---

## 4. Esteira: mandar para o ar por tag

`.github/workflows/web.yml`:

| Quando | O que faz |
|---|---|
| PR e push na `main` | `flutter analyze`, `flutter test` e compila a PWA da `loja_ju`. Nada vai para o ar. |
| tag `web-<loja>-v<versão>` | o mesmo + envia **aquela** loja para o Hosting |

Exemplo: `web-loja_ju-v1.0.0` → alvo `hosting:loja_ju`. Tag de loja que não
está em `tool/web/lojas_web.dart` **falha** antes de compilar.

**Enquanto não existir o secret, o envio fica desligado**: o job roda, escreve
um aviso dizendo o que falta e termina verde. O site compilado fica guardado
como artefato por 7 dias, então dá para baixar e conferir.

### Criar o secret **(você — uma vez)**

1. Conta de serviço no Google Cloud (projeto `loja-digital-ju0714`):
   console do Firebase → ⚙️ Configurações do projeto → **Contas de serviço**
   → *Gerar nova chave privada*. Baixa um `.json`.
   - Se preferir uma conta só para isso (recomendado), crie uma nova no
     Google Cloud → IAM → Contas de serviço e dê **só** o papel
     **Administrador do Firebase Hosting** (`roles/firebasehosting.admin`)
     + **Leitor do Firebase** (`roles/firebase.viewer`).
2. GitHub → repositório `loja_digital` → **Settings** → *Environments* →
   **producao** → *Add secret*:
   - Nome: `FIREBASE_SERVICE_ACCOUNT`
   - Valor: o conteúdo **inteiro** do `.json` (abre, copia tudo, cola)
3. (Opcional, recomendado) no mesmo *environment*, ligue
   *Required reviewers* com o seu usuário: aí nenhuma tag vai para o ar sem
   você apertar um botão.

> O arquivo `.json` é uma chave: não commite, não mande por WhatsApp e apague
> do Downloads depois de colar. Se vazar, revogue no console.

### Mandar uma versão para o ar

```bash
git tag web-loja_ju-v1.0.0
git push origin web-loja_ju-v1.0.0
```

Acompanhe na aba **Actions**. A versão da tag é só um rótulo do site (o
`version` do `pubspec.yaml` continua sendo a do app nativo).

---

## 5. Quando der problema

| Sintoma | Causa provável |
|---|---|
| `Site loja-digital-ju0714-lojaju not found` | o site não foi criado (passo 3) |
| `Deploy target loja_ju not configured` | rodou de fora de `app_loja_digital/` (é onde estão o `firebase.json` e o `.firebaserc`) |
| Cliente continua vendo a loja antiga | o `firebase.json` já manda `no-cache` no `index.html` e nos carregadores do Flutter; o resto é o cache de 1 h do próprio Hosting. Em dúvida, abra em aba anônima |
| Site abre em branco | quase sempre `--base-href` errado: servido em subpasta precisa de `--base-href /subpasta/` |
| Ícone do Flutter na tela inicial | falta o logotipo em `flavors/<flavor>/icon.png` (passo 2) |
| Tudo dá `permission-denied` dentro do site | regras do Firestore/Storage — ver `STATUS.md` |

---

## 6. O que ainda não existe

- **Build único multi-loja** (loja resolvida pela URL): Fase 2.
- **Domínio próprio** por loja: Fase 4 (`ARQUITETURA_SAAS.md` → "Domínios").
- **Loja suspensa sai do ar sozinha**: hoje o site de uma loja inadimplente
  continua no ar; depende do job diário do backend (Fase 3).
- **iOS/Android por loja**: `tool/new_flavor.sh` (nativo) e a tarefa E3 da
  fila dos agentes (esteira de iOS).

Loja nova na web, hoje, são 3 arquivos: entrada em `tool/web/lojas_web.dart`,
alvo no `firebase.json` e site no `.firebaserc`. Esquecer um dos três quebra o
teste, não o site.
