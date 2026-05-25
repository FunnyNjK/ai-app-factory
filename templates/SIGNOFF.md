# Gate D Sign-off Notes

This template captures the four short written sign-offs required at Gate D (see `OPERATING_MODEL.md` and `docs/adr/0006-three-agent-signoff.md`). Each agent writes one note. The product owner writes the fourth. All four live in the PR description or the release artifact and must reference the artifacts they reviewed.

Keep each sign-off short. A sign-off is a paragraph plus a checklist, not a report.

---

## Architect (Claude) sign-off

**Decision:** Approved | Approved with notes | Blocked

**What I reviewed:**

- `ARCHITECTURE.md` against the implemented system
- ADRs in `docs/adr/` (and any project-local ADRs)
- `THREAT_MODEL.md` against the implementation (if required)
- `COST_ESTIMATE.md` against the live cost shape after a representative load
- Observability defaults from `standards/observability-standards.md`

**Notes:**

Describe in 2–6 sentences what convinced you to approve, or what is blocking. Link any deviations to the ADR that covers them.

**Signed:** Claude (architect) — `YYYY-MM-DD`

---

## Developer (Cursor) sign-off

**Decision:** Approved | Approved with notes | Blocked

**What I reviewed:**

- Acceptance criteria from the architect handoff
- Test suite results (unit, integration, E2E)
- `.env.example` and the built bundle for secret leakage
- `README.md` and `RUNBOOK.md` against the current implementation
- Any escalation trails or design deviations raised during build

**Notes:**

Describe in 2–6 sentences. Name any known limitations and where they are documented. If approval is conditional, name the condition.

**Signed:** Cursor (developer) — `YYYY-MM-DD`

---

## Quality Engineer (Codex) sign-off

**Decision:** Ready | Ready with documented risks | Not ready

**What I reviewed:**

- `TEST_PLAN.md` execution results
- Critical user journeys against the running system
- Security smoke checks (secret scan, webhook verification, auth)
- Accessibility baseline (keyboard, labels, focus, contrast)
- Observability signal during a representative end-to-end run

**Notes:**

Describe in 2–6 sentences. If "Ready with documented risks," link each risk explicitly. Name the residual coverage gaps.

**Signed:** Codex (quality engineer) — `YYYY-MM-DD`

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
