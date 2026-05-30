# Incident Post-Mortem — <incident-title>

> Blameless post-incident review. The goal is a more resilient system, not blame. Be specific and honest — the next person reading this was not in the room. Write "none" where a section does not apply; do not delete the section.

## Document metadata

| Field | Value |
|---|---|
| Incident ID | `TODO` |
| Severity | SEV1 / SEV2 / SEV3 |
| Status | Investigating / Mitigated / Resolved |
| Detected | `YYYY-MM-DD HH:MM` UTC |
| Resolved | `YYYY-MM-DD HH:MM` UTC |
| Author | `TODO` |
| Reviewers | `TODO` |

## Severity reference

- **SEV1** — major outage or data loss; user-facing and widespread.
- **SEV2** — partial outage or degraded function; a workaround exists.
- **SEV3** — minor or contained; little user impact.

## Summary

Two or three sentences: what happened, when, and the user-visible effect, written so someone with no context understands it.

## Impact

- **Users affected:** `TODO` (how many, which segments)
- **Functionality:** `TODO` (what did and did not work)
- **Data:** `TODO` (any loss, corruption, or exposure, or "none")
- **Cost / revenue:** `TODO` (or "none")

## Timeline (UTC)

| Time | Event |
|---|---|
| `HH:MM` | First signal or alert fired. |
| `HH:MM` | Acknowledged; investigation began. |
| `HH:MM` | Root cause identified. |
| `HH:MM` | Mitigation applied. |
| `HH:MM` | Resolved and confirmed. |

## Root cause

The specific technical cause. Be precise — "the deploy at 14:02 shipped a migration that removed a column default, so writes to the `orders` table began failing" beats "a database problem." If you used the five-whys, record them.

## Contributing factors

What made this possible, or worse than it had to be — a missing alert, a slow rollback, a gap in a check. System conditions, not people.

## What went well

- `TODO`

## What went poorly

- `TODO`

## Action items

Each item is concrete, owned, and tracked as a real task. Link the `TASKS.md` slice/phase or the `ESCALATIONS.md` entry that carries it, so it does not get lost.

| Action | Owner | Type | Tracking ID |
|---|---|---|---|
| `TODO` | `TODO` | prevent / detect / mitigate | `TODO` |

## Lessons and feedback

What should change beyond this one project — a standard, a default, a template, or an observability threshold (see `standards/observability-standards.md`). This is the Gate E feedback loop: what should the factory itself learn from this incident.
