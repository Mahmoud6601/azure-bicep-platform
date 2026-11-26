#!/usr/bin/env bash
# Instant 1-command PaaS rollback via Azure App Service slot swap-back.
# Usage: ./scripts/rollback-paas.sh <resource-group> <webapp-name>
set -euo pipefail

RG="${1:-}"
APP="${2:-}"

if [ -z "$RG" ] || [ -z "$APP" ]; then
  echo "Usage: $0 <resource-group> <webapp-name>" >&2
  exit 1
fi

echo "Swapping production and staging slots back on '${APP}'..."
az webapp deployment slot swap --resource-group "$RG" --name "$APP" --slot staging --target-slot production >/dev/null

PROD_HOST="$(az webapp show --resource-group "$RG" --name "$APP" --query defaultHostName -o tsv)"
bash ./scripts/smoke-test.sh "https://${PROD_HOST}"
echo "Rollback complete and verified on https://${PROD_HOST}."
