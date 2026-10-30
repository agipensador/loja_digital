#!/usr/bin/env bash
# Atalho antigo, mantido porque o new_flavor.sh e o ARQUITETURA_SAAS.md
# apontam para cá. O build web da loja agora é o tool/build_web.dart:
# tem teste, gera os ícones da PWA a partir do logotipo da loja e NÃO
# reescreve a pasta web/ do repositório (o que fazia a última loja compilada
# vazar para a próxima). Receita completa: docs/PUBLICAR_WEB.md.
#
# Uso: tool/build_web_flavor.sh <storeId> [--base-href /loja-da-ju/]
#      (storeId, com underscore: loja_ju — não o id do flavor do Gradle)
set -euo pipefail
cd "$(dirname "$0")/.."
ID="${1:?Uso: tool/build_web_flavor.sh <storeId> [--base-href /slug/]}"
shift
exec dart run tool/build_web.dart "$ID" "$@"
