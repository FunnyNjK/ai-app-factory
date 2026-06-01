# ADR-0010: Automate the Gate D agent sign-offs with a dedicated adapter

## Document metadata

| Field | Value |
|---|---|
| Number | `0010` |
| Date | `2026-05-29` |
| Author | Claude (architect) |
| Approval owner | Product owner / technical owner |
| Supersedes | None |

## Status

Accepted. Extended by [ADR-0013](0013-configurable-roles-and-tools.md): the ceremony now runs five agent sub-sessions (architect, developer, quality engineer, security, code review) instead of three, each driven by whichever tool the project mapped to that role, and `SIGNOFF.md` is a six-party artifact. The adapter design described below is otherwise unchanged. References to "three agent sign-offs" and "four-party" in the text below are historical.

## Context

`docs/adr/0006-three-agent-signoff.md` defines release readiness as a four-party Gate D sign-off: architect (Claude), developer (Cursor), quality engineer (Codex), and the human product owner each sign in writing, and a project is not shippable unless all four agree. `templates/SIGNOFF.md` is the artifact that holds those four notes.

Nothing in the orchestrator ever triggered that ceremony. The autonomous loop in `scripts/orchestrator/orchestrate.sh` declared the run finished — exit 0, "Orchestrator done" — the moment every slice and phase review reached `approved`. The first full end-to-end test run exposed the gap directly: the project reached all-phases-approved and the loop stopped, but `SIGNOFF.md` was still the unchanged template. There was no recorded architect, developer, or quality-engineer sign-off and no point at which the product owner was asked to authorize release. The model from ADR-0006 was correct; the lifecycle around it had no closing step.

We need a deterministic, repeatable way to produce the three agent sign-offs and to surface — not fabricate — the fourth.

## Decision

Add a dedicated orchestrator adapter, `scripts/orchestrator/gate-d-signoff.sh`, that runs the Gate D agent sign-offs.

`factory_next_action` emits a new action, `orchestrator gate-d-signoff -`, when every phase review is `approved` and `SIGNOFF.md` is still in its pristine template state (no party has signed). The orchestrator dispatches the adapter, which:

1. Confirms every phase review is approved and `SIGNOFF.md` exists.
2. Runs three headless sub-sessions in order — Claude (architect), then Codex (quality engineer), then Cursor (developer). Each fills only its own section of `SIGNOFF.md` (Decision, Notes, dated Signed line) and is told to reference the artifacts it reviewed. Running in sequence lets each later signer read the earlier sign-offs.
3. Leaves the product-owner section untouched, writes a `judgment-call` escalation to `ESCALATIONS.md` asking a human to review the three agent sign-offs and complete the fourth, commits the changes, and exits 2 (human-needed) so the orchestrator halts.

A new `factory_signoff_state` helper classifies `SIGNOFF.md` as `pristine`, `agents-signed`, `complete`, or `partial`, which lets `factory_next_action` fire the adapter exactly once and lets the orchestrator's end-game distinguish "waiting on the human" (exit 2) from "all four signed, release-ready" (exit 0).

## Alternatives considered

1. Keep the sign-off fully manual (status quo) — relies on a human remembering to fill `SIGNOFF.md` after the loop stops. The test run proved that does not happen; the loop silently reported "done" with an empty sign-off.
2. Have each per-phase review write a partial sign-off — couples a release-level gate to per-phase gates, which is the wrong altitude, and the final phase review still has no view of the other parties' sign-offs.
3. One combined session writes all three agent sign-offs at once — loses the independence ADR-0006 requires. One agent speaking for the other two defeats the point of separate sign-offs.
4. Auto-sign the product owner too — violates ADR-0006. The human must accept documented risk and authorize release; the factory cannot make that business decision, so the fourth section is deliberately left as a human escalation.

## Consequences

### Positive

- Every run can now reach a clean, well-defined terminal state instead of stopping in an ambiguous "approved but unsigned" condition.
- The sign-off artifact is produced automatically and cites the reviewed artifacts, giving the product owner a real basis for the final decision.
- The human's remaining responsibility is narrowed to exactly the product-owner judgment, with an escalation that points straight at it.
- The adapter is re-runnable: already-signed sections are left untouched, so a recovery run only fills what is missing.

### Negative

- Three sequential headless sessions add wall-time (up to three times the per-adapter cap) to what is a one-time, end-of-project ceremony.
- The quality of the agent sign-offs depends on the sub-session prompts and model. A weak run could produce thin notes; the adapter mitigates this by verifying each section was actually filled and escalating any `partial` state rather than reporting success.

### Neutral

- `SIGNOFF.md` stays the same four-section template. The adapter fills three sections; the unfilled fourth is exactly what `scripts/validate-project.sh` learns to detect as the remaining Gate D gap.

## Follow-up

- `scripts/validate-project.sh` gains a check that `SIGNOFF.md` is filled once all phase reviews are approved, so the gap is caught structurally rather than by eye.
- Revisit whether the product-owner escalation should also carry an explicit re-review date when risks are accepted.

## References

- `docs/adr/0006-three-agent-signoff.md` — the four-party Gate D sign-off model
- `docs/adr/0008-per-slice-and-per-phase-gating.md` — the per-slice and per-phase gating model
- `docs/adr/0009-autonomous-orchestrator.md` — orchestrator and adapter design
- `OPERATING_MODEL.md` — Gate D definition and quality gates
- `templates/SIGNOFF.md` — the four-party sign-off note template
- `scripts/orchestrator/gate-d-signoff.sh` — the adapter introduced by this decision
