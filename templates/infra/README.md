# Infrastructure (Bicep)

This directory holds the factory's default Bicep starter for Azure. It is intentionally minimal: enough to host a typical factory project, no more. Add modules or extend `main.bicep` per project needs and record substantial decisions as ADRs.

See `docs/adr/0004-default-iac-bicep.md` for the decision and trade-offs that led to Bicep.

## What this deploys

- Log Analytics workspace
- Application Insights tied to the workspace
- Storage account (Functions backend, no public blob access, TLS 1.2 min)
- Linux App Service Plan, Consumption Y1
- Function App on Node 20 with system-assigned managed identity
- Static Web App, Standard tier
- Key Vault, RBAC mode, soft delete on, purge protection in prod
- Role assignments so the Function App can read Key Vault secrets and use storage with AAD auth

Intentionally not included: any database. The architect picks Azure SQL, Cosmos DB, or PostgreSQL per project and adds the matching module. The choice should be backed by an ADR.

## Prerequisites

- Azure CLI 2.55+
- Bicep CLI installed (`az bicep install`)
- Logged in to the right subscription (`az login`, then `az account set --subscription <id>`)

## Deploy

```bash
# Create the resource group once.
az group create --name myapp-dev-rg --location eastus

# Deploy.
az deployment group create \
  --resource-group myapp-dev-rg \
  --template-file main.bicep \
  --parameters main.bicepparam
```

## Per-environment parameter files

The recommended pattern is one parameter file per environment, checked into source control:

```text
main.bicepparam          # dev (or copy as needed)
main.dev.bicepparam
main.staging.bicepparam
main.prod.bicepparam
```

Never put real secrets in parameter files. Secrets live in Key Vault and are referenced from the app at runtime via managed identity.

The database default is PostgreSQL (see `docs/adr/0007-default-database-postgres-then-sql-then-cosmos.md`). When the first real project needs it, add a `postgres.bicep` (under a future `modules/` subdirectory) module wired into `main.bicep` behind an `enablePostgres` parameter. Until then this directory ships without a database module on purpose: speculative modules go stale fast.

## What lives outside this file

- Database resources (project-specific)
- Custom domains and TLS certificates (typically configured post-deploy)
- Stripe / Plaid / Postmark accounts (not Azure resources)
- GitHub Actions deployment workflow (see `.github/workflows/`)

## Validating before deploy

```bash
az deployment group what-if \
  --resource-group myapp-dev-rg \
  --template-file main.bicep \
  --parameters main.bicepparam
```

`what-if` shows exactly what will change. Always run it before a production deploy.
