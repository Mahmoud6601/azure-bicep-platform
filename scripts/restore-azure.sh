#!/usr/bin/env bash
# Verify and re-apply a checksummed Azure Resource Group template backup.
# Usage: ./scripts/restore-azure.sh <resource-group> <backups/.../rg-export-*.json.gz>
set -euo pipefail
cd "$(dirname "$0")/.."

RG="${1:-}"
BACKUP_FILE="${2:-}"

if [ -z "$RG" ] || [ -z "$BACKUP_FILE" ] || [ ! -f "$BACKUP_FILE" ]; then
  echo "Usage: $0 <resource-group> <backup-file.json.gz>" >&2
  exit 1
fi

if [ -f "${BACKUP_FILE}.sha256" ]; then
  sha256sum -c "${BACKUP_FILE}.sha256"
fi

if [ "${RESTORE_FORCE:-0}" != "1" ]; then
  read -r -p "Run what-if and restore '${BACKUP_FILE}' into resource group '${RG}'? [y/N] " answer
  case "$answer" in
    y|Y|yes|YES) ;;
    *) echo "Aborted."; exit 1 ;;
  esac
fi

TMP_JSON="$(mktemp)"
trap 'rm -f "$TMP_JSON"' EXIT
gunzip -c "$BACKUP_FILE" > "$TMP_JSON"

az deployment group what-if --resource-group "$RG" --template-file "$TMP_JSON"
az deployment group create --resource-group "$RG" --template-file "$TMP_JSON"
echo "Azure Resource Group restore complete."
