# ADR-0008: Per-slice and per-phase gating between Cursor, Codex, and Claude

## Document metadata

| Field | Value |
|---|---|
| Number | 0008 |
| Date | 2026-05-26 |
| Author | Architect (Claude) |
| Approval owner | Product owner |
| Supersedes | Partial — refines Phases 4 and 5 in `OPERATING_MODEL.md` |

## Status

Accepted

## Context

The factory's original operating model uses **coarse gating** between phases: Claude produces the architecture, Codex reviews it once at Gate B, Cursor implements every vertical slice in sequence (Phase 4), and Codex verifies the whole implementation at Gate C/D. Within Phase 4 there is no per-slice approval loop — Cursor builds slice 1 through slice N without an enforced Codex review between them.

This is acceptable for human-led development where context-switching is expensive and review batches are economical. It is suboptimal for an AI factory where:

- Each agent runs as a separate session and pays a real token cost to re-read project context, so per-slice review does not amortize the same way it does for humans.
- A defect introduced in slice 1 can propagate to slice 5 before any reviewer catches it.
- Codex reviewing a finished implementation reviews specifications-vs-behavior, but loses the ability to flag intent drift in earlier slices.
- Claude's value as architect is highest at *phase boundaries*, where integration questions surface that no single slice raises.

The factory has not yet been used end-to-end. This ADR codifies the gating model before the first real project runs, while the cost of changing the model is still low.

## Decision

The factory adopts a **two-level gating model**:

### Per-slice gate (Cursor ↔ Codex)

For every vertical slice produced from the Architecture Package's Work Breakdown:

1. **Cursor** picks the next `pending` slice in `TASKS.md`, marks it `in-progress`, implements it end-to-end (UI/API/tests/docs as scoped), and marks it `awaiting-review`.
2. **Codex** picks up any slice in `awaiting-review` status, executes the slice's acceptance criteria, and either:
   - Marks the slice `approved` and the next `pending` slice becomes available, or
   - Files **sub-tasks** under the slice with specific bug reports and marks it `in-progress` again so Cursor can fix.
3. The cycle repeats until the slice is `approved` or the per-task iteration cap is hit.

### Per-phase gate (Codex → Claude)

When every slice in a phase reaches `approved`:

1. **Claude** picks up the phase, reads the implementation against the phase's intent from the Architecture Package, and either:
   - Marks the phase `approved` and the next phase begins, or
   - Files **phase-level sub-tasks** in `TASKS.md` and routes them back to Cursor (mark relevant slices `in-progress` again).
2. The cycle repeats until the phase is `approved` or the per-phase iteration cap is hit.

### Sub-task ownership

The reviewer that found the issue files the sub-task. This keeps responsibility aligned with the role:

- **Codex** files code-level sub-tasks (bug found during slice review).
- **Claude** files architecture/integration-level sub-tasks (issue found during phase review).

### Iteration caps and escalation

When a cap is hit (or any agent cannot make progress for a documented reason), the agent **does not** keep looping. It writes an entry to `ESCALATIONS.md` with the slice/phase identifier, the reason, what was tried, and a recommended action, then marks the affected work `human-needed`. Stage-2 orchestration (a future ADR) reads these signals to halt the loop and surface the queue to the product owner.

### Default budget caps

These are factory defaults, configurable per project in the `TASKS.md` header:

| Cap | Default | Rationale |
|---|---|---|
| Per-task iterations (Codex finds bugs → Cursor fixes) | 5 rounds | After five honest attempts, the slice is either mis-scoped or needs human judgment. Raised from 3 → 5 on 2026-06-05; see Amendment below. |
| Per-phase iterations (Claude finds issues → Cursor fixes) | 2 rounds | Phase-level disagreement usually reveals an architecture question, not an implementation bug. |
| Per-session token cap | 100,000 tokens | Configurable per tool; protects against unbounded context expansion. |
| Per-project budget | $200 (soft) | Sized for small marketing-site and SaaS projects. Larger projects override this in the `TASKS.md` header. |
| Per-session wall time | 30 minutes | Catches hung sessions or stuck loops. |

These are starting points. Real-world projects should adjust based on observed cost-per-slice during early factory use. Stage 2 (autonomous orchestrator) will enforce them programmatically; Stage 1 relies on each agent honoring them.

### Human review point

The product owner reviews `ESCALATIONS.md` **after** the most recent Claude phase review (or sooner if they want to). For each open escalation, the human either provides guidance (resolution notes routed back to the relevant agent), defers it, or marks the project blocked pending external action (secret rotation, design call, vendor support, etc.).

## Alternatives considered

