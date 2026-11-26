# Track B: Zero-RDP IaaS Windows Server IIS Guide

1. Provision Track B infrastructure via `.github/workflows/deploy-iaas.yml` (`deploymentTrack=iaas`). The VM has **zero public IP** and **zero public RDP**.
2. Run `infra/iaas/scripts/configure-iis.ps1` once via Azure Custom Script Extension or `az vm run-command invoke` to install IIS, disable TLS 1.0/1.1, and initialize `C:\inetpub\releases\`.
3. Each release packages `site/public/*` + `site/iis/web.config` + build-stamped `version.json` into a versioned ZIP + `.sha256` via `scripts/package-iis.sh`, uploads to private Blob Storage, and executes `deploy-iis-release.ps1` via `az vm run-command invoke`.
4. For interactive troubleshooting, connect privately via **Azure Bastion** (never open port 3389 to the internet).
