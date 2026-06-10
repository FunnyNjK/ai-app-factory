---
name: refresh-project
description: Bring an already-scaffolded factory project up to current factory conventions without losing project-specific content. Use when the user says "refresh project X", "update the project to the latest factory", "this project was scaffolded a while ago", or after the factory changes a skeleton or template convention that existing projects should adopt.
---

# Refresh a scaffolded project to current factory conventions

As the factory evolves, files copied into a project at scaffold time drift from the factory's current conventions. Live-referenced standards and ADRs (read from the factory at `<factory-path>`) do not drift; copied files do. This skill reconciles that drift surgically, preserving every bit of project-specific content.

## When to use

- A project was scaffolded from an older factory and should adopt newer conventions.
- The factory just changed a skeleton or template convention (a new TASKS.md legend, a new slash command, a new Gate-D artifact) that existing projects should pick up.

## Inputs

- The path to the project to refresh (a sibling of the factory by default).

## Procedure

1. **Detect drift (read-only).** Run the detector and read its report:

   ```bash
   <factory-path>/scripts/refresh-project.sh <project-path>
   ```

   Each `DRIFT` line names a current convention the project lacks and how to fix it; `ok` lines are already current. If it reports "Up to date", stop — there is nothing to do.

2. **Reconcile each drift surgically.** For every `DRIFT` item, apply the factory's current convention to the project WITHOUT touching project-specific content:
   - **Additive boilerplate** (a missing TASKS.md legend, a missing slash command, a missing artifact such as `SIGNOFF.md`): copy the current version from `<factory-path>/templates/project-skeleton/` or `<factory-path>/templates/` into the project. Insert a legend in the same position the skeleton uses; do not disturb the project's phases, slices, or filled-in values.
   - **Customized files** (`CLAUDE.md`, `AGENTS.md`, and the Cursor `developer.mdc` rules): these carry the project's snapshot. Do NOT overwrite them. Compare only the static boilerplate sections against the skeleton and bring those forward, leaving every project-specific value (name, goal, snapshot, decisions) intact. When in doubt, show the user the diff and ask.
   - Never re-introduce a `<placeholder>` token. Never clobber a value the project already filled in.
   - **Machine-absolute repo paths** (`validate-project.sh` check 9): projects scaffolded before 2026-06-09 may reference the factory by the authoring machine's absolute path (e.g. `/home/<user>/repos/ai-app-factory/docs/adr/0008-per-slice-and-per-phase-gating.md`). Rewrite each to the portable form — `<factory>/docs/adr/0008-per-slice-and-per-phase-gating.md` or "`docs/adr/0008-per-slice-and-per-phase-gating.md` in the factory" — changing ONLY the path prefix, never the surrounding sentence or the file being referenced.

3. **Stamp the baseline.** Write or update `<project-path>/.factory-version` with the factory's current short SHA and today's date, so the next refresh has a reference.

4. **Record the migration.** Append a short dated note under the project's `docs/adr/` (a small ADR) or its README change log: which conventions were brought forward and why. That is the trail the next refresh reads.

5. **Re-verify.** Run both checks and confirm they are clean:

   ```bash
   <factory-path>/scripts/refresh-project.sh <project-path>
   <factory-path>/scripts/validate-project.sh <project-path>
   ```

   The detector should now report "Up to date." Any remaining `validate-project.sh` failures are separate lifecycle issues, not drift.

6. **Confirm with the product owner.** Summarize what changed, show the migration note, and stage (do not commit) the changes — the commit message is theirs.

## What NOT to do

- Do not overwrite `CLAUDE.md`, `AGENTS.md`, the Cursor `developer.mdc`, `PROJECT.md`, `ARCHITECTURE.md`, or any file the project has filled in. Reconcile, do not replace.
- Do not change application code. A refresh is a planning and convention sync, not a feature change.
- Do not commit on the product owner's behalf. Stage only.
- Do not invent project decisions. If a drift needs a judgment call, surface it and ask.