1. **Keep coarse gating (status quo).** Smaller per-slice overhead and lets Cursor build momentum, but lets defects and intent drift propagate across slices. Rejected because the factory's whole point is producing maintainable software, not just code.
2. **Per-slice gate only (no per-phase gate).** Catches code-level defects but misses integration questions that only appear at phase boundaries. Rejected because phase reviews are where Claude's architect role earns its keep.
3. **Continuous-integration only.** Tests run after every slice, replacing Codex review with automation. Reasonable in the long run but requires test coverage and CI pipelines that do not exist at slice 1. Rejected as Stage-N work, not Stage 1.
4. **Human review of every slice.** Highest quality but does not scale and defeats the purpose of an AI factory. Rejected.
5. **No iteration caps (let the AI loop until done).** Open-ended cost risk, runaway loops on ambiguous acceptance criteria. Rejected.

## Consequences

### Positive

- Defects caught at slice boundaries instead of propagating across the project.
- Phase reviews catch integration issues that slice review cannot.
- Sub-task ownership is unambiguous (reviewer that found the issue files it).
- Budget caps create a clear stop condition for autonomous loops.
- `ESCALATIONS.md` gives the human a single queue to review at known cadence (each phase boundary), not a constant interrupt stream.

### Negative

- More handoff overhead per slice. Mitigated by AI agents paying low context-switch cost.
- Requires `TASKS.md` and `ESCALATIONS.md` to stay in sync across three tools. Mitigated by simple markdown formats that all three can read and write.
- Iteration caps are guesses until validated by real factory use. The cap numbers are likely to change once the first two test projects run.

### Neutral

- The slice/phase shape itself does not change; only the *gating between them* does. Existing handoff and architecture templates work unchanged.
- Stage 1 relies on the product owner as the orchestrator (manually moving work between Cursor and Codex sessions). Stage 2 will replace that with a script (separate ADR).

## Amendment (2026-06-05): per-task cap 3 → 5, and exhaustive single-pass slice review

The first end-to-end orchestrator run (the `simplytammi` marketing-site pilot, ADR-0009 validation) exercised the per-task cap on a real multi-criteria slice and confirmed the prediction in this ADR's own Negative consequences ("the cap numbers are likely to change once the first two test projects run"). Two findings:

1. **The cap of 3 was too tight for slices with many discrete acceptance criteria.** On slice 2.2 (`POST /api/contact` — validation, honeypot, rate-limit, error envelope), the Tester (Codex) surfaced legitimate, in-scope gaps in *successive* review rounds — 2.2.a–d in round one, then 2.2.e–f (error-envelope test coverage required by `API_SPEC.md`) in round two — exhausting the 3-round cap on sound work rather than on a mis-scope. The escalation was correct mechanically but pointed at a too-small cap, not a too-broad slice.

2. **The root cause was incremental review, not the cap.** Because the Tester filed gaps a batch at a time instead of enumerating the full acceptance-criteria set in one pass, each pass consumed one of the limited iterations.

**Decisions:**

- **Per-task iteration cap default raised 3 → 5.** Five gives headroom for a couple of legitimate fix rounds while still flagging genuinely mis-scoped slices. The cap remains a *mis-scope detector*, not a throughput knob, so it is not raised further — a higher value would mask mis-scoping and waste tokens looping. The per-phase cap is unchanged at 2.
- **Slice review must be exhaustive in a single pass.** `scripts/orchestrator/codex-slice-review.sh` now instructs the Tester to evaluate *every* acceptance criterion and file *all* defects and missing tests as sub-tasks in one review, rather than stopping at the first batch. This is the structural fix; the cap raise is the safety margin.

The cap is read from the `TASKS.md` "Per-task iterations" budget header (single source of truth; `factory_increment_iterations` derives each slice's `N/M` denominator from it), so existing projects pick up the new default by editing that one header row (or via `refresh-project`).

## Follow-up

- Add `templates/project-skeleton/TASKS.md` — per-project task tracker.
- Add `templates/project-skeleton/ESCALATIONS.md` — human review queue.
- Update `templates/project-skeleton/CLAUDE.md`, `templates/project-skeleton/AGENTS.md`, and `templates/project-skeleton/.cursor/rules/developer.mdc` with the gating workflows.
- Add `templates/project-skeleton/.claude/commands/next-slice.md` — surface the next pending slice and any blockers.
- Update `OPERATING_MODEL.md` Phases 4 and 5 to reference this gating model.
- Stage 2: build the autonomous orchestrator (separate ADR) once the model has been validated on at least one real project.

## References

- `OPERATING_MODEL.md` — Phases 4 and 5
- `templates/project-skeleton/TASKS.md`
- `templates/project-skeleton/ESCALATIONS.md`
- `docs/adr/0006-three-agent-signoff.md` — four-party Gate D sign-off (this ADR layers under that one)
