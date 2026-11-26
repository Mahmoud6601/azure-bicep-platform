# Track A: PaaS Deployment & OIDC Setup

## 1. Configure GitHub Actions OIDC (Zero Secrets)
1. Create an Entra ID App Registration + Service Principal and grant it `Contributor` + `User Access Administrator` scoped strictly to your target Resource Group.
2. Add a Federated Credential matching `repo:<owner>/azure-bicep-platform:environment:<env>`.
3. Set GitHub Environment variables: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `AZURE_RESOURCE_GROUP`.

## 2. Deploy & Promote
Run `.github/workflows/deploy-paas.yml` (`dev`, `staging`, or `prod`). On `staging`/`prod`, the workflow pushes to the `staging` slot, executes `scripts/smoke-test.sh`, swaps to `production`, and automatically swaps back if post-swap probes fail.
