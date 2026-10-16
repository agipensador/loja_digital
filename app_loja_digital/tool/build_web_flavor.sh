#!/usr/bin/env bash
# Build web de uma loja: gera os ícones/favicon da loja em web/ e compila
# para build/web_<id> (alvo de hosting criado pelo new_flavor.sh).
# Uso: tool/build_web_flavor.sh <id> [--base-href /loja-da-ju/]
set -euo pipefail
cd "$(dirname "$0")/.."
ID="${1:?Uso: tool/build_web_flavor.sh <id>}"; shift
BASE_HREF="/"
[[ "${1:-}" == "--base-href" ]] && BASE_HREF="$2"
[[ -f "flavors/$ID/flavor.json" ]] || { echo "Flavor $ID não existe."; exit 1; }
NAME=$(node -p "require('./flavors/$ID/flavor.json').appName")
if [[ -f "flavors/$ID/icon.png" ]]; then
  dart run flutter_launcher_icons -f "flavors/$ID/web_icons.yaml"
fi
# Nome do app no manifest e no título da aba.
node -e '
const fs=require("fs");const [name]=process.argv.slice(1);
const m=JSON.parse(fs.readFileSync("web/manifest.json","utf8"));
m.name=name;m.short_name=name.slice(0,12);
fs.writeFileSync("web/manifest.json",JSON.stringify(m,null,2)+"\n");
let h=fs.readFileSync("web/index.html","utf8");
h=h.replace(/<title>[^<]*<\/title>/,"<title>"+name+"</title>")
   .replace(/(apple-mobile-web-app-title" content=")[^"]*/,"$1"+name);
fs.writeFileSync("web/index.html",h);' "$NAME"
flutter build web --release --base-href "$BASE_HREF" \
  --dart-define-from-file="flavors/$ID/dart_defines.json" \
  --output "build/web_$ID"
echo "Pronto: build/web_$ID → firebase deploy --only hosting:$ID"
