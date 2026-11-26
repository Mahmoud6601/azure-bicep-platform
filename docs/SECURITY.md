# Azure Security Controls

- **Zero Publish Profiles / Zero Client Secrets:** GitHub Actions authenticates to Azure via OIDC federated tokens (`azure/login@v2`).
- **Managed Identities Everywhere:** App Service uses `AcrPull` (ACR admin user disabled); IaaS VM uses `Storage Blob Data Reader` (Storage shared key access disabled).
- **TLS 1.2+ & Strict Headers:** Enforced identically on App Service (`httpsOnly`, `minTlsVersion: '1.2'`, `ftpsState: 'Disabled'`), Nginx (`site/nginx/default.conf`), and IIS (`site/iis/web.config` + `configure-iis.ps1` SCHANNEL hardening).
- **Zero Public RDP:** IaaS VM has no public IP, Trusted Launch (Secure Boot + vTPM) is enabled, and `iaas-nsg` explicitly denies TCP 3389 from `Internet`.
- **Automated Policy Scanning:** `bicepconfig.json`, `ps-rule.yaml` (PSRule for Azure), Trivy Config/Image scans, PSScriptAnalyzer, Hadolint, and Gitleaks run on every PR.
