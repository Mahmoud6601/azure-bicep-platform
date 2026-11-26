#!/usr/bin/env bash
# Verify live health, version payload, security headers, and 404 behavior.
# Usage: ./scripts/smoke-test.sh [base-url] [expected-git-sha]
set -euo pipefail

BASE_URL="${1:-https://localhost}"
EXPECTED_SHA="${2:-}"

for i in $(seq 1 20); do
  if curl -kfsS "${BASE_URL}/healthz" | grep -q '"status":"ok"'; then
    break
  fi
  if [ "$i" -eq 20 ]; then
    echo "ERROR: Timed out waiting for ${BASE_URL}/healthz" >&2
    exit 1
  fi
  sleep 2
done

HEADERS="$(curl -kfsSI "${BASE_URL}/")"
echo "$HEADERS" | grep -qi "x-content-type-options: nosniff"
echo "$HEADERS" | grep -qi "x-frame-options: DENY"
echo "$HEADERS" | grep -qi "content-security-policy:"

VERSION_JSON="$(curl -kfsS "${BASE_URL}/version.json")"
echo "Verified ${BASE_URL}: ${VERSION_JSON}"

if [ -n "$EXPECTED_SHA" ] && ! echo "$VERSION_JSON" | grep -q "$EXPECTED_SHA"; then
  echo "ERROR: Expected git_sha '${EXPECTED_SHA}' not found in /version.json." >&2
  exit 1
fi

CODE_404="$(curl -ks -o /dev/null -w '%{http_code}' "${BASE_URL}/nonexistent-probe-path")"
if [ "$CODE_404" != "404" ]; then
  echo "ERROR: Expected 404 for nonexistent path, got ${CODE_404}" >&2
  exit 1
fi

echo "Smoke test passed for ${BASE_URL}."
