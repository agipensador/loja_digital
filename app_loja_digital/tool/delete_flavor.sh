#!/usr/bin/env bash
# Remove o app de uma loja (flavor).
#
# Uso: tool/delete_flavor.sh <id> [--purge-data]
#
# Padrão (seguro): remove os arquivos do flavor, o site de hosting e
# DESATIVA a loja no Firestore (dados e pedidos ficam guardados).
# --purge-data: também APAGA os dados da loja e as fotos — irreversível,
# pede uma segunda confirmação.
set -euo pipefail
cd "$(dirname "$0")/.."

PROJECT="${FIREBASE_PROJECT:-loja-digital-ju0714}"
ID="${1:-}"
PURGE="${2:-}"
[[ -z "$ID" ]] && { echo "Uso: tool/delete_flavor.sh <id> [--purge-data]"; exit 1; }
[[ -f "flavors/$ID/flavor.json" ]] || { echo "Flavor $ID não encontrado."; exit 1; }

STORE_ID=$(node -e 'console.log(require("./flavors/'"$ID"'/flavor.json").storeId)')
NAME=$(node -e 'console.log(require("./flavors/'"$ID"'/flavor.json").appName)')
SITE=$(node -e 'console.log(require("./flavors/'"$ID"'/flavor.json").hostingSite)')

echo "Vai remover o app \"$NAME\" (flavor $ID, loja $STORE_ID)."
read -r -p "Confirma que quer deletar $ID? Digite o nome do flavor para confirmar: " ANSWER
[[ "$ANSWER" == "$ID" ]] || { echo "Cancelado."; exit 1; }

if [[ "$PURGE" == "--purge-data" ]]; then
  read -r -p "ATENÇÃO: os dados, pedidos e fotos da loja serão APAGADOS para sempre. Digite APAGAR para continuar: " ANSWER2
  [[ "$ANSWER2" == "APAGAR" ]] || { echo "Cancelado."; exit 1; }
fi

echo "==> Site de hosting"
firebase hosting:sites:delete "$SITE" --project "$PROJECT" --force >/dev/null 2>&1 \
  && echo "    $SITE removido" || echo "    ⚠ Não consegui remover $SITE (já removido?)."
node -e '
const fs = require("fs");
const id = process.argv[1];
const cfg = JSON.parse(fs.readFileSync("firebase.json", "utf8"));
if (Array.isArray(cfg.hosting)) cfg.hosting = cfg.hosting.filter(h => h.target !== id);
fs.writeFileSync("firebase.json", JSON.stringify(cfg, null, 2) + "\n");
' "$ID"
firebase target:clear hosting "$ID" --project "$PROJECT" >/dev/null 2>&1 || true

echo "==> Loja no Firestore"
if [[ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" ]]; then
  (cd tool && [[ -d node_modules ]] || npm install --silent)
  if [[ "$PURGE" == "--purge-data" ]]; then
    node tool/provision_store.js purge "$STORE_ID"
  else
    node tool/provision_store.js deactivate "$STORE_ID"
  fi
else
  echo "    ⚠ GOOGLE_APPLICATION_CREDENTIALS não definido: a loja NÃO foi desativada."
fi

echo "==> Arquivos do flavor"
rm -rf "flavors/$ID" "android/app/src/$ID" "ios/flavors/$ID" "build/web_$ID"
echo "    removidos"

cat <<DONE

Feito. Falta (o Firebase CLI não remove apps registrados):
  • Console Firebase → Configurações do projeto → apague os apps Android/iOS
    de "$NAME" (não geram custo se ficarem).
  • Play Console / App Store Connect: despublicar o app, se estiver no ar.
DONE
