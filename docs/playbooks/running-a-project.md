# Playbook: Running a project end-to-end

> How to take a project from scaffold to release using the AI App Factory, either by manually orchestrating each step or by letting the autonomous loop drive. Pick the mode that matches your trust level for the run.

This playbook complements the operating model in `OPERATING_MODEL.md` and the gating model in `docs/adr/0008-per-slice-and-per-phase-gating.md`. The orchestrator design is in `docs/adr/0009-autonomous-orchestrator.md`.

---

## 1. One-time setup on your machine

The factory is the meta-system. Each project lives in its own folder and references the factory scripts. Add the factory to your `PATH` so you can call its scripts by name from anywhere.

### 1.1 Set `FACTORY_PATH` and update `PATH`

Add to your shell rc file (`.bashrc`, `.zshrc`, or equivalent):

```bash
export FACTORY_PATH=/home/you/repos/ai-app-factory
export PATH="$PATH:$FACTORY_PATH/scripts:$FACTORY_PATH/scripts/orchestrator"
```

Reload your shell. After this, every factory script is callable by name:

```bash
check-cli-tools.sh
scaffold-new-project.sh --name acme-marketing-site --blueprint marketing-site ...
validate-project.sh .
orchestrate.sh
cursor-slice.sh 1.1
codex-slice-review.sh 1.1
claude-phase-review.sh 1
```

If you prefer not to modify `PATH`, every script also works with an absolute path; the playbook examples assume `PATH` is set.

### 1.2 Confirm the CLIs are installed and authenticated

```bash
check-cli-tools.sh
```

Expected: `Summary: 3 ok, 0 missing.` If anything's missing, the script prints the install command and docs URL for that tool. Authenticate each via its env var (`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `CURSOR_API_KEY`) or its interactive login flow.

### 1.3 Make the orchestrator scripts executable (first clone only)

```bash
chmod +x "$FACTORY_PATH"/scripts/*.sh "$FACTORY_PATH"/scripts/orchestrator/*.sh
```

The repo tracks the executable bit in git, so future clones inherit it; this is for the first clone on a new machine.

---

## 2. Scaffold a new project

```bash
scaffold-new-project.sh \
  --name my-project \
  --blueprint marketing-site \
  --goal "<one-line goal>" \
  --users "<primary users>"
```

Defaults: parent dir is the directory containing the factory (sibling layout), `--operator` is "product owner," `--launch-date` is `none`. Pass `--parent <abs-path>` to put the project elsewhere.

