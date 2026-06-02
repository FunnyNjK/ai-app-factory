# ADR-0012: Interactive bash TUI launcher for the factory

## Document metadata

| Field | Value |
|---|---|
| Number | `0012` |
| Date | `2026-05-31` |
| Author | Architect (Claude) |
| Approval owner | Product owner |
| Supersedes | None |

## Status

Proposed

## Context

Driving the factory today is raw script invocation: `scripts/scaffold-new-project.sh`, the per-role orchestrator adapters, `scripts/orchestrator/orchestrate.sh`, `scripts/validate-project.sh`, plus Claude Code slash commands (`/intake`, `/design`, `/handoff-*`) for the conversational steps.

The first real end-to-end run (the `simplytammi` project, Phase 1) repeatedly exposed the same friction at the shell layer:

- Knowing **which adapter to run next** (operators hand-tracked `TASKS.md` and guessed).
- Managing `RUN_PHASE_*` env vars by hand — `RUN_PHASE_NO_PUSH`, and especially the Codex sandbox flag (which also hit a duplicate-`--sandbox` bug).
- Finding open escalations and the current phase/slice state.

Crucially, the **conversational steps already have a good interface** — Claude Code's own TUI, with slash-command autocomplete and streaming output. The gap is the **shell/orchestration layer**, which is currently bare script calls. The product owner asked for "a GUI like Claude has via the CLI" for both the factory-level kickoff and the per-project build loop.

## Decision

Add a single, **context-aware bash TUI launcher** — `factory.sh`, under `scripts/` — that detects whether it is run in the factory root or in a scaffolded project and presents the matching menu, shelling out to the existing audited scripts and handing the terminal to `claude`/`codex`/`agent` for full-screen sessions.

It is a **thin convenience veneer**: all real logic stays in the existing scripts. Routing reuses `factory_next_action` from `scripts/orchestrator/lib.sh`; scaffolding, the adapters, and the autopilot loop are invoked unchanged. The TUI adds only menus, a status/next-action view, and settings toggles so operators stop hand-managing env vars.

**Baseline is dependency-free** — numbered `read`-based menus that work over SSH with no extra runtime. It may opt into `whiptail`/`fzf` for a nicer boxed UI when those are present, but must degrade to the plain menu when they are not.

Menu spec:

**Factory-root context** (kickoff):

- Factory health (`scripts/factory-status.sh`) and CLI preflight (`scripts/check-cli-tools.sh`).
- New project — prompt name / blueprint / goal / users, run `scripts/scaffold-new-project.sh`, then offer to open the new project in Claude for `/intake`.
- Open an existing project's build panel (re-enter in project context).

**Project context** (build loop):

- Status — current phase/slice, the resolved next action (`factory_next_action`), and open escalations, at a glance.
- Run next step (dispatch the right adapter) · Autopilot (`scripts/orchestrator/orchestrate.sh` until it halts).
- Settings — toggle `RUN_PHASE_NO_PUSH`, set the Codex sandbox flag.
- View escalations / `TASKS.md` · Validate (`scripts/validate-project.sh`) · Open a Claude session.

A non-interactive path (`factory.sh --next` / `--status`) prints the resolved next command and current state without entering a menu — testable, and doubles as the shell answer to "what do I run next?".

## Alternatives considered

1. **Richer framework TUI** (Node + Ink — what Claude Code itself uses — or Python + Textual). Rejected for v1: adds a real codebase and a runtime dependency the factory must own and test, against its bash-first, "prefer simple" ethos. Revisit if the bash TUI proves too limiting.
2. **Local web dashboard.** Rejected: heaviest to build; runs scripts behind a web server (new security surface); furthest from the factory's design and operating model.
3. **Do nothing beyond a `--next` flag on the orchestrator.** A viable minimal step, but it ignores the scaffold/kickoff context and the env-var/settings friction; the TUI subsumes it.
4. **(Chosen) thin, context-aware bash TUI launcher** — removes the friction the first run exposed while keeping all real logic in the existing audited scripts.

## Consequences

### Positive

- One entry point removes the "which command / which env var" friction the first end-to-end run surfaced.
- Reuses Claude Code's TUI for the conversational steps instead of reimplementing it.
- Thin wrapper keeps real logic in the audited scripts; works over SSH with no new runtime.
- The non-interactive `--next`/`--status` path is unit-testable and useful on its own.

### Negative

- Another script to maintain and test — it must get the Tier-1 test discipline the multi-agent review called for (covering the non-interactive paths at least).
- It is a launcher around full-screen sessions, not one unified embedded screen; expectations should be set accordingly.
- The role-to-adapter dispatch map would duplicate `orchestrate.sh` unless the two share it via `lib.sh`.

### Neutral

- `/intake` and `/design` stay inside Claude Code; the TUI orchestrates around them rather than replacing them.

## Follow-up

- [x] Implemented `factory.sh` under `scripts/`; it reuses `factory_next_action` from `scripts/orchestrator/lib.sh`, and the role-to-adapter map now lives in one place — `factory_adapter_for` in `lib.sh`, shared with `orchestrate.sh` so the two cannot drift.
- [x] Non-interactive `--next` / `--status` implemented (now also accepting an optional project-path argument), covered by a dependency-free bash test suite under `scripts/test/` that CI runs in a `Script Tests` job.
- [x] Documented the launcher in `docs/playbooks/running-a-project.md`; registered in `MANIFEST.md` and `scripts/validate-factory.mjs` `requiredFiles`.
- [ ] Promote this ADR to Accepted after a first interactive run on the Ubuntu host (where the `fzf`/`whiptail` pickers and the full menu paths can be exercised live).

## References

- `docs/adr/0009-autonomous-orchestrator.md` — the orchestrator the project context wraps.
- `docs/playbooks/running-a-project.md` — the manual/autopilot flow the TUI makes interactive.
- The `simplytammi` Phase 1 review — the source of the documented friction.
