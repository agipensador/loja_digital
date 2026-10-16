#!/usr/bin/env bash
# Cria um novo app de loja (flavor) a partir do app base.
#
# Uso:
#   tool/new_flavor.sh --id lojagi --store-id loja_gi --name "Loja Gi" \
#     --owner-email contato@inforizz.com [--package com.inforizz.lojagi] \
#     [--bundle com.inforizz.lojagi] [--plan unica] \
#     [--logo caminho/logo.png] [--color "#E53935"]
#
# O que faz (tudo no MESMO projeto Firebase — sem Terraform: cada loja é
# só um conjunto de registros, não uma infraestrutura própria):
#   1. flavors/<id>/flavor.json e dart_defines.json (nome, ids, STORE_ID)
#   2. registra o app Android no Firebase e baixa o google-services.json
#      para android/app/src/<id>/ (o Gradle cria o flavor sozinho)
#   3. registra o app iOS e baixa o GoogleService-Info.plist para
#      ios/flavors/<id>/ + xcconfig (o scheme do Xcode precisa de um Mac)
#   4. cria o site de hosting <id> e o alvo no firebase.json
#   5. cria a loja no Firestore (trial de 3 meses; o dono assume ao entrar
#      no app com o e-mail informado) — exige GOOGLE_APPLICATION_CREDENTIALS
#   6. ícone do app = logotipo real da loja (--logo): Android, iOS e web
set -euo pipefail
cd "$(dirname "$0")/.."

PROJECT="${FIREBASE_PROJECT:-loja-digital-ju0714}"
ID="" STORE_ID="" NAME="" OWNER="" PACKAGE="" BUNDLE="" PLAN="unica"
LOGO="" COLOR="#FFFFFF"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --id) ID="$2"; shift 2 ;;
    --store-id) STORE_ID="$2"; shift 2 ;;
    --name) NAME="$2"; shift 2 ;;
    --owner-email) OWNER="$2"; shift 2 ;;
    --package) PACKAGE="$2"; shift 2 ;;
    --bundle) BUNDLE="$2"; shift 2 ;;
    --plan) PLAN="$2"; shift 2 ;;
    --logo) LOGO="$2"; shift 2 ;;
    --color) COLOR="$2"; shift 2 ;;
    *) echo "Opção desconhecida: $1"; exit 1 ;;
  esac
done

[[ -z "$ID" || -z "$NAME" || -z "$OWNER" ]] && {
  echo "Obrigatório: --id, --name e --owner-email"; exit 1; }
# Nome de flavor do Gradle: só minúsculas e números, começando por letra.
[[ "$ID" =~ ^[a-z][a-z0-9]*$ ]] || {
  echo "--id deve ter só letras minúsculas e números (ex.: lojagi)"; exit 1; }
STORE_ID="${STORE_ID:-$ID}"
PACKAGE="${PACKAGE:-com.inforizz.$ID}"
BUNDLE="${BUNDLE:-com.inforizz.$ID}"
[[ -d "flavors/$ID" ]] && { echo "O flavor $ID já existe."; exit 1; }

echo "==> 1/5 Configuração do flavor"
mkdir -p "flavors/$ID"
cat > "flavors/$ID/flavor.json" <<JSON
{
  "id": "$ID",
  "storeId": "$STORE_ID",
  "appName": "$NAME",
  "androidPackage": "$PACKAGE",
  "iosBundleId": "$BUNDLE",
  "ownerEmail": "$OWNER",
  "hostingSite": "$PROJECT-$ID",
  "iconBackground": "$COLOR"
}
JSON
cat > "flavors/$ID/dart_defines.json" <<JSON
{ "STORE_ID": "$STORE_ID", "APP_NAME": "$NAME" }
JSON

app_id_from() { grep -oE '1:[0-9]+:(android|ios|web):[0-9a-f]+' | head -1; }

echo "==> 2/5 App Android no Firebase"
ANDROID_APP_ID=$(firebase apps:create ANDROID "$NAME" --package-name "$PACKAGE" \
  --project "$PROJECT" 2>&1 | app_id_from || true)
if [[ -n "$ANDROID_APP_ID" ]]; then
  mkdir -p "android/app/src/$ID"
  firebase apps:sdkconfig ANDROID "$ANDROID_APP_ID" --project "$PROJECT" \
    > "android/app/src/$ID/google-services.json"
  echo "    $ANDROID_APP_ID"
else
  echo "    ⚠ Não consegui criar o app Android (já existe? sem login?)."
fi

echo "==> 3/5 App iOS no Firebase"
IOS_APP_ID=$(firebase apps:create IOS "$NAME" --bundle-id "$BUNDLE" \
  --project "$PROJECT" 2>&1 | app_id_from || true)
