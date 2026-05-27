# Project Tasks — <project-name>

> Per-slice and per-phase task tracker. Source of truth for what is done, what is in progress, and what is blocked. See `docs/adr/0008-per-slice-and-per-phase-gating.md` in the factory for the gating model.

## Status values

- `pending` — not yet started
- `in-progress` — actively being worked or has new sub-tasks
- `awaiting-review` — Cursor finished a slice; Codex picks up. Or, after a phase completes: Claude picks up.
- `approved` — passed its review gate
- `blocked` — cannot proceed; needs human input (see `ESCALATIONS.md`)
- `human-needed` — iteration cap hit; needs human review

## Budget caps (project overrides)

| Cap | Value | Override here |
|---|---|---|
| Per-task iterations | 3 | <number-or-default> |
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
- Iterations: 0/3
- Sub-tasks: none
- Notes: -

### 1.2 <slice-name>

- Status: `pending`
- Owner: cursor
- Acceptance criteria: see `ARCHITECTURE.md` Work Breakdown 1.2
- Iterations: 0/3
- Sub-tasks: none
- Notes: -

### Phase 1 review

- Status: `pending` (becomes `awaiting-review` when all slices in this phase are `approved`)
- Reviewer: claude
- Iterations: 0/2
- Notes: -

---

## Phase 2 — <phase-name>

> Phase intent (one sentence): <what-this-phase-delivers>

### 2.1 <slice-name>

- Status: `pending`
- Owner: cursor
- Acceptance criteria: see `ARCHITECTURE.md` Work Breakdown 2.1
- Iterations: 0/3
- Sub-tasks: none
- Notes: -

### Phase 2 review

- Status: `pending`
- Reviewer: claude
- Iterations: 0/2
- Notes: -

---

## How sub-tasks work

When Codex finds bugs during slice review, append them under the slice as a numbered list. Example shape (placeholder slice ID):

```text
### N.M <slice-name>

- Status: `in-progress`
- Owner: cursor
- Iterations: 1/3
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

## Phase order

Phases proceed strictly in order. Phase N+1 cannot start until Phase N is `approved` and `ESCALATIONS.md` has no open `human-needed` items affecting Phase N+1.

The product owner reviews `ESCALATIONS.md` after each phase review (or sooner). Once the queue is clear (or escalations are explicitly deferred), the next phase begins.
