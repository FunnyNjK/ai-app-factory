# Cost Estimate

## Project name

`TODO`

## Document metadata

| Field | Value |
|---|---|
| Owner | Architect |
| Status | Draft / Reviewed / Approved |
| Currency | `TODO` (default USD) |
| Estimate horizon | `TODO` (default monthly) |
| Last updated | `TODO` |
| Assumptions reviewed by | `TODO` |

---

## 1. Workload assumptions

State the load assumptions the estimate depends on. If these change materially, redo the estimate.

| Assumption | Value | Source |
|---|---|---|
| Monthly active users | `TODO` | `TODO` |
| Monthly requests | `TODO` | `TODO` |
| Monthly transactional emails | `TODO` | `TODO` |
| Average database size | `TODO` | `TODO` |
| Webhook events per month | `TODO` | `TODO` |
| Peak concurrency | `TODO` | `TODO` |

---

## 2. Recurring infrastructure

Itemize every paid component. Use the cheapest plausible tier first; the architecture review can upgrade individual line items with justification.

| Component | Tier / SKU | Monthly cost (low) | Monthly cost (expected) | Monthly cost (high) | Notes |
|---|---|---:|---:|---:|---|
| Azure Static Web Apps | Standard | `TODO` | `TODO` | `TODO` | `TODO` |
| Azure Functions (Consumption Y1) | Consumption | `TODO` | `TODO` | `TODO` | First 1M executions free per month |
| Azure SQL Database / Cosmos DB | `TODO` | `TODO` | `TODO` | `TODO` | `TODO` |
| Azure Storage | `TODO` | `TODO` | `TODO` | `TODO` | `TODO` |
| Azure Key Vault | Standard | `TODO` | `TODO` | `TODO` | First 10k operations cheap |
| Application Insights | `TODO` | `TODO` | `TODO` | `TODO` | Volume-based; cap ingestion in non-prod |
| Log Analytics Workspace | Pay-as-you-go | `TODO` | `TODO` | `TODO` | Retention drives cost |
| Custom domain + certificate | `TODO` | `TODO` | `TODO` | `TODO` | Often free with SWA |

---

## 3. External providers

Per-transaction or per-unit costs from third parties.

| Provider | Pricing model | Expected monthly cost | Notes |
|---|---|---:|---|
| Postmark | Per email | `TODO` | `TODO` |
| Stripe | 2.9% + $0.30 per transaction | `TODO` | Adjust for actual transaction mix |
| Plaid | Per-Item or per-API-call | `TODO` | Sandbox is free; development tier billed |
| Auth provider (Auth0 / Clerk / Entra) | Per MAU | `TODO` | `TODO` |

---

## 4. One-time costs

| Item | Cost | Notes |
|---|---:|---|
| Domain registration | `TODO` | `TODO` |
| Penetration test | `TODO` | If applicable |
| Stripe / Plaid activation | `TODO` | Usually zero |

---

## 5. Total

| Scenario | Monthly cost |
|---|---:|
| Low usage (idle baseline) | `TODO` |
| Expected usage at v1 success criteria | `TODO` |
| High / stress scenario (5x expected) | `TODO` |

---

## 6. Cost-control levers

What knobs exist if the bill is higher than planned?

- Application Insights ingestion sampling
- Log Analytics retention
- Function App always-on vs consumption
- Postmark message stream consolidation
- Database SKU step-down
- CDN cache TTLs

---

## 7. Re-estimate triggers

This estimate must be revisited when any of the following happen:

- Monthly active users exceeds the assumption above by 50%
- A new external integration is added
- A new Azure region is added
- The architecture changes a major component (database swap, hosting model swap)
- 90 days have passed since the last estimate

---

## 8. Open questions

| Question | Owner | Needed by |
|---|---|---|
| `TODO` | `TODO` | `TODO` |
