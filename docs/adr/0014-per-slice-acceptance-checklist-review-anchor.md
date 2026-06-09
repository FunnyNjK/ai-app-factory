# ADR-0014: Per-slice acceptance checklists as the authoritative review anchor

## Status

Accepted

Accepted 2026-06-08 after the failure mode recurred a third time: `simplytammi` slice 2.3 hit the per-task iteration cap (ESC-004) via the same incremental-review dribble this ADR describes, confirming that the cap raise and the "exhaustive single-pass" instruction are not sufficient on their own. `scripts/orchestrator/codex-slice-review.sh` now implements the per-item verdict mechanism (decision 2): when a slice's acceptance line names a consolidated checklist, the reviewer loads it and reports `covered`/`gap`/`n/a` for every item, approving only when all are `covered` or `n/a`; absent a checklist it falls back to enumerating the scattered docs as before.

Extends [ADR-0008](0008-per-slice-and-per-phase-gating.md) (sharpens what "acceptance criteria" a slice review verifies against) and [ADR-0009](0009-autonomous-orchestrator.md) (changes the slice-review adapter's contract). **Refines the second decision of ADR-0008's Amendment (2026-06-05).** That amendment made two changes after the first orchestrator pilot: (a) raised the per-task iteration cap 3 → 5, and (b) instructed the Tester to "review exhaustively in a single pass." The same pilot, run one slice further, showed that **(b) alone does not work** — see Context. This ADR keeps the exhaustive-pass instruction but re-grounds it: the reviewer enumerates against an explicit, authored checklist instead of re-deriving the criteria set each round. The cap raise (a) stands as a safety margin.

## Context

ADR-0008's per-slice gate has the Tester review each completed slice against its "acceptance criteria." In practice those criteria are **scattered** across `API_SPEC.md`, `SECURITY.md`, `CURSOR_HANDOFF.md`, and `ARCHITECTURE.md`. Nothing consolidates them into one enumerable list, and nothing forces the reviewer to check the implementation against that list item by item. So both the implementer (Cursor) and the reviewer (Codex) **re-synthesize the criteria set from scratch every round** — and each round they reconstruct a *different* subset.

The consequence is a recurring failure mode the first end-to-end pilot (the `simplytammi` marketing-site, ADR-0009 validation) exhibited sharply on slice 2.2 (`POST /api/contact`):

- **The reviewer dribbles findings across rounds instead of surfacing them all at once.** Round 1 filed sub-tasks 2.2.a–d, round 2 filed 2.2.e–f, round 3 filed 2.2.g–l — each round legitimate, each round consuming one iteration of the cap. The work was sound; the *review* was incremental.
- **It happened even after the ADR-0008 amendment's "exhaustive single-pass" instruction shipped.** Under the new prompt, the reviewer still filed a fresh batch (g–l). You cannot "enumerate every acceptance criterion in one pass" when the criteria do not live in one enumerable place — the instruction had nothing concrete to enumerate.
- **The reviewer sometimes contradicted its own prior guidance.** Round 2 told Cursor (2.2.e) that downstream throws should return `500 INTERNAL_ERROR`; round 3 (2.2.g) said a Turnstile `siteverify`-unreachable must instead fail-closed to `400 BOT_CHECK_FAILED`. Cursor was penalized for following the earlier instruction. Both rounds were re-deriving from the same docs and landing in different places.
- **Most findings were real and already written down.** `API_SPEC.md` contained a 17-item "Test coverage checklist" the whole time. The round-3 findings mapped almost entirely onto items in that existing checklist. The reviewer simply was not anchored to it.

The slice was finished only by the architect stepping outside the autonomous loop: treating `API_SPEC.md`'s checklist as the authoritative gate, triaging the reviewer's findings against it (keeping the legitimate ones, trimming two over-broad ones with recorded scope decisions), and verifying the result directly. That converged in **one** bounded implementer pass, green, with no further churn. The contrast is the evidence for this ADR: the cap and the reviewer prompt are not the lever — a consolidated, authoritative checklist is.

## Decision

**1. Every slice has a consolidated acceptance checklist, authored at design time.** The architect produces, during `/design` and the handoffs, an explicit flat list of testable acceptance criteria per slice — each item with a stable id (e.g. `2.2-AC-07`). Contract-bearing documents that already carry such lists (`API_SPEC.md`'s "Test coverage checklist", `SECURITY.md`'s checklists) are folded in by reference rather than duplicated. The checklist — not a prose pointer to four documents — is the slice's acceptance gate.

**2. The slice review verifies item-by-item against the checklist and reports a per-item verdict.** `scripts/orchestrator/codex-slice-review.sh` instructs the Tester to load the slice's checklist and emit, for **every** item, one of: `covered` (and by which test), `gap` (file a sub-task), or `n/a` (with a one-line reason). A slice is approved only when every item is `covered` or `n/a`. Because the list is finite and explicit, "file all gaps in one pass" becomes enforceable rather than aspirational.

**3. Implementer and reviewer share the one list.** Cursor's handoff references the same per-slice checklist the reviewer verifies, so there is a single source of truth and no divergent re-synthesis between the two roles.

**4. Scope and N/A decisions belong to the architect and are recorded on the checklist.** When a criterion does not apply (e.g. `Content-Security-Policy` / `X-Frame-Options` on a JSON API body, which are never rendered or framed), the architect records the decision against the checklist item so the reviewer does not re-litigate it round after round. This is what stopped slice 2.2's i/j churn.

**5. The reviewer keeps one adversarial pass beyond the checklist.** The checklist is the floor, not the ceiling. The review prompt still asks for issues the checklist did not anticipate (emergent integration bugs, security smells), filed as sub-tasks — so the checklist does not degrade into rote box-ticking.

## Alternatives Considered

1. **Raise the iteration cap further (e.g. 5 → 8).** Rejected. Masks mis-scoping, burns tokens looping, and does nothing about the dribble or the contradictions — it just delays the escalation. The cap should stay a mis-scope detector.
2. **Only strengthen the reviewer prompt (ADR-0008's amendment 2b).** Tried in the pilot. Insufficient: the reviewer cannot enumerate a set that is not consolidated. Necessary but not sufficient; retained, re-grounded by this ADR.
3. **Add a reviewer panel (N independent reviewers per round).** Rejected as the default. More cost per round and still no shared enumerable spec; redundancy is not the missing ingredient — a single source of truth is.
4. **Require human checklist verification on every slice.** Rejected as the default — it defeats the autonomy ADR-0009 buys. The architect-verification path used to rescue slice 2.2 remains the deliberate escape hatch when the loop stalls, not the steady state.

## Consequences

### Positive

- Reviews converge: one pass against a finite, shared list instead of an open-ended re-derivation.
- No more contradictory round-to-round guidance — the criteria are fixed before implementation starts.
- The iteration cap becomes a true mis-scope signal again: repeated cap hits now mean the *slice* is wrong, not the review.
- Implementer and reviewer build and check against the same spec.
- Architect scope decisions become durable instead of being re-argued every round.

### Negative

- More design-time work: the architect must author a real per-slice checklist, not a pointer.
- The checklist must be kept in sync when the contract changes (mitigation: fold in the existing `API_SPEC`/`SECURITY` checklists by reference so there is one place to update).
- Risk of the checklist becoming a rote box-tick that misses emergent issues (mitigation: decision 5, the retained adversarial pass).

### Neutral

- `API_SPEC.md`-style test-coverage checklists already exist informally in well-specified projects; this formalizes and generalizes the pattern to every slice.
- The slice/phase loop shape is unchanged; only the *contract the slice review verifies against* becomes explicit.

## Follow-up

- Choose the checklist's canonical home and format (recommended: a per-slice "Acceptance checklist" block in `ARCHITECTURE.md` Work Breakdown — the slice's existing home — with stable item ids, referencing `API_SPEC`/`SECURITY` checklists; `TASKS.md` links to it). Prototype on the next greenfield slice.
- Update `scripts/orchestrator/codex-slice-review.sh` to load the checklist and require a per-item verdict before approval; update the `FACTORY_STATUS` contract if a structured per-item result is wanted.
- Update the `/design`, `/handoff-cursor`, `/handoff-codex` skills and the project-skeleton templates to require a per-slice acceptance checklist.
- Add a back-reference from ADR-0008's Amendment (2026-06-05) to this ADR.
- Re-validate on `simplytammi` slice 2.5 (or the next project's first slice): confirm a single review pass with a per-item verdict, no dribble, no cap hit on sound work.
- Restore the slice-2.2 carry-forward (a dedicated `500 INTERNAL_ERROR` unit test) during Phase 2 hardening — a concrete instance of a checklist item that fell through precisely because the review was not checklist-anchored.

## References

- [ADR-0008](0008-per-slice-and-per-phase-gating.md) — per-slice and per-phase gating (and its 2026-06-05 amendment)
- [ADR-0009](0009-autonomous-orchestrator.md) — autonomous orchestrator and the slice-review adapter contract
- `scripts/orchestrator/codex-slice-review.sh` — the slice-review adapter this ADR re-contracts
- `simplytammi` slice 2.2 (`TASKS.md`, `ESCALATIONS.md` ESC-002/ESC-003) — the worked example
