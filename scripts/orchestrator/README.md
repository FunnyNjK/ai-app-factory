# Orchestrator

Autonomous bash orchestrator for the AI App Factory's per-slice and per-phase gating model. Reads a project's `TASKS.md`, picks the next actionable item, dispatches to the matching role-specific adapter, and loops until the project is done or human intervention is needed.

See [docs/adr/0008-per-slice-and-per-phase-gating.md](../../docs/adr/0008-per-slice-and-per-phase-gating.md) for the gating model and [docs/adr/0009-autonomous-orchestrator.md](../../docs/adr/0009-autonomous-orchestrator.md) for the orchestrator design.

## Files

| File | Role |
|---|---|
| `orchestrate.sh` | Top-level loop. Reads `TASKS.md`, picks next action, dispatches, loops. |
| `cursor-slice.sh` | Adapter — one slice implementation via Cursor CLI (`agent`). |
| `codex-slice-review.sh` | Adapter — one slice review via Codex CLI (`codex exec`). |
| `claude-phase-review.sh` | Adapter — one phase review via Claude Code CLI (`claude`). |
| `lib.sh` | Shared safety + TASKS.md helpers. Sourced by every script. |

## Prerequisites

- Ubuntu 22+ (or any Linux with bash, GNU coreutils, Python 3.8+, git). macOS works. Windows requires WSL or Git Bash.
- Each AI CLI installed and authenticated:
  - **Claude Code** — `npm install -g @anthropic-ai/claude-code`. Auth: `claude` (interactive) or `ANTHROPIC_API_KEY`.
  - **Codex CLI** — `npm install -g @openai/codex`. Auth: `codex login` or `OPENAI_API_KEY`.
  - **Cursor CLI** — `curl https://cursor.com/install -fsS | bash`. Auth: `agent login` or `CURSOR_API_KEY`.
- The project to be orchestrated must contain a project TASKS.md and ESCALATIONS.md (from `templates/project-skeleton/`) plus ARCHITECTURE.md, CLAUDE.md, AGENTS.md, `<project>/.cursor/rules/developer.mdc`, and CURSOR_HANDOFF.md.

After cloning the factory, make the scripts executable:

```bash
chmod +x scripts/orchestrator/*.sh scripts/*.sh
```

Confirm the three CLIs are installed and authenticated before the first run:

```bash
scripts/check-cli-tools.sh
```

## Usage

From the project root:

```bash
/path/to/ai-app-factory/scripts/orchestrator/orchestrate.sh
```

Or with an explicit project path:

```bash
/path/to/ai-app-factory/scripts/orchestrator/orchestrate.sh --project /abs/path/to/project
```

The orchestrator runs to one of three terminal states:

- **Exit 0** — every slice and phase review is `approved`. Project done.
- **Exit 2** — human intervention needed (iteration cap hit, escalation, ambiguous decision). Read `ESCALATIONS.md` to find the open items, address them, edit `TASKS.md` to clear `human-needed` or `blocked` statuses, then re-invoke the orchestrator.
- **Exit 1** — unrecoverable error (adapter failure, push failure, missing required file).

## Env vars

| Var | Default | Purpose |
|---|---|---|
| `FACTORY_MAX_OUTER_ITER` | `200` | Hard ceiling on the outer loop. Stops runaway loops if state is corrupted. |
| `FACTORY_WALL_TIME_SEC` | `1800` | Per-adapter wall-time cap. Each adapter wraps its CLI in `timeout`. |
| `FACTORY_TOKEN_CAP` | `100000` | Per-session token cap (passed to adapters; mapping depends on each CLI). |
| `RUN_PHASE_NO_PUSH` | `0` | Set to `1` to commit but skip `git push`. |
| `RUN_PHASE_AUTO_BRANCH` | `1` | Auto-create a `<tool>/phase-<timestamp>` branch if the current branch does not match. |
| `RUN_PHASE_ALLOW_DIRTY` | `0` | Refuse to start on a dirty worktree (override at your own risk). |
| `RUN_PHASE_ALLOWLIST_REGEX` | unset | Extra ERE restricting which changed paths may be staged. |
| `RUN_PHASE_FORCE_UNSAFE` | `0` | Bypass sensitive-path refusal (NOT recommended). |
| `RUN_PHASE_CLAUDE_MODEL` | unset | Pin a specific Claude model. |
| `RUN_PHASE_CODEX_MODEL` | unset | Pin a specific Codex model. |
| `RUN_PHASE_CURSOR_MODEL` | unset | Pin a specific Cursor model. |
| `RUN_PHASE_CLAUDE_MAX_TURNS` | unset | Pass `--max-turns` to Claude (version-dependent). |
| `RUN_PHASE_CODEX_APPROVAL_FLAG` | unset | Append a Codex approval-bypass flag (e.g. `--ask-for-approval=never`; name varies by version). |

