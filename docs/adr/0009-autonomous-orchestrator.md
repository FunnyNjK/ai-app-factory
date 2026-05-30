# ADR-0009: Autonomous bash orchestrator for the gating loop

## Document metadata

| Field | Value |
|---|---|
| Number | 0009 |
| Date | 2026-05-26 |
| Author | Architect (Claude) |
| Approval owner | Product owner |
| Supersedes | None — extends `docs/adr/0008-per-slice-and-per-phase-gating.md` |

## Status

Proposed

## Context

`docs/adr/0008-per-slice-and-per-phase-gating.md` defined the per-slice (Cursor ↔ Codex) and per-phase (Codex → Claude) gating model. Stage 1 of that ADR shipped the manual flow: the product owner moves work between AI tool sessions by hand, reading `TASKS.md` and `ESCALATIONS.md`.

Stage 2 automates the manual handoffs so the product owner only intervenes for:

- Escalations written to `ESCALATIONS.md` (iteration cap, judgment call, secret needed).
- Phase boundaries where the product owner explicitly wants a check-in.
- External resources (browser verification, vendor account work, DNS, key rotation).

The product owner has prior research from another project — five per-tool harness scripts (`run-phase.sh`, `run-phase-codex.sh`, `run-phase-cursor.sh`, plus Gemini and Copilot variants) and a shared safety library `run-phase-lib.sh`. Those scripts are documented under `docs/research/headless-cli/` and were validated on Ubuntu. They share a common pattern: one tool runs N tasks per phase, work → handoff → commit → push.

Two constraints from that research must change for the factory:

1. **Tool switching.** The research scripts run one tool per phase. The factory's gating model requires switching tools per slice (Cursor implements → Codex reviews → Cursor fixes → Codex re-reviews → ... → Claude reviews the phase). The orchestrator owns the switching loop; per-tool adapters handle one task per invocation.
2. **Planning-file convention.** The research uses an ai/ directory layout (ai/TASKS.md with `### P0-T1` IDs, ai/DECISIONS.md aggregating all ADRs, ai/CURRENT_STATE.md capped at 80 lines, etc.) The factory uses per-project artifacts at project root (a project TASKS.md with `### 1.1` slice IDs, `docs/adr/*.md` per-decision files). Stage 2 adopts the factory convention. The research's universal mechanics (sensitive-path refusal, NUL-safe path enumeration, dirty-worktree check, push-on-failure stop) port over unchanged.

## Decision

The factory ships a bash orchestrator under `scripts/orchestrator/` with these components:

### Files

- `scripts/orchestrator/orchestrate.sh` — top-level loop. Reads `<project>/TASKS.md`, picks the next actionable item, dispatches to the matching adapter, parses the adapter's structured output, updates `<project>/TASKS.md` and `<project>/ESCALATIONS.md`, enforces budget caps. Halts on terminal state or human-needed escalation.
- `scripts/orchestrator/cursor-slice.sh` — one slice implementation via Cursor CLI (`agent`).
- `scripts/orchestrator/codex-slice-review.sh` — one slice review via Codex CLI (`codex exec`).
- `scripts/orchestrator/claude-phase-review.sh` — one phase review via Claude Code (`claude`).
- `scripts/orchestrator/lib.sh` — shared safety mechanics adapted from `docs/research/headless-cli/run-phase-lib.sh`. Preserves: timestamped logging, log-dir layout, preflight (git worktree + dirty-tree + branch check + auto-branch), sensitive-path refusal regex, NUL-safe path enumeration, safe-stage with allowlist, commit-and-push with stop-on-failure, tool presence check.

### Adapter contract

Every adapter writes a single structured status line to stdout on exit, in addition to the human log. The orchestrator parses the LAST line matching the `^FACTORY_STATUS=` prefix as JSON:

```text
 FACTORY_STATUS={"role":"cursor|codex|claude","action":"slice|slice-review|phase-review","slice":"1.2","phase":"1","status":"approved|sub-tasks-filed|escalated|error","details":"...","sub_tasks":["..."]}
```

(Indented one space in this document so it does not look like an env-var assignment to tooling; the AI emits the line flush-left in adapter logs.)

Adapters do not modify `TASKS.md` or `ESCALATIONS.md` themselves — they emit the status line, and the orchestrator applies the change. This keeps the file-update logic in one place.

### Budget enforcement

Caps from `TASKS.md` header (or factory defaults from ADR-0008) are enforced by the orchestrator before each adapter invocation:

| Cap | Enforcement |
|---|---|
| Per-task iterations | Orchestrator increments counter on each cursor-slice or codex-slice-review for a given slice. At cap+1, halts with escalation. |
| Per-phase iterations | Same, for claude-phase-review of a given phase. |
| Per-session token cap | `FACTORY_TOKEN_CAP` is reserved but **not enforced** — no headless CLI exposes a universal token-cap flag. Wall-time (`FACTORY_WALL_TIME_SEC`) is the enforced per-session bound; Claude also honors `--max-turns` via `RUN_PHASE_CLAUDE_MAX_TURNS`. |
| Per-session wall time | Adapter wraps the CLI call in `timeout <seconds>` (GNU coreutils). |
| Per-project budget USD | A target recorded in the `<project>/TASKS.md` budget header for the human. The orchestrator does **not** compute or enforce per-session dollar cost today (there is no token/cost accounting); the wall-time and iteration caps are the enforced bounds. |