The script copies `templates/project-skeleton/` plus the right starter templates for the chosen blueprint, replaces every `<placeholder>` token, and runs `git init` (stages but does not commit — that's your call).

After it finishes:

```bash
cd <new-project-folder>
validate-project.sh .
```

Should pass cleanly. If it fails, the script names what's missing or unfilled.

---

## 3. Intake and design (Claude only, before any gating)

These are user-driven Claude Code sessions. Open the project in Claude Code:

```bash
cd <project-folder>
claude
```

In Claude:

1. `/intake` — Claude leads you through the critical-10 questions and produces `PROJECT.md` at Gate A.
2. `/design` — Claude produces `ARCHITECTURE.md`, the supporting docs (`SECURITY.md`, `THREAT_MODEL.md` if needed, `COST_ESTIMATE.md`, `API_SPEC.md` if needed), the ADRs under `docs/adr/`, and `TASKS.md` populated with phases and slices. Gate B.
3. `/handoff-cursor` — `CURSOR_HANDOFF.md`.
4. `/handoff-codex` — `CODEX_HANDOFF.md`.

After all four, run `validate-project.sh .` again. `TASKS.md` should now have real phases and slices with `### N.M` headings and `Status: pending` lines.

---

## 4. The gating loop: two modes

You can drive the loop manually one slice at a time, or let `orchestrate.sh` dispatch automatically. Both modes use the same adapters and the same `TASKS.md` / `ESCALATIONS.md` state.

### When to pick which mode

- **Manual (Option A)** for your first project, when you want to watch each step, when you're still tuning prompts, or when you're investigating a specific slice failure.
- **Autonomous (Option B)** once you've validated the loop manually for at least one phase and you trust the prompts.

In both modes, set `RUN_PHASE_NO_PUSH=1` for the first runs so commits stay local until you've reviewed them:

```bash
export RUN_PHASE_NO_PUSH=1
```

Drop the var when you trust the loop enough to auto-push.

---

### Option A — Manual step-by-step

For each slice in the current phase:

```bash
# Cursor implements the slice
cursor-slice.sh 1.1
```

The adapter runs Cursor headless against the slice's acceptance criteria, marks `TASKS.md` to `awaiting-review` when done, and commits.

```bash
# Codex reviews the slice
codex-slice-review.sh 1.1
```

The adapter runs Codex headless against the slice's checks. Codex either:

- **Approves** → marks the slice `approved` in `TASKS.md`, commits. Move on to the next slice.
- **Files sub-tasks** → marks the slice `in-progress` again, adds sub-tasks under it in `TASKS.md`, increments the iteration counter. Re-run `cursor-slice.sh 1.1` and Cursor reads the sub-tasks and fixes only those. Then `codex-slice-review.sh 1.1` again.
- **Escalates** → writes to `ESCALATIONS.md`, marks the slice `human-needed`. You resolve and either resume or re-scope.

After all slices in the phase are `approved`, `TASKS.md` shows the Phase review entry transitioning to `awaiting-review` (the Codex review adapter flips it deterministically when it approves the last slice in the phase).

```bash
# Claude reviews the phase as a whole
claude-phase-review.sh 1
```

The adapter runs Claude headless to look at the phase's *integrated* result (not slice-by-slice). Claude either approves, files phase-level sub-tasks (which route specific slices back to `in-progress`), or escalates.

Repeat for each phase. After the final phase approves, `TASKS.md` reports done.

---

### Option B — Autonomous orchestrator

```bash
orchestrate.sh
```

The orchestrator reads `TASKS.md`, picks the next actionable item, dispatches to the matching adapter, and loops. It halts at one of three terminal states:

- **Exit 0** — every slice and phase review is `approved`. Project done.
- **Exit 2** — human intervention needed. Read `ESCALATIONS.md` for the open items, address them, edit `TASKS.md` to clear `human-needed` or `blocked` statuses, then re-invoke `orchestrate.sh`.
- **Exit 1** — unrecoverable error (adapter failure, push failure, missing required file). Investigate via `.factory-logs/`.

You can also point the orchestrator at a different project:

```bash
orchestrate.sh --project /abs/path/to/other-project
```

### Branch model and `main`

Each adapter runs on its own `<tool>/phase-<timestamp>` branch (auto-created by the safety lib if the current branch does not match). Those branches chain linearly — each is created off the previous one — so the newest branch contains every prior commit.

`main` is advanced by fast-forward only, never by force:

- After each phase review is approved, the orchestrator fast-forwards `main` to the current branch's HEAD.
- After the Gate D sign-off adapter runs, and again after the final all-signed run, it fast-forwards once more.

So `main` always points at the latest approved state and a fresh clone gets the real project, not a transient work branch. If a fast-forward is ever rejected — meaning `main` carries commits that are not on the work branch (someone pushed to `main` directly, or two runs diverged) — the orchestrator does **not** force. It writes a `factory_advance_main_failed` escalation and halts so a human can reconcile.

---

## 5. The Codex sandbox: a real environment limitation

The OpenAI Codex CLI runs each session in a sandbox that — by default — blocks localhost binding (no `astro dev`, no `swa start`, no Functions host on port 7071). This is the most common surprise during a Phase 2+ slice review where Codex wants to start a server and `curl -I` against it.

Two ways to handle it:

### Option 1: Loosen the Codex sandbox

```bash
export RUN_PHASE_CODEX_APPROVAL_FLAG="--sandbox danger-full-access"
```

The exact flag name varies by Codex CLI version. Verify with:

```bash
codex exec --help | grep -i sandbox
```

Common names: `--sandbox danger-full-access`, `--full-auto`. The factory adapter passes whatever you set via `RUN_PHASE_CODEX_APPROVAL_FLAG` straight through.

This is the right call for **factory testing on a trusted machine**. The factory's whole orchestration model already grants AI agents file write access; the sandbox restriction is over-correction inside the gating loop.

### Option 2: Let Codex improvise

If you prefer to keep the sandbox tight, Codex falls back to:

- Config-level verification (parsing `staticwebapp.config.json` and asserting headers exist)
- Schema validation (validating config against the SWA JSON schema)
- **Module-level instrumentation** — importing the framework's own response middleware and calling it with fake req/res to capture behavior

The test project's slice 1.3 review was approved this way: Codex imported SWA CLI's `getStorageContent()` and asserted that the configured headers were applied to a `/` request. Creative but not as direct as `curl -I` against a live server.

For a real production project where every slice's behavior matters, prefer Option 1.

---

## 6. Common situations

### A slice keeps coming back with sub-tasks

After 2 Codex review rounds, the iteration counter is at 2/3. One more round of `sub-tasks-filed` will push to 3/3 and trigger an `iteration-cap-hit` escalation.

If you see this approaching:

- Read the sub-task pattern. Is the slice mis-scoped? (Codex finds new issues each round because the scope is too broad.) → Split the slice.
- Is the acceptance criterion ambiguous? → Edit `ARCHITECTURE.md` Work Breakdown for that slice, then resume.
- Is Codex moving goalposts? → Escalate to Claude for an ADR clarifying the contract.

### Phase review files sub-tasks

Claude finds an integration issue (e.g., slices use inconsistent error formats). Claude adds phase-level sub-tasks to `TASKS.md` under the Phase review entry and routes specific slices back to `in-progress`. Resume the loop; Cursor will pick those slices up first.

### Push fails mid-loop

`rpl_commit_and_push` halts the entire run on push failure (auth, network, non-fast-forward). Resolve the push manually (`git pull --rebase` or `git push --force-with-lease` if you understand the risk), then re-invoke the orchestrator. The lib's safe-stage guarantees the commits already made are safe.

### You want to inspect what an adapter did

All adapter logs land under `<project>/.factory-logs/<adapter>_<timestamp>/work.log` inside the project (gitignored by the skeleton). The orchestrator's own log is under `<project>/.factory-logs/orchestrate_<timestamp>/`.

---

## 7. Gate D sign-off and release

When the final phase completes, the run is not done until the six-party Gate D sign-off in `SIGNOFF.md` is complete (`docs/adr/0013-configurable-roles-and-tools.md`): architect, developer, quality engineer, security, code review, and product owner.

In **autonomous mode**, the orchestrator handles the five agent sign-offs for you. Once every phase gate (review, security, code-review) is `approved` and `SIGNOFF.md` is still the unfilled template, it dispatches `gate-d-signoff.sh`, which runs five sub-sessions — each driven by the tool that role is mapped to in `.factory-roles.json` — that fill their sections of `SIGNOFF.md`, then writes a product-owner escalation to `ESCALATIONS.md` and exits 2. In **manual mode**, run it yourself:

```bash
gate-d-signoff.sh
```

Then close out the release:

1. Complete the product-owner section of `SIGNOFF.md` (Decision, Notes, Signed) — accept any documented risks and authorize the release — then commit it so the final fast-forward can carry it to `main`.
2. Finalize `RELEASE_CHECKLIST.md` — any deferred items get explicit deferral notes.
3. Run `validate-project.sh .` one more time. It checks that `SIGNOFF.md` is fully signed once every phase review is `approved`.
4. Re-run `orchestrate.sh` one last time (autonomous mode): it detects all six sign-offs and exits 0.
5. Tag the release in git, deploy per `RUNBOOK.md`.

---

## 8. Quick reference card

| Step | Command |
|---|---|
| Setup (once) | `export FACTORY_PATH=...; export PATH=...` |
| Tool check | `check-cli-tools.sh` |
| Scaffold | `scaffold-new-project.sh --name ... --blueprint ... --goal "..." --users "..."` |
| Validate project | `validate-project.sh .` |
| Refresh a project (drift check) | `refresh-project.sh <project-path>` |
| Intake (Claude UI) | `/intake` |
| Design (Claude UI) | `/design` |
| Cursor handoff (Claude UI) | `/handoff-cursor` |
| Codex handoff (Claude UI) | `/handoff-codex` |
| Manual: one slice | `RUN_PHASE_NO_PUSH=1 cursor-slice.sh <id>` |
| Manual: one review | `RUN_PHASE_NO_PUSH=1 codex-slice-review.sh <id>` |
| Manual: one phase | `RUN_PHASE_NO_PUSH=1 claude-phase-review.sh <id>` |
| Autonomous | `RUN_PHASE_NO_PUSH=1 orchestrate.sh` |
| Gate D sign-off (manual) | `gate-d-signoff.sh` |
| Codex sandbox open | `export RUN_PHASE_CODEX_APPROVAL_FLAG="--sandbox danger-full-access"` |
| Factory health | `factory-status.sh` |

## 9. References

- `OPERATING_MODEL.md` — overall factory model
- `docs/adr/0013-configurable-roles-and-tools.md` — five roles, per-phase security + code-review gates, six-party Gate D sign-off (supersedes ADR-0006)
- `docs/adr/0008-per-slice-and-per-phase-gating.md` — gating model + budget caps
- `docs/adr/0009-autonomous-orchestrator.md` — orchestrator design
- `docs/adr/0010-gate-d-signoff-adapter.md` — Gate D sign-off adapter
- `scripts/orchestrator/README.md` — orchestrator details
