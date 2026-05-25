# ADR-0005: Factory scope is greenfield projects only

## Document metadata

| Field | Value |
|---|---|
| Number | 0005 |
| Date | 2026-05-25 |
| Author | Architect (Claude) |
| Approval owner | Product owner |
| Supersedes | None |

## Status

Accepted

## Context

The factory's blueprints, templates, examples, and quality gates are written assuming a fresh project: no legacy database to migrate, no existing API surface to preserve, no production traffic to dark-launch behind. Trying to cover brownfield work — strangler-fig adoption, data migrations, dark launches, cutover plans — would double the surface area of the factory without making greenfield work better.

For the project owner's actual delivery pipeline, greenfield projects are the dominant case. Brownfield evolutions exist but are rare and tend to need bespoke attention regardless of which factory generated the original system.

## Decision

The AI App Factory targets greenfield projects only.

Existing systems that need significant evolution are out of scope. The factory does not ship a brownfield blueprint, a migration template, or strangler-fig patterns.

A factory-generated project that later needs to evolve is a separate question and the architect should approach that evolution as its own design problem, not as a factory output.

## Alternatives considered

1. Cover both greenfield and brownfield in v1 — doubles surface area; dilutes the worked examples; the brownfield work tends to need so much project-specific context that a generic template is low-value.
2. Add a brownfield blueprint in a future version — possible but not committed. Re-open this ADR when there is a real project that warrants the investment.
3. Pretend the factory is general-purpose and let users discover the brownfield gap themselves — wastes the user's time on a problem this factory cannot solve.

## Consequences

### Positive

- Blueprints can assume a clean slate. Architecture diagrams do not need to show the legacy system.
- Quality gates are simpler: there is no "legacy regression suite" to keep green.
- Worked examples (marketing site, Stripe subscription, Plaid dashboard) stay focused.

### Negative

- Real-world projects that mix greenfield work with brownfield touches still need bespoke design work outside the factory.
- The factory's value to mature engineering organizations with large legacy estates is limited.

### Neutral

- The factory's principles (small vertical slices, business-first design, secure-by-default) apply equally to brownfield work — just without the factory's scaffolding.

## Follow-up

- `README.md` and `OPERATING_MODEL.md` state the greenfield-only scope explicitly.
- Revisit this ADR if a real brownfield project surfaces and demands a blueprint.

## References

- `README.md`
- `OPERATING_MODEL.md`
