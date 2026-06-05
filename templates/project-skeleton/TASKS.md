# Project Tasks — <project-name>

> Per-slice and per-phase task tracker. Source of truth for what is done, what is in progress, and what is blocked. See `docs/adr/0008-per-slice-and-per-phase-gating.md` (gating model) and `docs/adr/0013-configurable-roles-and-tools.md` (five roles and the per-phase security + code-review gates) in the factory.

## Status values

- `pending` — not yet started
- `in-progress` — actively being worked or has new sub-tasks
- `awaiting-review` — a slice is finished and its reviewer picks up. Or, after a phase's slices are all approved, each phase gate becomes `awaiting-review` in turn: the architect review, then the security gate, then the code-review gate.
- `approved` — passed its review gate
- `blocked` — cannot proceed; needs human input (see `ESCALATIONS.md`)
- `human-needed` — iteration cap hit; needs human review

## Owner values

- `cursor` — implementation (coding) work
- `codex` — verification work (no separate implementer; Codex does the work itself)

`Owner` is the slice's *work type*, set by the architect at design time and left unchanged through the loop — `Status` (not `Owner`) tracks runtime progress. `cursor` and `codex` are the only valid owners; any other value is an architect error and is routed to `cursor` with a warning.

## Budget caps (project overrides)

| Cap | Value | Override here |
|---|---|---|
| Per-task iterations | 5 | <number-or-default> |
| Per-phase iterations | 2 | <number-or-default> |
| Per-session token cap | 100,000 | <number-or-default> |
| Per-project budget (USD) | 200 | <number-or-default> |
| Per-session wall time (minutes) | 30 | <number-or-default> |

When a cap is hit, the agent writes to `ESCALATIONS.md` and marks the affected work `human-needed`. No agent keeps looping past the cap.

---

## Phase 1 — <phase-name>

> Phase intent (one sentence): <what-this-phase-delivers>

### 1.1 <slice-name>

- Status: `pending`
- Owner: cursor
- Acceptance criteria: see `ARCHITECTURE.md` Work Breakdown 1.1 (or `CURSOR_HANDOFF.md` slice 1.1)
- Iterations: 0/5
- Sub-tasks: none
- Notes: -

### 1.2 <slice-name>

- Status: `pending`
- Owner: cursor
- Acceptance criteria: see `ARCHITECTURE.md` Work Breakdown 1.2
- Iterations: 0/5
- Sub-tasks: none
- Notes: -

### Phase 1 review

- Status: `pending` (becomes `awaiting-review` when all slices in this phase are `approved`)
- Reviewer: architect
- Iterations: 0/2
- Notes: -

### Phase 1 security

- Status: `pending` (becomes `awaiting-review` when `Phase 1 review` is `approved`)
- Reviewer: security
- Iterations: 0/2
- Notes: -

### Phase 1 code-review

- Status: `pending` (becomes `awaiting-review` when `Phase 1 security` is `approved`)
- Reviewer: code_review
- Iterations: 0/2
- Notes: -

---

## Phase 2 — <phase-name>

> Phase intent (one sentence): <what-this-phase-delivers>

### 2.1 <slice-name>

- Status: `pending`
- Owner: cursor
- Acceptance criteria: see `ARCHITECTURE.md` Work Breakdown 2.1
- Iterations: 0/5
- Sub-tasks: none
- Notes: -

### Phase 2 review

- Status: `pending`
- Reviewer: architect
- Iterations: 0/2
- Notes: -

### Phase 2 security

- Status: `pending`
- Reviewer: security
- Iterations: 0/2
- Notes: -

### Phase 2 code-review

- Status: `pending`
- Reviewer: code_review
- Iterations: 0/2
- Notes: -

---

## How sub-tasks work

When Codex finds bugs during slice review, append them under the slice as a numbered list. Example shape (placeholder slice ID):

```text
### N.M <slice-name>

- Status: `in-progress`
- Owner: cursor
- Iterations: 1/5
- Sub-tasks:
  - N.M.a Fix the off-by-one error in pagination.
  - N.M.b Add server-side validation for the email field.
- Notes: Codex review 2026-05-26 — see PR comments.
```

When Claude finds phase-level issues, file them under the phase review. Example shape (placeholder phase ID):

```text
### Phase N review

- Status: `in-progress`
- Reviewer: claude
- Iterations: 1/2
- Sub-tasks:
  - N.review.a The contact form and the email service do not share a common error format. Standardize per `standards/api-standards.md`.
- Notes: Claude review 2026-05-26.
```

---

## Phase gates

Each phase has three gates that run in order after its slices are all approved (see `docs/adr/0013-configurable-roles-and-tools.md`):

1. **`Phase N review`** — the architect reviews the phase as a whole for cohesion and intent.
2. **`Phase N security`** — the security role reviews the phase for vulnerabilities and hardens in place; it may escalate to a human.
3. **`Phase N code-review`** — the code-review role reviews maintainability and applies behavior-preserving refactors; it may escalate.

All three must reach `approved` for the phase to be complete. The gates block: the security gate opens only after the review gate is approved, and the code-review gate only after the security gate is approved.

## Phase order

Phases proceed strictly in order. Phase N+1 cannot start until every gate of Phase N (`review`, `security`, `code-review`) is `approved` and `ESCALATIONS.md` has no open `human-needed` items affecting Phase N+1.

The product owner reviews `ESCALATIONS.md` after each phase (or sooner). Once the queue is clear (or escalations are explicitly deferred), the next phase begins.
