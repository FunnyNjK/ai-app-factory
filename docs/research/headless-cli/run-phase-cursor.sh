#!/usr/bin/env bash
# run-phase-cursor.sh — run N consecutive tasks autonomously via Cursor CLI (`agent`).
# Each task: work → handoff → commit → push.
#
# This is the Cursor adapter. It is one of FIVE tool-specific harnesses —
# see also run-phase.sh (Claude), run-phase-codex.sh, run-phase-copilot.sh,
# run-phase-gemini.sh.
# Shared safety/session mechanics live in scripts/run-phase-lib.sh; this
# script keeps the Cursor-specific CLI invocation because Cursor's
# `agent` subcommand uses different flags (`--trust`, `--sandbox`,
# `--output-format`) than the other CLIs.
#
# Usage:
#   ./run-phase-cursor.sh <num_tasks>                    # commit + push (default)
#   RUN_PHASE_NO_PUSH=1 ./run-phase-cursor.sh <num_tasks> # commit, skip push
#
# Prerequisites:
#   - Cursor CLI installed: curl https://cursor.com/install -fsS | bash
#     (default install path: ~/.local/bin)
#   - Authenticate once: `agent login` (or set CURSOR_API_KEY for headless / CI).
#   - Docs: https://cursor.com/docs/cli
#
# Optional env vars:
#   - RUN_PHASE_NO_PUSH=1            — commit but skip push.
#   - RUN_PHASE_CURSOR_MODEL="..."   — pin a specific model
#                                      (e.g. "composer-2").
#   - RUN_PHASE_AUTO_BRANCH=0        — fail instead of auto-creating
#                                      a cursor/* branch when needed.
#   - RUN_PHASE_ALLOW_DIRTY=1        — allow a dirty worktree before
#                                      the run starts. NOT recommended.
#   - RUN_PHASE_ALLOWLIST_REGEX="..." — extra ERE restricting which
#                                       changed paths may be staged.
#   - RUN_PHASE_FORCE_UNSAFE=1       — override sensitive-path
#                                      refusal. NOT recommended.
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

# Prefer Cursor CLI on PATH (install default: ~/.local/bin).
export PATH="${HOME}/.local/bin:${PATH}"

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/run-phase-lib.sh
. "$SCRIPT_DIR/scripts/run-phase-lib.sh"

TOOL_NAME="Cursor"
TOOL_LOG_PREFIX="run_cursor"
TOOL_SCRIPT="run-phase-cursor.sh"

rpl_require_tool agent \
  "curl https://cursor.com/install -fsS | bash" \
  "https://cursor.com/docs/cli"

TASKS=${1:?Usage: $0 <num_tasks>   e.g.  ./run-phase-cursor.sh 8}

rpl_preflight

LOG_DIR=$(rpl_init_log_dir)
START_PROMPT=$(rpl_start_prompt)
END_PROMPT=$(rpl_end_prompt)

# --- Tool-specific CLI flags. ---
# Headless automation: trust repo, allow tool/shell actions without
# interactive approval. Cursor CLI has no equivalent to Claude Code's
# --max-turns; omit here.
CURSOR_AGENT_FLAGS=(
  --trust
  --force
  --sandbox
  disabled
  --output-format
  text
)

# Optional: pin model, e.g. RUN_PHASE_CURSOR_MODEL="composer-2"
if [ -n "${RUN_PHASE_CURSOR_MODEL:-}" ]; then
  CURSOR_AGENT_FLAGS+=(--model "$RUN_PHASE_CURSOR_MODEL")
fi

echo "Starting $TOOL_NAME phase run: $TASKS tasks. Logs -> $LOG_DIR"

for i in $(seq 1 "$TASKS"); do
  printf '\n========== Task %d of %d ==========\n' "$i" "$TASKS"

  log "Step 1/3: working on next task (agent -p)..."
  agent -p "${CURSOR_AGENT_FLAGS[@]}" -- "$START_PROMPT" \
    2>&1 | tee "$LOG_DIR/task_${i}_work.log"

  log "Step 2/3: writing handoff (agent --continue -p)..."
  agent --continue -p "${CURSOR_AGENT_FLAGS[@]}" -- "$END_PROMPT" \
    2>&1 | tee "$LOG_DIR/task_${i}_handoff.log"

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
