#!/usr/bin/env bash
# run-phase-codex.sh — run N consecutive tasks autonomously via OpenAI Codex CLI (`codex`).
# Each task: work → handoff → commit → push.
#
# This is the OpenAI Codex adapter. It is one of FIVE tool-specific
# harnesses — see also run-phase.sh (Claude), run-phase-cursor.sh,
# run-phase-copilot.sh, run-phase-gemini.sh. Shared safety/session mechanics live in
# scripts/run-phase-lib.sh; this script keeps the Codex-specific CLI
# invocation because Codex's `exec` / `exec resume` flag sets differ
# materially from the other CLIs.
#
# Usage:
#   ./run-phase-codex.sh <num_tasks>                    # commit + push (default)
#   RUN_PHASE_NO_PUSH=1 ./run-phase-codex.sh <num_tasks> # commit, skip push
#
# Prerequisites:
#   - Codex CLI installed: npm install -g @openai/codex
#     (or use the Rust binary distribution from the project README).
#   - Authenticate once: `codex login` (or set OPENAI_API_KEY for headless / CI).
#   - Docs: https://github.com/openai/codex
#
# Optional env vars:
#   - RUN_PHASE_NO_PUSH=1                — commit but skip push.
#   - RUN_PHASE_CODEX_MODEL="..."        — pin a specific model.
#   - RUN_PHASE_CODEX_APPROVAL_FLAG="--ask-for-approval=never"
#       — append your version's approval-bypass flag (name varies; verify
#         with `codex exec --help`). Leave unset to omit.
#   - RUN_PHASE_AUTO_BRANCH=0            — fail instead of auto-creating
#                                          a codex/* branch when needed.
#   - RUN_PHASE_ALLOW_DIRTY=1            — allow a dirty worktree before
#                                          the run starts. NOT recommended.
#   - RUN_PHASE_ALLOWLIST_REGEX="..."    — extra ERE restricting which
#                                          changed paths may be staged.
#   - RUN_PHASE_FORCE_UNSAFE=1           — override sensitive-path
#                                          refusal. NOT recommended.
#
# IMPORTANT: Codex CLI flag names evolve quickly. The defaults below stick
# to the most universally supported flag (`--sandbox workspace-write`) and
# let you opt in to version-specific extras via env vars. Verify with
# `codex exec --help` before relying on this in production. Note that
# `codex exec` and `codex exec resume` accept different flag sets — this
# script uses separate arrays so they don't collide.
#
# Staging safety: see scripts/run-phase-lib.sh — only session-changed
# files are staged, sensitive paths are refused fail-closed.
#
# Push behavior follows the Git Rules in /ai/AI_RULES.md: push after every
# successful commit unless explicitly disabled. If a push fails (auth,
# network, non-fast-forward), the script stops — do NOT silently keep
# committing on top of an out-of-sync local branch.
#
# Run from your project root (where /ai/ lives).

set -euo pipefail

# Prefer common user-local install paths.
export PATH="${HOME}/.local/bin:${HOME}/.npm-global/bin:${PATH}"

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/run-phase-lib.sh
. "$SCRIPT_DIR/scripts/run-phase-lib.sh"

TOOL_NAME="Codex"
TOOL_LOG_PREFIX="run_codex"
TOOL_SCRIPT="run-phase-codex.sh"

rpl_require_tool codex \
  "npm install -g @openai/codex" \
  "https://github.com/openai/codex"

TASKS=${1:?Usage: $0 <num_tasks>   e.g.  ./run-phase-codex.sh 8}

rpl_preflight

LOG_DIR=$(rpl_init_log_dir)
START_PROMPT=$(rpl_start_prompt)
END_PROMPT=$(rpl_end_prompt)

# --- Tool-specific CLI flags. ---
#
# Headless automation. Codex CLI flag names evolve quickly — verify your
# installed version with `codex exec --help` before relying on this.
#
# `codex exec` (initial call) and `codex exec resume` accept different flag
# sets — resume inherits most settings from the original session — so we
# keep them separate. The defaults below stick to the most universally
# supported flag (`--sandbox workspace-write`) and let you opt in to
# version-specific extras via env vars.
CODEX_EXEC_FLAGS=(
  --sandbox workspace-write
)

CODEX_RESUME_FLAGS=()

# Optional approval-bypass flag. The exact name varies by Codex version
# (e.g. `--ask-for-approval never`, `--full-auto`, etc.). Verify with
# `codex exec --help` and set this to whatever your version accepts:
#   RUN_PHASE_CODEX_APPROVAL_FLAG="--ask-for-approval=never"
# Leave unset if your version doesn't have one.
if [ -n "${RUN_PHASE_CODEX_APPROVAL_FLAG:-}" ]; then
  # Split on whitespace so users can pass either "--flag" or "--flag value".
  read -r -a _approval <<< "$RUN_PHASE_CODEX_APPROVAL_FLAG"
  CODEX_EXEC_FLAGS+=("${_approval[@]}")
fi

# Optional: pin model, e.g. RUN_PHASE_CODEX_MODEL="gpt-5-codex"
if [ -n "${RUN_PHASE_CODEX_MODEL:-}" ]; then
  CODEX_EXEC_FLAGS+=(--model "$RUN_PHASE_CODEX_MODEL")
  # Don't pass --model on resume; it's locked to the original session.
fi

echo "Starting $TOOL_NAME phase run: $TASKS tasks. Logs -> $LOG_DIR"

for i in $(seq 1 "$TASKS"); do
  printf '\n========== Task %d of %d ==========\n' "$i" "$TASKS"

  log "Step 1/3: working on next task (codex exec)..."
  codex exec "${CODEX_EXEC_FLAGS[@]}" "$START_PROMPT" \
    2>&1 | tee "$LOG_DIR/task_${i}_work.log"

  log "Step 2/3: writing handoff (codex exec resume --last)..."
  if [ ${#CODEX_RESUME_FLAGS[@]} -gt 0 ]; then
    codex exec resume --last "${CODEX_RESUME_FLAGS[@]}" "$END_PROMPT" \
      2>&1 | tee "$LOG_DIR/task_${i}_handoff.log"
  else
    codex exec resume --last "$END_PROMPT" \
      2>&1 | tee "$LOG_DIR/task_${i}_handoff.log"
  fi

  log "Step 3/3: staging + committing + pushing..."
  SUBJECT=$(rpl_extract_subject "$LOG_DIR/task_${i}_handoff.log" \
            "Phase task $i (auto, $TOOL_NAME)")

  set +e
  rpl_commit_and_push "$SUBJECT" "$LOG_DIR/task_${i}_handoff.log"
  rc=$?
  set -e
  case "$rc" in
    0) ;;
    2) log "ℹ️  No changes after task $i; nothing to commit or push." ;;
    *) exit 1 ;;
  esac

  log "✅ Task $i complete."
done

echo
echo "🎉 $TOOL_NAME phase complete: $TASKS tasks done."
echo "Logs: $LOG_DIR"