Cap hits are non-recoverable inside the loop. The orchestrator writes an `ESCALATIONS.md` entry and exits with code 2 (human-needed). The product owner unblocks by editing `TASKS.md` or `ESCALATIONS.md` and re-invoking the orchestrator.

### Safety inherited from the research

- **Sensitive-path refusal:** the adapter scripts and the orchestrator both invoke `rpl_commit_and_push` from `lib.sh`, which refuses to stage `.env`, `.aws/`, `.ssh/`, `*.pem`, `*.key`, `*.sqlite3`, `*.db`, `credentials*`, `id_rsa`, and similar. Fail-closed; the run halts rather than committing.
- **Push-on-failure stop:** if a push fails (auth, network, non-fast-forward), the orchestrator stops the entire run rather than piling more commits on a drifted local branch.
- **Dirty-tree precheck:** the orchestrator refuses to start if the project worktree has uncommitted changes (unless `RUN_PHASE_ALLOW_DIRTY=1`).
- **Auto-branch:** if the current branch does not match the expected `<tool>/*` prefix, a new branch is created under `<tool>/phase-<timestamp>`.

### Invocation

From the project root:

```bash
<factory>/scripts/orchestrator/orchestrate.sh
```

Or from anywhere with an explicit project path:

```bash
<factory>/scripts/orchestrator/orchestrate.sh --project /abs/path/to/project
```

Optional flags and env vars are documented in `scripts/orchestrator/README.md`.

## Alternatives considered

1. **Node.js orchestrator + bash adapters (hybrid).** Recommended in the earlier discussion; rejected by the product owner in favor of pure bash. Bash matches the existing research and the Ubuntu deployment target. The factory's Node validator stays where it is — it does not need to share a language with the orchestrator.
2. **PowerShell-native.** Rejected because the deployment target is Ubuntu; PowerShell on Linux works but loses the prior art.
3. **Single bash script (no per-role adapters).** Rejected. Tool-specific CLI flag drift is real (the research documents it carefully); isolating it in adapters keeps the orchestrator stable when one tool's CLI changes.
4. **Reuse research scripts as-is (one tool per phase).** Rejected. The factory needs tool switching every slice; the research's N-tasks-per-tool loop is the wrong shape.
5. **No budget enforcement.** Rejected. ADR-0008 already committed to budget caps; enforcing them in the orchestrator is the natural place.

## Consequences

### Positive

- Reuses the research's battle-tested safety mechanics with no reinvention.
- Each adapter is independently testable (a fake CLI that emits a known `FACTORY_STATUS=` line lets us test the orchestrator without spending API tokens).
- Tool-specific CLI flag drift stays isolated to one adapter per tool.
- Budget enforcement is centralized; cap hits are a single code path.
- The structured status line makes the orchestrator's decision logic explicit and parseable.

### Negative

- Pure bash limits Windows-native use; Ubuntu and macOS work directly, Windows requires WSL or Git Bash. The factory's target is Ubuntu, so this is acceptable.
- The orchestrator is **untested end-to-end** until run against a real project with valid API keys. The first two test projects (per the project owner's plan) will exercise it.
- Per-session cost is estimated, not measured directly. Each tool's CLI does not return a cost or token count in a standard format. The estimate uses configurable per-model rates in `TASKS.md`.

### Neutral

- Adapters do not modify `TASKS.md` directly. Some teams might prefer adapters to write to the tracker themselves; the centralized-writer approach trades a small amount of coupling for a much simpler audit story.
- The orchestrator does not parallelize. Slice N+1 only starts after slice N is approved; the design is deliberately serial per ADR-0008.

## Follow-up

- Create the orchestrator scripts under `scripts/orchestrator/`: `orchestrate.sh`, `cursor-slice.sh`, `codex-slice-review.sh`, `claude-phase-review.sh`, and `lib.sh`.
- Write `scripts/orchestrator/README.md` documenting setup, env vars, and the status-line contract.
- Register the new files in `MANIFEST.md` and `scripts/validate-factory.mjs` `requiredFiles`.
- Validate end-to-end on the first two test projects (per the project owner's plan).
- After the first real run, revisit budget cap defaults from ADR-0008 with observed numbers.
- Future: add Gemini and Copilot adapters if the team wants those tools in rotation.

## References

- `docs/adr/0008-per-slice-and-per-phase-gating.md` — the gating model this orchestrator automates
- `docs/research/headless-cli/run-phase-lib.sh` — research lib being adapted
- `docs/research/headless-cli/run-phase.sh` — research Claude adapter
- `docs/research/headless-cli/run-phase-codex.sh` — research Codex adapter
- `docs/research/headless-cli/run-phase-cursor.sh` — research Cursor adapter
- `templates/project-skeleton/TASKS.md` — per-project task tracker the orchestrator reads
- `templates/project-skeleton/ESCALATIONS.md` — human review queue the orchestrator appends to
