#!/usr/bin/env bash
# Deploy Track A (Azure App Service PaaS) using Blue/Green Staging Slot + Smoke Test + Swap.
# Usage: ./scripts/deploy-paas.sh <resource-group> <webapp-name> <acr-login-server> <image-tag> [use-slot:true|false]
set -euo pipefail

RG="${1:-}"
APP="${2:-}"
ACR="${3:-}"
TAG="${4:-}"
USE_SLOT="${5:-true}"

if [ -z "$RG" ] || [ -z "$APP" ] || [ -z "$ACR" ] || [ -z "$TAG" ]; then
  echo "Usage: $0 <resource-group> <webapp-name> <acr-login-server> <image-tag> [use-slot:true|false]" >&2
  exit 1
fi

IMAGE="${ACR}/azure-web-payload:${TAG}"

if [ "$USE_SLOT" = "true" ]; then
  echo "Deploying '${IMAGE}' to '${APP}' staging slot..."
  az webapp config container set --resource-group "$RG" --name "$APP" --slot staging --container-image-name "$IMAGE" >/dev/null
  az webapp restart --resource-group "$RG" --name "$APP" --slot staging >/dev/null

  STAGING_HOST="$(az webapp show --resource-group "$RG" --name "$APP" --slot staging --query defaultHostName -o tsv)"
  bash ./scripts/smoke-test.sh "https://${STAGING_HOST}"

  echo "Swapping staging slot -> production..."
  az webapp deployment slot swap --resource-group "$RG" --name "$APP" --slot staging --target-slot production >/dev/null
else
  echo "Deploying '${IMAGE}' directly to '${APP}' (Basic SKU without slots)..."
  az webapp config container set --resource-group "$RG" --name "$APP" --container-image-name "$IMAGE" >/dev/null
  az webapp restart --resource-group "$RG" --name "$APP" >/dev/null
fi

PROD_HOST="$(az webapp show --resource-group "$RG" --name "$APP" --query defaultHostName -o tsv)"
if ! bash ./scripts/smoke-test.sh "https://${PROD_HOST}"; then
  if [ "$USE_SLOT" = "true" ]; then
    echo "Production smoke test failed — automatically swapping slots back!" >&2
    bash ./scripts/rollback-paas.sh "$RG" "$APP"
  fi
  exit 1
fi

echo "Track A PaaS deployment verified at https://${PROD_HOST}"
