# ADR-0004: Default infrastructure-as-code is Bicep

## Document metadata

| Field | Value |
|---|---|
| Number | 0004 |
| Date | 2026-05-25 |
| Author | Architect (Claude) |
| Approval owner | Product owner |
| Supersedes | None |

## Status

Accepted

## Context

ADR-0001 chose Azure as the default cloud. Every factory project will need a way to provision its Azure footprint reproducibly: storage, App Service Plan, Function App, Static Web App, Key Vault, Application Insights, and a Log Analytics workspace.

Without a default IaC choice, the architect-to-Cursor handoff has a gap: "implement infrastructure" with no scaffold. That gap forces either ad-hoc portal clicks (not reproducible) or a per-project tooling decision (re-litigating each time).

## Decision

Bicep is the factory's default infrastructure-as-code language. The factory ships a starter `templates/infra/main.bicep` covering the default Azure footprint plus an example parameter file.

Bicep is Microsoft's first-party Azure DSL, transpiles to ARM templates, has rich VS Code support, and integrates cleanly with the Azure CLI. It does not introduce a third-party CLI or state file the way Terraform or Pulumi would.

Projects may override with Terraform or Pulumi when they need multi-cloud or already have an investment in either. That choice requires a project-level ADR.

## Alternatives considered

1. Terraform — strong default elsewhere in industry, multi-cloud, mature state management. Not chosen because the factory has already chosen single-cloud Azure (ADR-0001), and Terraform's state file is operational overhead the factory does not need. Also, Bicep avoids a separate provider download and state-locking story for tiny projects.
2. Pulumi — code-as-IaC in TypeScript is appealing given ADR-0003. Not chosen because Pulumi adds a state backend dependency and a paid plan for serious team use. The factory's projects are too small to amortize either.
3. ARM templates directly — Bicep's compile target, but the syntax is hostile and unreadable. Bicep solves the readability problem without losing anything.
4. Portal clicks / scripted Azure CLI — fast to start, awful to reproduce. Not acceptable as the default.

## Consequences

### Positive

- Cursor handoff can reference a concrete starter file; "now what?" disappears.
- No state file to manage. ARM tracks deployment history; `what-if` shows pending changes.
- First-party Microsoft tooling. Patches keep pace with Azure feature releases.
- Bicep modules are easy to add as projects grow.

### Negative

- Single-cloud lock by design. Mitigated by ADR-0001 already choosing Azure.
- Bicep is less known than Terraform across the broader market. Hiring may take an extra day of ramp.

### Neutral

- The Bicep starter is intentionally minimal. Each project adds the right database module after the architecture decides it; a future ADR may move common modules into a shared module catalog.

## Follow-up

- `templates/infra/main.bicep` and `templates/infra/README.md` exist and ship the default footprint.
- Add Azure SQL and Cosmos DB module starters when the second non-marketing project demands one.
- Add a deployment workflow under `.github/workflows/` once a project actually uses it.

## References

- `templates/infra/main.bicep`
- `templates/infra/README.md`
- `docs/adr/0001-default-cloud-azure.md`