if [[ -n "$IOS_APP_ID" ]]; then
  mkdir -p "ios/flavors/$ID"
  firebase apps:sdkconfig IOS "$IOS_APP_ID" --project "$PROJECT" \
    > "ios/flavors/$ID/GoogleService-Info.plist"
  cat > "ios/flavors/$ID/$ID.xcconfig" <<XC
#include "../../Flutter/Release.xcconfig"
PRODUCT_BUNDLE_IDENTIFIER=$BUNDLE
DISPLAY_NAME=$NAME
ASSETCATALOG_COMPILER_APPICON_NAME=AppIcon-$ID
XC
  echo "    $IOS_APP_ID (falta criar o scheme '$ID' no Xcode, num Mac)"
else
  echo "    ⚠ Não consegui criar o app iOS."
fi

echo "==> 4/5 Site de hosting"
SITE="$PROJECT-$ID"
firebase hosting:sites:create "$SITE" --project "$PROJECT" >/dev/null 2>&1 \
  && echo "    https://$SITE.web.app" \
  || echo "    ⚠ Não consegui criar o site $SITE (nome em uso?)."
node -e '
const fs = require("fs");
const [id, site] = process.argv.slice(1);
const cfg = JSON.parse(fs.readFileSync("firebase.json", "utf8"));
const hosting = Array.isArray(cfg.hosting) ? cfg.hosting : (cfg.hosting ? [cfg.hosting] : []);
if (!hosting.some(h => h.target === id)) {
  hosting.push({ target: id, public: `build/web_${id}`,
    ignore: ["firebase.json", "**/.*", "**/node_modules/**"],
    rewrites: [{ source: "**", destination: "/index.html" }] });
}
cfg.hosting = hosting;
fs.writeFileSync("firebase.json", JSON.stringify(cfg, null, 2) + "\n");
' "$ID" "$SITE"
firebase target:apply hosting "$ID" "$SITE" --project "$PROJECT" >/dev/null 2>&1 || true

echo "==> 5/5 Loja no Firestore"
if [[ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" ]]; then
  (cd tool && [[ -d node_modules ]] || npm install --silent)
  node tool/provision_store.js create "$STORE_ID" "$NAME" "$OWNER" "$PLAN"
else
  echo "    ⚠ GOOGLE_APPLICATION_CREDENTIALS não definido. Rode depois:"
  echo "    node tool/provision_store.js create $STORE_ID \"$NAME\" $OWNER $PLAN"
fi

echo "==> 6/6 Ícone do app (logotipo da loja)"
# flutter_launcher_icons lê flutter_launcher_icons-<flavor>.yaml na raiz:
# Android vai para android/app/src/<id>/res, iOS para AppIcon-<id>.
cat > "flutter_launcher_icons-$ID.yaml" <<YAML
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "flavors/$ID/icon.png"
  remove_alpha_ios: true
  background_color_ios: "$COLOR"
  adaptive_icon_background: "$COLOR"
  adaptive_icon_foreground: "flavors/$ID/icon_foreground.png"
YAML
# Web: a pasta web/ é compartilhada; o build web da loja gera os ícones
# dela antes de compilar (tool/build_web_flavor.sh).
cat > "flavors/$ID/web_icons.yaml" <<YAML
flutter_launcher_icons:
  android: false
  ios: false
  image_path: "flavors/$ID/icon.png"
  web:
    generate: true
    image_path: "flavors/$ID/icon.png"
    background_color: "$COLOR"
    theme_color: "$COLOR"
YAML
if [[ -n "$LOGO" && -f "$LOGO" ]]; then
  cp "$LOGO" "flavors/$ID/icon.png"
  # Adaptive icon do Android corta as bordas: usa o mesmo logo, com margem
  # (o ideal é um PNG com 30% de folga em volta).
  cp "$LOGO" "flavors/$ID/icon_foreground.png"
  dart run flutter_launcher_icons -f "flutter_launcher_icons-$ID.yaml"     && echo "    ícones Android/iOS gerados"     || echo "    ⚠ Falha ao gerar ícones (o logo é PNG quadrado ≥ 1024 px?)"
else
  echo "    ⚠ Sem --logo: coloque flavors/$ID/icon.png e icon_foreground.png"
  echo "      (PNG quadrado ≥ 1024 px) e rode:"
  echo "      dart run flutter_launcher_icons -f flutter_launcher_icons-$ID.yaml"
fi

cat <<DONE

Pronto. Próximos passos:
  • Rodar:   flutter run --flavor $ID --dart-define-from-file=flavors/$ID/dart_defines.json
  • Web:     tool/build_web_flavor.sh $ID   (ícones + build)
             firebase deploy --only hosting:$ID
  • Android: flutter build appbundle --flavor $ID --dart-define-from-file=flavors/$ID/dart_defines.json
DONE
