# Day-2 Operations & Recovery Runbook

## 1. Track A (PaaS) Instant Rollback
```bash
./scripts/rollback-paas.sh <resource-group> <webapp-name>
```
Swaps `staging` and `production` slots back immediately and runs `scripts/smoke-test.sh`.

## 2. Track B (IaaS) Atomic IIS Rollback
Execute via `az vm run-command invoke` (no RDP required):
```powershell
.\infra\iaas\scripts\rollback-iis.ps1
# Or specify an explicit prior version folder:
.\infra\iaas\scripts\rollback-iis.ps1 -TargetVersion sha-a1b2c3d
```

## 3. Resource Group & VM Backup Recovery
- Resource Group config snapshot: `./scripts/backup-azure.sh <rg>` / `./scripts/restore-azure.sh <rg> <file.json.gz>`
- IaaS VM disk/system restore: Restore point-in-time snapshot from the provisioned **Recovery Services Vault** (`<prefix>-rsv`) in Azure Backup.
