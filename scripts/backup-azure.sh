#!/usr/bin/env bash
# Export Azure Resource Group template & App Service configuration backup with SHA-256 checksum.
# Usage: ./scripts/backup-azure.sh <resource-group>
set -euo pipefail
cd "$(dirname "$0")/.."

RG="${1:-}"
if [ -z "$RG" ]; then
  echo "Usage: $0 <resource-group>" >&2
  exit 1
fi

TIMESTAMP="$(date -u +%Y%m%d-%H%M%SZ)"
OUT_DIR="backups/${RG}"
OUT_FILE="${OUT_DIR}/rg-export-${TIMESTAMP}.json.gz"
mkdir -p "$OUT_DIR"

echo "Exporting Azure Resource Group '${RG}' snapshot..."
az group export --name "$RG" | gzip -c > "$OUT_FILE"
sha256sum "$OUT_FILE" > "${OUT_FILE}.sha256"

echo "Backup complete: ${OUT_FILE}"
echo "Restore verify:  ./scripts/restore-azure.sh ${RG} ${OUT_FILE}"
