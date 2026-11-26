# Architecture & Dual-Track Design

This platform models the exact same static verification payload across two production Azure hosting patterns so engineers can compare operational overhead, security boundaries, rollback mechanics, and cost side-by-side:

1. **Track A (PaaS):** Linux Container App Service pulling immutable SHA-tagged images from ACR via System-Assigned Managed Identity (`AcrPull`, ACR admin user disabled), integrated with VNet, Key Vault (RBAC), and Log Analytics/App Insights. Standard (`S1`) and Premium (`P1v3`) plans automatically provision a `staging` deployment slot for zero-downtime swaps.
2. **Track B (IaaS):** Windows Server 2022 Datacenter Azure Edition VM inside a private VNet subnet (`snet-iaas-web`) with **no public IP** and an NSG explicitly denying public RDP (3389). Inbound HTTPS terminates behind a Standard Azure Load Balancer probing `/health.json`. Releases are pulled as SHA-256-verified ZIP archives from private Blob Storage via Managed Identity and switched atomically under `C:\inetpub\releases\`.
