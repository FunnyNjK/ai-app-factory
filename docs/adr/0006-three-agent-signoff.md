# ADR-0006: Release readiness requires three-agent and team sign-off

## Document metadata

| Field | Value |
|---|---|
| Number | 0006 |
| Date | 2026-05-25 |
| Author | Architect (Claude) |
| Approval owner | Product owner |
| Supersedes | Partial — refines Gate D in `OPERATING_MODEL.md` |

## Status

Superseded by [ADR-0013](0013-configurable-roles-and-tools.md). The principle stands — Gate D requires independent agent sign-offs plus the human product owner — but the team grew from three agents to five (architect, developer, quality engineer, security, code review), making Gate D a six-party sign-off.

## Context

The factory had four quality gates (A → D), with Gate D being "release candidate ready." Gate D listed a set of checks (tests pass, integrations verified, monitoring reviewed, rollback documented) but did not name who declares the project complete. In practice, that left the call to whichever agent or human happened to be in the room.

The project owner has named a clearer success definition: a project is successful when all three agents — Claude, Cursor, Codex — sign off, and the human team also concurs.

## Decision

Gate D is reframed as a four-party sign-off. A factory-generated project is release-ready only when each of the following four parties has signed off in writing inside the PR or release artifact:

1. **Claude (Architect)** — confirms the implementation matches the approved architecture, that no silent design deviations exist, and that any deviations are documented as ADRs or design notes.
2. **Cursor (Developer)** — confirms the implementation meets every acceptance criterion, tests pass, no hard-coded secrets exist, and the runbook and README are up to date.
3. **Codex (Quality Engineer)** — confirms the test plan was executed, critical user journeys pass, security and accessibility smoke checks pass, and the release readiness decision is "Ready" or "Ready with documented risks."
4. **Human team (Product owner / technical owner)** — confirms the work satisfies the business intent, accepts any documented risks, and authorizes release.

A project is not "successful" until all four sign off. A project is not "shippable" if any one of the four declines. If an agent declines, the agent's responsibility is to name the specific blocker and route it back to the appropriate owner; vague concerns are not blockers.

## Alternatives considered

1. Architect-only sign-off — too narrow; misses implementation and quality concerns the architect did not observe.
2. Codex-only sign-off — too narrow; misses the architectural integrity Claude is responsible for.
3. Human-only sign-off — already required, but does not exploit the value of three specialist agents.
4. Majority vote of the three agents — encourages a hung jury and removes accountability. Unanimity is the right default for a small team.

## Consequences

### Positive

- A single, consistent definition of "done" across every factory project.
- Forces each agent to state its position explicitly, surfacing disagreements early.
- The team retains final authority.

### Negative

- A blocked sign-off can stall a release. Mitigated by the rule that the declining party must name a specific blocker.
- More signal-collection overhead per release. Mitigated by the PR template providing a single checklist.

### Neutral

- The factory's "Release Readiness Review" produced by Codex is unchanged in format; it is now framed as one of four required sign-offs.

## Follow-up

- `OPERATING_MODEL.md` Gate D updated to require the four sign-offs.
- `.github/pull_request_template.md` includes a four-party sign-off checklist.
- Each role file (`CLAUDE.md`, `AGENTS.md`, `.cursor/rules/ai-app-factory-developer.mdc`) names that role's specific sign-off responsibility.

## References

- `OPERATING_MODEL.md` — Quality Gates section
- `.github/pull_request_template.md`
- `CLAUDE.md`, `AGENTS.md`, `.cursor/rules/ai-app-factory-developer.mdc`
