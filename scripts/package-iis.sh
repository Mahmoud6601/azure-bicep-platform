#!/usr/bin/env bash
# Package deterministic Track B IIS static bundle + SHA-256 checksum.
# Usage: ./scripts/package-iis.sh [version] [git-sha] [environment]
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-local-dev}"
GIT_SHA="${2:-$(git rev-parse --short=7 HEAD 2>/dev/null || echo local)}"
ENVIRONMENT="${3:-dev}"
BUILT_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

STAGE_DIR="dist/iis/stage-${VERSION}"
OUT_ZIP="dist/iis/site-${VERSION}.zip"

rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"
cp -R site/public/* "$STAGE_DIR/"
cp site/iis/web.config "$STAGE_DIR/web.config"

printf '{"version":"%s","git_sha":"%s","deployment_track":"iaas-iis","environment":"%s","built_at":"%s"}\n' \
  "$VERSION" "$GIT_SHA" "$ENVIRONMENT" "$BUILT_AT" > "$STAGE_DIR/version.json"

(cd "$STAGE_DIR" && zip -rq "../site-${VERSION}.zip" .)
sha256sum "$OUT_ZIP" > "${OUT_ZIP}.sha256"

echo "Packaged IIS release: ${OUT_ZIP}"
echo "Checksum written:     ${OUT_ZIP}.sha256"
