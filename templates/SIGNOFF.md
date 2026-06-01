# Gate D Sign-off Notes

This template captures the six short written sign-offs required at Gate D (see `OPERATING_MODEL.md` and `docs/adr/0013-configurable-roles-and-tools.md`, which supersedes the three-agent model of `docs/adr/0006-three-agent-signoff.md`). Each of the five agent roles writes one note; the product owner writes the sixth. All six live in the PR description or the release artifact and must reference the artifacts they reviewed.

Section headings are role-anchored and tool-agnostic — the role (Architect, Developer, …) is the sign-off, regardless of which tool the project mapped to that role in `.factory-roles.json`. The signer line carries the role's configured name.

Keep each sign-off short. A sign-off is a paragraph plus a checklist, not a report.

---

## Architect sign-off

**Decision:** Approved | Approved with notes | Blocked

**What I reviewed:**

- `ARCHITECTURE.md` against the implemented system
- ADRs in `docs/adr/` (and any project-local ADRs)
- `THREAT_MODEL.md` against the implementation (if required)
- `COST_ESTIMATE.md` against the live cost shape after a representative load
- Observability defaults from `standards/observability-standards.md`

**Notes:**

Describe in 2–6 sentences what convinced you to approve, or what is blocking. Link any deviations to the ADR that covers them.

**Signed:** `<name>` (architect) — `YYYY-MM-DD`

---

## Developer sign-off

**Decision:** Approved | Approved with notes | Blocked

**What I reviewed:**

- Acceptance criteria from the architect handoff
- Test suite results (unit, integration, E2E)
- `.env.example` and the built bundle for secret leakage
- `README.md` and `RUNBOOK.md` against the current implementation
- Any escalation trails or design deviations raised during build

**Notes:**

Describe in 2–6 sentences. Name any known limitations and where they are documented. If approval is conditional, name the condition.

**Signed:** `<name>` (developer) — `YYYY-MM-DD`

---

## Quality Engineer sign-off

**Decision:** Ready | Ready with documented risks | Not ready

**What I reviewed:**

- `TEST_PLAN.md` execution results
- Critical user journeys against the running system
- Security smoke checks (secret scan, webhook verification, auth)
- Accessibility baseline (keyboard, labels, focus, contrast)
- Observability signal during a representative end-to-end run

**Notes:**

Describe in 2–6 sentences. If "Ready with documented risks," link each risk explicitly. Name the residual coverage gaps.

**Signed:** `<name>` (quality engineer) — `YYYY-MM-DD`

---

## Security sign-off

**Decision:** Pass | Pass with documented risks | Fail

**What I reviewed:**

- `SECURITY.md` and `THREAT_MODEL.md` (if present) against the implementation
- The per-phase security gate results in `TASKS.md`
- Secret scanning of the tree (no secrets beyond `.env.example` placeholders)
- Input validation, authorization, and webhook verification where applicable
- Dependency risk and unsafe file/network/shell behavior

**Notes:**

Describe in 2–6 sentences. If "Pass with documented risks," link each risk explicitly and name its owner and re-review date.

**Signed:** `<name>` (security) — `YYYY-MM-DD`

---

## Code Review sign-off

**Decision:** Approved | Approved with notes | Blocked

**What I reviewed:**

- The per-phase code-review gate results in `TASKS.md`
- Readability, naming, and consistency across the codebase
- Duplication, dead code, and over-complex functions
- Consistency with `standards/coding-standards.md`
- Any refactors applied or deferred during the build

**Notes:**

Describe in 2–6 sentences. Name any maintainability debt accepted into the release and where it is tracked.

**Signed:** `<name>` (code review) — `YYYY-MM-DD`

---

## Product owner / technical owner sign-off

**Decision:** Release approved | Release approved with accepted risks | Release blocked

**What I reviewed:**

- The business outcome each sign-off above asserts
- Any documented risks and their owners
- Rollback plan in `RUNBOOK.md`
- Cost, support, and operational ownership after launch

**Notes:**

Describe in 2–6 sentences. If risks are accepted, list them and name the re-review date.

**Signed:** `name (product owner)` — `YYYY-MM-DD`
