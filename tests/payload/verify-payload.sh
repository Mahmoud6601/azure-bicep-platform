#!/usr/bin/env bash
# Verify static payload hygiene, JSON/XML validity, CSP compliance, and zero template/PII leftovers.
set -euo pipefail
cd "$(dirname "$0")/../.."

echo "==> Checking JSON payload files..."
jq -e '.status == "ok"' site/public/health.json >/dev/null
jq -e '.version and .git_sha and .deployment_track' site/public/version.json >/dev/null

echo "==> Checking IIS web.config XML well-formedness..."
if command -v xmllint >/dev/null 2>&1; then
  xmllint --noout site/iis/web.config
fi

echo "==> Checking zero inline scripts and zero template/email leftovers..."
if grep -Eqi '<script[^>]*>[^<]+' site/public/index.html; then
  echo "ERROR: Inline script detected in site/public/index.html (violates strict CSP)." >&2
  exit 1
fi

if grep -Eriq '(Tooplate|Praesent tellus|info@company\.com|gmail\.com|#544639|#FC6)' site/; then
  echo "ERROR: Template debris or third-party email detected in site/." >&2
  exit 1
fi

echo "Payload verification passed."
