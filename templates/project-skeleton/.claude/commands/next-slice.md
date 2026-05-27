---
description: Show the next pending slice or phase review in this project
---

Read this project's `TASKS.md` and report:

1. **The next actionable slice or phase.** In priority order:
   - Any `awaiting-review` Phase review (Claude picks up).
   - Any `awaiting-review` slice (Codex picks up).
   - Any `in-progress` slice with sub-tasks (Cursor picks up to fix).
   - Otherwise, the lowest-numbered `pending` slice in the lowest-numbered open phase (Cursor picks up to start).

2. **Open escalations.** Read `ESCALATIONS.md`. If any entries have `Status: open`, list them with their IDs and reasons. Flag if any escalation blocks the next actionable item.

3. **Budget state.** Read the budget cap section at the top of `TASKS.md`. Sum the iteration counters across all open slices and the current phase review. Warn if any are within one round of their cap.

4. **Recommended next agent.** Based on (1), name which AI tool should be invoked next: cursor, codex, or claude. In Stage 1, the product owner runs that tool's session manually. In Stage 2, the orchestrator does this automatically.

Do not modify `TASKS.md` or `ESCALATIONS.md` from this command. This is a read-only status check.

If `TASKS.md` does not exist yet, route the user back to the design slash command — the architecture has not been produced.
