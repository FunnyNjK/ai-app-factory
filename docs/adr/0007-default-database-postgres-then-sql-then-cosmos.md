# ADR-0007: Default database is PostgreSQL, then Azure SQL, then Cosmos DB

## Document metadata

| Field | Value |
|---|---|
| Number | 0007 |
| Date | 2026-05-25 |
| Author | Architect (Claude) |
| Approval owner | Product owner |
| Supersedes | None — refines the "Azure SQL or Cosmos DB" placeholder in earlier blueprints |

## Status

Accepted

## Context

ADR-0001 chose Azure as the default cloud. ADR-0003 chose TypeScript as the default language. ADR-0004 chose Bicep as the default IaC. Each factory project then needs a database, and the prior blueprints punted with "Azure SQL or Cosmos DB" — leaving every new project to re-derive a real architectural decision from scratch.

The factory's typical project is a small full-stack web app with authenticated users, a handful of relational entities, occasional JSON columns, low single-region traffic, and a strong preference for portable tooling. The factory's blueprints (full-stack web app, Stripe subscription, Plaid personal finance) all fit this shape.

A factory-level default with a clear fallback order removes the rederivation tax and lets the Bicep starter ship a real database module behind a single parameter.

## Decision

Factory projects use this database preference order. Pick the first one that fits; document the choice (and any non-default pick) in the project's `ARCHITECTURE.md`.

1. **PostgreSQL — default for relational work.** Azure Database for PostgreSQL Flexible Server is the deployment target. Local development uses a standard `postgres:16` container.
2. **Azure SQL Database — when first-party Azure SQL is required.** Choose this when the team has existing T-SQL expertise, an established `.bacpac` ecosystem, or a tight requirement to use Azure-native SQL Server features.
3. **Cosmos DB — when the data is document-shaped, key-value, or genuinely global.** Choose this only when relational queries are not central, when document storage is the natural fit, or when global multi-region active-active is a hard requirement.

A project that picks anything other than PostgreSQL records the reason in its `ARCHITECTURE.md` and, where the choice is non-trivial, creates a project-local ADR explaining the deviation.

## Alternatives considered

1. Azure SQL as the default — strong managed offering with first-party tooling. Not chosen because it locks projects to a Microsoft licensing surface, has weaker portability if a project ever needs to move clouds, and pushes most teams toward T-SQL idioms that JavaScript/TypeScript-first developers do not natively use.
2. Cosmos DB as the default — appealing for serverless billing and global scale. Not chosen because most factory projects are small, single-region, relational, and would pay a real complexity cost (modeling, indexing, query patterns) to get features they will not use.
3. SQLite for everything — fine for the smallest projects, painful when concurrency or managed backups become real requirements. Not a credible production default.
4. MongoDB or another non-Azure document store — adds a non-Azure operational dependency without enough offsetting benefit given ADR-0001.
5. Leave the choice open per project (status quo) — produces the rederivation tax the factory exists to remove.

## Consequences

### Positive

- Bicep can ship a default Postgres module behind a parameter, so the Cursor handoff has a real database baseline.
- TypeScript ORMs (Prisma, Drizzle) are first-class on Postgres; tooling, types, and migration ergonomics are excellent.
- JSONB columns cover the cases where projects need light document storage without introducing a second data store.
- Local development with Docker Postgres matches production behavior closely.
- Cost is predictable and low at small scale; Flexible Server Burstable B1ms is roughly $13/month.

### Negative

- Projects with existing Azure SQL investment pay a small migration cost to align. Mitigated by the explicit fallback to Azure SQL in this ADR.
- Postgres on Azure is a third-party engine on Azure infrastructure; some Azure-native integrations (Synapse Link, etc.) are weaker than Azure SQL or Cosmos. Acceptable given the factory's target project shape.

### Neutral

- Cosmos DB stays in the toolbox for the projects that need it. The factory does not eliminate it, just stops defaulting to it.
- Schema migration tooling is project-specific. The factory does not pick between Prisma Migrate, Drizzle Kit, and node-pg-migrate; the choice is documented in `coding-standards.md` over time.

## Follow-up

- [ ] Add a `postgres.bicep` (under `templates/infra/modules/`) module wired into `templates/infra/main.bicep` behind an `enablePostgres` parameter. Defer until the first real project that needs it; the module should not be speculative.
- [x] Update `blueprints/full-stack-web-app.md`, `blueprints/stripe-app.md`, and `blueprints/plaid-app.md` to reference this ADR and to drop the "Azure SQL or Cosmos DB" hedge.
- [ ] Pick a default migration tool and record it in `standards/coding-standards.md` after a project actually runs the migration path. Likely Drizzle Kit given the TypeScript-first stack.
- [ ] Add an Azure SQL Bicep module when a project surfaces that needs it. Same rule: ship modules driven by real demand, not anticipation.

## References

- `docs/adr/0001-default-cloud-azure.md`
- `docs/adr/0003-default-language-typescript.md`
- `docs/adr/0004-default-iac-bicep.md`
- `templates/infra/main.bicep`
- `blueprints/full-stack-web-app.md`
