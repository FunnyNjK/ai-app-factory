# Project Skeleton

> **This is a factory template, not a working project.** It is the starter folder structure that the `/new-project` command (or the `spawn-new-project` skill) copies into a new project directory.

When `/new-project` runs, the contents of `templates/project-skeleton/` are copied into a new sibling folder of the AI App Factory repo. Every `<placeholder>` token is filled in based on the product owner's answers during scaffolding.

## What ships in the skeleton

- `CLAUDE.md` — project-level Claude (Architect) instructions. Architect persona, teammate traits, project snapshot, role boundaries, quality gates, default workflow, escalation rules, and per-phase gating workflow. Auto-loaded by Claude Code.
- `AGENTS.md` — project-level Codex (Quality Engineer) instructions. QE persona, teammate traits, project snapshot, role boundaries, quality gates, and per-slice review workflow. Auto-loaded by Codex CLI.
- `.cursor/rules/developer.mdc` — project-level Cursor (Developer) rules. Developer persona, teammate traits, project snapshot, role boundaries, development principles, quality gates, and per-slice implementation workflow. Auto-loaded by Cursor.
- `TASKS.md` — per-project task tracker. Tracks every slice and phase review with status, owner, iteration counter, and sub-tasks. Shared source of truth for the three AI tools.
- `ESCALATIONS.md` — human review queue. Any agent appends here when it hits an iteration cap, needs a secret, or needs a judgment call. The product owner reviews this file at phase boundaries.
- `README.md` — this file. The skeleton itself documents how it is used; the spawned project's developer-facing README is generated separately by Cursor during implementation.
- `.claude/commands/intake.md` — slash command for Project Intake Mode.
- `.claude/commands/design.md` — slash command for the Architecture Package.
- `.claude/commands/adr.md` — slash command for a new Architecture Decision Record.
- `.claude/commands/handoff-cursor.md` — slash command for the developer handoff.
- `.claude/commands/handoff-codex.md` — slash command for the QE handoff.
- `.claude/commands/next-slice.md` — slash command that reports the next actionable slice or phase review from `TASKS.md`.

## What does NOT ship in the skeleton

- Application source code. The skeleton stops at instructions and templates.
- Test files. Codex and Cursor produce these against the architecture.
- The factory's blueprints, standards, and examples. Those live in the factory repo. The skeleton's CLAUDE.md references the factory at `<factory-path>`.
- A `<project>/.claude/settings.json`. Permission allowlists are opt-in per project; copy `<factory-path>/.claude/settings.json` if you want to inherit the factory's defaults.

## Manual customization after scaffolding

The three persona files — `CLAUDE.md`, `AGENTS.md`, and `.cursor/rules/developer.mdc` — share the same placeholder set. Replace each token consistently across all three (the AI team will fall out of alignment if the snapshots disagree):

- `<project-name>` — the project name
- `<blueprint-name>` — chosen factory blueprint
- `<blueprint>` — the blueprint filename stem (used in the factory blueprint reference)
- `<factory-path>` — absolute or relative path to the AI App Factory repo
- `<one-line-goal>` — the elevator-pitch goal
- `<primary-users>` — who uses this
- `<date-or-none>` — target launch date or `none`
- `<who>` — who operates the system after launch (`CLAUDE.md` only)

Then run the intake slash command inside the new project to begin Intake Mode.

## Why a skeleton (and not a fork of the whole factory)

The factory repo is the meta-system. Every project should be a separate folder with its own git history. Forking the entire factory per project would couple project history to factory governance and make factory upgrades painful.

The skeleton is intentionally small: persona + commands. Everything substantive (blueprints, templates, standards, ADRs, examples) is referenced back to the factory repo. To change factory rules, change the factory. To change project rules, change the project's CLAUDE.md.
