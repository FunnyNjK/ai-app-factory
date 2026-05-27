---
name: spawn-new-project
description: Scaffold a new project folder with its own Claude-specific instructions, templates, and structure. Use when the user wants to "start a new project", "scaffold a project", "kick off project X", or any phrasing that begins a fresh project from the factory. Creates a sibling folder by default and customizes the project-level CLAUDE.md for the chosen blueprint.
---

# Spawn a new project from the factory

You create a new project folder outside the factory repo with its own Claude-specific instructions, project templates, and a starter README.

## Inputs to collect

Ask the product owner (one at a time, per `CLAUDE.md` Section 11):

1. **Project name** (kebab-case, e.g., `acme-marketing-site`).
2. **Parent directory** — defaults to the directory containing the factory repo (sibling layout). Confirm or ask.
3. **Blueprint** — pick from `blueprints/`:
   - `marketing-site.md`
   - `static-web-app.md`
   - `full-stack-web-app.md`
   - `api-service.md`
   - `azure-functions.md`
   - `stripe-app.md`
   - `plaid-app.md`
   - `postmark-email.md`

## Procedure

The factory ships a script that performs every step below deterministically: `scripts/scaffold-new-project.sh`. Use the script rather than performing the steps by hand — it keeps placeholders consistent, copies the right conditional templates per blueprint, and initializes git.

1. **Invoke the scaffold script** with the collected inputs:

   ```bash
   <factory-path>/scripts/scaffold-new-project.sh \
     --name <project-name> \
     --blueprint <blueprint> \
     --parent <parent-dir-or-omit-for-sibling> \
     --goal "<one-line-goal>" \
     --users "<primary-users>" \
     --launch-date "<YYYY-MM-DD or none>" \
     --operator "<operator-after-launch>"
   ```

   The script:
   - Copies `templates/project-skeleton/` into `<parent>/<project-name>/` (including `CLAUDE.md`, `AGENTS.md`, `templates/project-skeleton/.cursor/rules/developer.mdc`, `TASKS.md`, `ESCALATIONS.md`, `.claude/commands/`, `README.md`, `.gitignore`).
   - Copies starter templates (`templates/PROJECT.md`, `templates/ARCHITECTURE.md`, `templates/SECURITY.md`, `templates/.env.example`, `templates/RELEASE_CHECKLIST.md`, `templates/RUNBOOK.md`, `templates/SIGNOFF.md`).
   - Conditionally copies `templates/API_SPEC.md`, `templates/THREAT_MODEL.md`, `templates/COST_ESTIMATE.md`, and `templates/infra/` based on the blueprint.
   - Replaces every `<placeholder>` token across `.md` and `.mdc` files in the new project using the args provided.
   - Runs `git init` and stages the initial files (but does not commit; the product owner chooses the first commit message).

   The skeleton intentionally does not ship a `<project>/.claude/settings.json`. Permission allowlists are opt-in per project; if the product owner wants the factory's defaults, copy them from the factory's settings file separately.

   The gating model behind `TASKS.md` and `ESCALATIONS.md` is documented in `docs/adr/0008-per-slice-and-per-phase-gating.md`. The orchestrator that automates the gating loop is documented in `docs/adr/0009-autonomous-orchestrator.md`.

2. **Validate the scaffolded project** before handing it off:

   ```bash
   <factory-path>/scripts/validate-project.sh <new-project-path>
   ```

   This catches missed placeholders, missing required files, and TASKS.md / ESCALATIONS.md structural issues. Fix anything it flags before moving on.

3. **Confirm with the product owner.** Show:
   - Absolute path to the new project folder
   - The output of the validate-project script
   - Recommended next step: open the new folder in Claude Code and run `/intake`

## What NOT to do

- Do not write any application code in the spawn step. The project starts at intake, not implementation.
- Do not copy the entire `examples/` directory. Those are factory-level exemplars; the project does not need its own copy.
- Do not commit on behalf of the product owner. Stage only.
- Do not invent project-specific decisions. Defer to `/intake` and `/design`.

## After spawning

Suggest: "I scaffolded `<path>`. Open that folder in Claude Code and run `/intake` to begin Project Intake Mode."