## Status-line contract

Every adapter writes a final line to stdout of the form:

```text
 FACTORY_STATUS={"role":"...","action":"...","slice":"...","phase":"...","status":"...","details":"...","sub_tasks":[...]}
```

(Indented one space in this document so it does not look like an env-var assignment to tooling; the AI emits the line flush-left in adapter logs.)

`status` is one of:

- `implementation-complete` — Cursor finished a slice; marked `awaiting-review` in `TASKS.md`.
- `approved` — Codex (slice) or Claude (phase) approved.
- `sub-tasks-filed` — Codex or Claude added sub-tasks under the slice/phase; orchestrator increments the iteration counter.
- `escalated` — adapter wrote to `ESCALATIONS.md`; orchestrator halts with exit 2.
- `error` — adapter could not complete; orchestrator halts with exit 1.

The orchestrator decides what to do next based on the adapter's exit code, not the JSON contents. The JSON is for observability and downstream tooling.

## Safety inherited from the prior research

- **Sensitive-path refusal.** `lib.sh` will not stage `.env`, `.aws/`, `.ssh/`, `*.pem`, `*.key`, `id_rsa`, `*.sqlite3`, `credentials*`, and similar. Fail-closed; the run halts rather than commits.
- **Push-on-failure stop.** If `git push` fails (auth, network, non-fast-forward), the orchestrator halts. No piling commits on a drifted local branch.
- **Dirty-tree precheck.** Refuses to start with uncommitted changes unless `RUN_PHASE_ALLOW_DIRTY=1`.
- **Auto-branch.** Each adapter checks the branch matches its expected `<tool>/*` prefix; auto-creates `<tool>/phase-<timestamp>` if not.

These come from [docs/research/headless-cli/run-phase-lib.sh](../../docs/research/headless-cli/run-phase-lib.sh), adapted into `lib.sh`. The research scripts are kept under `docs/research/` for reference.

## Untested end-to-end

The orchestrator has not yet been validated against a real AI session. The product owner plans to run two test projects through it to validate the workflow. After those runs, expect adjustments to:

- Prompt wording (whatever the AI tools consistently misread or skip).
- Budget cap defaults in [docs/adr/0008-per-slice-and-per-phase-gating.md](../../docs/adr/0008-per-slice-and-per-phase-gating.md).
- Status-line contract (if any tool refuses to emit it reliably).
- Per-tool CLI flag sets (the research notes these change month-to-month).

Real failures will reveal what to harden. Treat this version as a v0.

## Debugging an adapter in isolation

Each adapter can be run directly without the orchestrator:

```bash
cd /path/to/project
/path/to/ai-app-factory/scripts/orchestrator/cursor-slice.sh 1.2
/path/to/ai-app-factory/scripts/orchestrator/codex-slice-review.sh 1.2
/path/to/ai-app-factory/scripts/orchestrator/claude-phase-review.sh 1
```

Logs land under `<project>/.factory-logs/<adapter>_<timestamp>/work.log`. The orchestrator's own logs are under `<project>/.factory-logs/orchestrate_<timestamp>/`.

## Adding a new adapter

If you add a Gemini or Copilot adapter in the future:

1. Copy one of the existing adapters as a template.
2. Update `TOOL_NAME`, `TOOL_LOG_PREFIX`, `TOOL_SCRIPT`.
3. Replace `rpl_require_tool` arguments with the new tool's name, install command, and docs URL.
4. Replace the CLI invocation block with the new tool's flag set (cross-reference [docs/research/headless-cli/](../../docs/research/headless-cli/) for prior art on Gemini and Copilot).
5. Adjust `orchestrate.sh` dispatcher case-statement to recognize the new role.
6. Write a new ADR documenting why the new adapter was added.
