# ADR-0011: Recurring security review for sensitive-data projects

## Document metadata

| Field | Value |
|---|---|
| Number | `0011` |
| Date | `2026-05-30` |
| Author | Architect (Claude) |
| Approval owner | Product owner |
| Supersedes | None — extends `docs/adr/0008-per-slice-and-per-phase-gating.md` |

## Status

Proposed

## Context

A multi-perspective read-only review of the factory itself (six reviewer subagents under `.claude/agents/`: architecture, developer, quality, security, project-manager, business-analyst) found real defects — insecure Azure template defaults, unconditional permission flags in the orchestrator, and an absent test suite. That success raised a fair question: should the projects the factory builds get the same six-reviewer pass after each phase?

The honest answer is no — not as the six read-only reviewers, and not every phase — because the per-project gating model (`docs/adr/0008-per-slice-and-per-phase-gating.md`) already covers most of those lenses, and the reviewers as built do not fit the loop:

- **Architecture** is already Claude's per-phase review (integration, consistency, observability, threat-model gaps).
- **Developer** and **Quality** are already Codex's per-slice review (requirements, acceptance criteria, QA, bug reports).
- **Project-manager** and **business-analyst** add little per-phase on a single orchestrated project — the orchestrator's iteration caps and `ESCALATIONS.md` are the delivery control, and business intent is captured once at intake.
- **Security** is the one lens that is *not* recurring: it exists at design time (the `threat-modeler` subagent) and once at Gate D (security smoke), but nothing re-examines security as code lands phase by phase.

Two further constraints rule out "embed all six per phase":

1. **Cost.** The factory's own top cross-cutting finding is that cost/budget is ungoverned (`FACTORY_TOKEN_CAP` is unenforced; wall-time is the only bound). Six extra CLI sessions per phase per project moves directly against that.
2. **The reviewers produce reports, not action.** The orchestrator runs on the `FACTORY_STATUS=` contract and on adapters that file `TASKS.md` sub-tasks and `ESCALATIONS.md` entries. Read-only reviewers that emit prose reports would be orphaned — nothing would turn their findings into work.

The genuinely valuable, currently-missing capability is therefore narrow: a recurring **security** review during the build, for the projects that actually carry security risk.

## Decision

Add a single, optional, data-classification-gated **security-review step** to the orchestrator's gating loop — a `security-review` adapter that runs for projects handling sensitive data, emits the `FACTORY_STATUS=` contract, and files `TASKS.md` sub-tasks or `ESCALATIONS.md` entries like every other adapter — rather than embedding the six read-only review subagents into generated projects.

Specifics:

- **One lens, not six.** Only security. The other five are redundant with Codex/Claude or low-value per-phase.
- **Gated on data classification.** The intake "default critical 10" already classifies stored data as Public / Internal / Personal / Financial / Health / Secret (`CLAUDE.md`, intake). The security-review step runs only when a project touches **Personal, Financial, Health, or Secret** data (e.g. the `blueprints/stripe-app.md` and `blueprints/plaid-app.md` blueprints, or any project with authentication). Public/Internal-only projects (marketing/static sites) continue to rely on the existing Gate D security smoke.
- **Cadence.** Per-phase for in-scope projects, with a fallback option of once at the Gate C→D boundary if the per-phase cost proves unjustified in the pilot.
- **Wired for action.** Implemented as a new adapter (`security-review.sh`, under `scripts/orchestrator/`) that sources `scripts/orchestrator/lib.sh`, inherits the safety library (sensitive-path refusal, wall-time cap, single-flight lock), emits `FACTORY_STATUS=`, and files sub-tasks/escalations. It does not produce a standalone report.
- **Cost-bounded.** The adapter prompt carries an explicit tool/turn budget (a lesson from the factory review, where reviewers without a budget were cut off before reporting), and may use a cheaper model tier than the phase reviewer.
- **Scoped to avoid overlap.** It checks security of the code landed since the last run against `standards/security-standards.md` and `THREAT_MODEL.md`; it does not re-run the full design-time threat model or duplicate the Gate D smoke.

The six read-only review subagents remain **factory-level meta-tooling** for auditing the factory itself, not artifacts shipped into generated projects.

## Alternatives considered

1. **Embed all six read-only reviewers in every project's per-phase loop** — rejected. Redundant with Codex (quality/developer) and Claude (architecture); project-manager/business-analyst add little per-phase; multiplies cost against the factory's known cost gap; and the reviewers emit reports rather than the `FACTORY_STATUS=` action contract the orchestrator requires.
2. **Do nothing (status quo)** — rejected. Sensitive projects get only a one-time design threat model and a Gate D smoke, so a security regression introduced in an early phase can survive untouched until release, or slip through entirely.
3. **Fold the security lens into Codex's existing per-slice review prompt** instead of a new adapter — viable and cheaper, but dilutes Codex's quality focus and gives no phase-level (cross-slice) security view. Retained as the fallback if a dedicated adapter proves too heavy in the pilot.
4. **A targeted, data-classification-gated security-review adapter** — chosen. Adds the one missing lens, only where risk is real, wired to produce action.

## Consequences

### Positive

- A recurring security eye on exactly the projects that carry security risk (payments, financial data, auth), catching regressions phase by phase instead of only at Gate D.
- Fits the existing orchestrator contract and reuses the shared safety library — no new control-flow paradigm.
- Scoped by data classification, so low-risk projects pay no extra cost or latency.
- Keeps the factory aligned with its own "secure by default" and "prefer simple architecture" principles — one targeted addition, not six.

### Negative

- Another adapter and prompt to maintain, and an additional CLI session (cost + wall-time) per phase on in-scope projects.
- Overlap risk with the design-time threat model and the Gate D smoke; the prompt must be scoped to "what landed since last run" to avoid re-reviewing the same surface.
- Depends on accurate data classification at intake — a misclassified project would skip the review. Mitigated by defaulting to "run it" when classification is missing or ambiguous.

### Neutral

- The six read-only review subagents stay as factory meta-tooling; this ADR does not ship them into projects.
- Cadence (per-phase vs. pre-Gate-D-only) is intentionally left to the pilot rather than fixed now.

## Follow-up

- Implement the `security-review.sh` adapter under `scripts/orchestrator/` and wire `factory_next_action` in `scripts/orchestrator/lib.sh` to dispatch it for in-scope projects.
- Define the data-classification trigger (read the classification from `SECURITY.md` / `PROJECT.md`); default to running when absent.
- Pilot on the `blueprints/stripe-app.md` blueprint; measure cost and wall-time per phase, and confirm per-phase vs. pre-Gate-D cadence.
- On implementation, register the new adapter in `MANIFEST.md` and `scripts/validate-factory.mjs` `requiredFiles`, and document its env vars in `scripts/orchestrator/README.md`.
- Promote this ADR to Accepted after the pilot confirms the cadence and cost shape.

## References

- `docs/adr/0008-per-slice-and-per-phase-gating.md` — the gating model this extends.
- `docs/adr/0006-three-agent-signoff.md` — the Gate D sign-off this complements.
- `standards/security-standards.md` — the rules the adapter reviews against.
- `.claude/agents/security-reviewer.md` — the read-only reviewer whose lens this productizes for the build loop.
- The multi-agent factory review (2026-05-30) that prompted the question.
