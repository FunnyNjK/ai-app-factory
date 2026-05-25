# ADR-0001: Default cloud is Azure

## Document metadata

| Field | Value |
|---|---|
| Number | 0001 |
| Date | 2026-05-25 |
| Author | Architect (Claude) |
| Approval owner | Product owner |
| Supersedes | None |

## Status

Accepted

## Context

The factory needs a single default cloud provider so that blueprints, templates, IaC starters, observability defaults, and worked examples can be specific instead of abstract. Without a default, every project starts with a multi-week "which cloud" detour and the factory's standards cannot ship concrete tooling.

The project owner already operates inside Azure for unrelated workloads and has Azure credentials, billing, and tooling in place. Reusing that environment shortens time-to-first-deploy substantially.

## Decision

Azure is the factory's default cloud. Blueprints, templates, and worked examples are written for Azure-native services first (Static Web Apps, Functions, SQL or Cosmos, Storage, Key Vault, Application Insights, Log Analytics).

This is a default, not a hard requirement. Individual projects may choose another cloud when constraints justify it; doing so requires a project-level ADR that names the cloud, the reason, and the replacement defaults for hosting, secrets, and observability.

## Alternatives considered

1. AWS — equally capable. Not chosen because the project owner does not run other workloads there; the integration tax (billing, identity, tooling, runbook know-how) would be paid on every project for no offsetting benefit.
2. GCP — same reasoning as AWS.
3. Cloud-agnostic with no default — produces blueprints full of "pick your provider" placeholders, which is exactly what the factory is meant to remove.
4. Multi-cloud per project — encourages design complexity that is rarely justified for the small projects this factory targets.

## Consequences

### Positive

- Blueprints can name specific services and price points.
- IaC starter, Bicep templates, and Application Insights defaults can ship as code, not prose.
- Runbooks reference concrete portal locations and CLI commands.
- New contributors learn one cloud well rather than three superficially.

### Negative

- Projects that should run elsewhere will pay a small migration cost (template rewrites, ADR overhead).
- Vendor lock-in to Azure-specific services. Mitigated by preferring services with portable interfaces (managed Postgres over Cosmos when relational fits, Stripe and Postmark over Azure-equivalent services).

### Neutral

- The factory's role files (Claude, Cursor, Codex) are unchanged. They reference "the cloud" generically; only the standards, blueprints, and IaC starter encode the Azure choice.

## Follow-up

- Bicep IaC starter exists at `templates/infra/main.bicep` (see ADR-0004).
- Application Insights defaults are codified in `standards/observability-standards.md`.
- Cost shapes for the default Azure footprint feed `templates/COST_ESTIMATE.md`.

## References

- `OPERATING_MODEL.md` — references Azure as the default cloud.
- `blueprints/full-stack-web-app.md` — names Azure services explicitly.
