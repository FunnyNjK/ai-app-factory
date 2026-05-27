#!/usr/bin/env bash
# run-phase-gemini.sh — run N consecutive tasks autonomously via Google
# Gemini CLI (`gemini`).
# Each task: work → handoff → commit → push.
#
# This is the Google Gemini adapter. It is one of FIVE tool-specific
# harnesses — see also run-phase.sh (Claude), run-phase-codex.sh,
# run-phase-cursor.sh, run-phase-copilot.sh. Shared safety/session
# mechanics live in scripts/run-phase-lib.sh; this script keeps the
# Gemini-specific CLI invocation because Gemini's command shape and
# flag spelling differ from the other tools.
#
# Usage:
#   ./run-phase-gemini.sh <num_tasks>                    # commit + push (default)
#   RUN_PHASE_NO_PUSH=1 ./run-phase-gemini.sh <num_tasks> # commit, skip push
#
# Prerequisites:
#   - Gemini CLI installed: npm install -g @google/gemini-cli
#     (or use the binary distribution from the project README).
#   - Authenticate once: run `gemini` interactively to log in via Google,
#     or set GEMINI_API_KEY for headless / CI usage.
#   - Docs: https://github.com/google-gemini/gemini-cli
#
# Optional env vars:
#   - RUN_PHASE_NO_PUSH=1                — commit but skip push.
#   - RUN_PHASE_GEMINI_MODEL="..."       — pin a specific model
#                                          (e.g. "gemini-2.5-pro").
#   - RUN_PHASE_GEMINI_YOLO_FLAG="--yolo"
#       — append your version's auto-approve / "skip approval" flag (name
#         varies; verify with `gemini --help`). Leave unset to omit.
#   - RUN_PHASE_AUTO_BRANCH=0            — fail instead of auto-creating
#                                          a gemini/* branch when needed.
#   - RUN_PHASE_ALLOW_DIRTY=1            — allow a dirty worktree before
#                                          the run starts. NOT recommended.
#   - RUN_PHASE_ALLOWLIST_REGEX="..."    — extra ERE restricting which
#                                          changed paths may be staged.
#   - RUN_PHASE_FORCE_UNSAFE=1           — override sensitive-path
#                                          refusal. NOT recommended.
#
# IMPORTANT: Gemini CLI flag names and command shape evolve quickly. The
# defaults below use the most stable headless pattern at time of writing
# (`gemini -p "<prompt>"`). Verify with `gemini --help` before relying on
# this in production.
#
# Gemini's session-resume model is less first-class than Codex's
# `exec resume --last`. This script issues TWO independent `gemini -p`
# invocations per task (work, then handoff). The handoff prompt is
# self-contained — it tells the AI to re-read CHAT_END_PROMPT.md and the
# relevant planning files rather than relying on prior-turn conversation
# state. If your Gemini version supports session checkpointing and you
# want to thread the work + handoff through one session, that's a
# version-specific tweak; the env var `RUN_PHASE_GEMINI_YOLO_FLAG` is the
# extensibility hook for any additional flags you want pinned.
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

TOOL_NAME="Gemini"
TOOL_LOG_PREFIX="run_gemini"
TOOL_SCRIPT="run-phase-gemini.sh"

rpl_require_tool gemini \
  "npm install -g @google/gemini-cli" \
  "https://github.com/google-gemini/gemini-cli"

TASKS=${1:?Usage: $0 <num_tasks>   e.g.  ./run-phase-gemini.sh 8}

rpl_preflight

LOG_DIR=$(rpl_init_log_dir)
START_PROMPT=$(rpl_start_prompt)
END_PROMPT=$(rpl_end_prompt)

# --- Tool-specific CLI flags. ---
#
# Headless automation. Gemini CLI flag names evolve quickly — verify your
# installed version with `gemini --help` before relying on this. We keep
# defaults minimal and expose env vars for the volatile bits.
GEMINI_FLAGS=()

# Optional auto-approve / "yolo" flag. The exact name varies by Gemini
# version (e.g. `--yolo`, `--no-prompt`, `--auto-approve`). Verify with
# `gemini --help` and set this to whatever your version accepts:
#   RUN_PHASE_GEMINI_YOLO_FLAG="--yolo"
# Leave unset if your version doesn't have one.
if [ -n "${RUN_PHASE_GEMINI_YOLO_FLAG:-}" ]; then
  # Split on whitespace so users can pass either "--flag" or "--flag value".
  read -r -a _yolo <<< "$RUN_PHASE_GEMINI_YOLO_FLAG"
  GEMINI_FLAGS+=("${_yolo[@]}")
fi

# Optional: pin model, e.g. RUN_PHASE_GEMINI_MODEL="gemini-2.5-pro"
if [ -n "${RUN_PHASE_GEMINI_MODEL:-}" ]; then
  GEMINI_FLAGS+=(--model "$RUN_PHASE_GEMINI_MODEL")
fi

echo "Starting $TOOL_NAME phase run: $TASKS tasks. Logs -> $LOG_DIR"

for i in $(seq 1 "$TASKS"); do
  printf '\n========== Task %d of %d ==========\n' "$i" "$TASKS"

  log "Step 1/3: working on next task (gemini -p)..."
  gemini "${GEMINI_FLAGS[@]}" -p "$START_PROMPT" \
    2>&1 | tee "$LOG_DIR/task_${i}_work.log"

  log "Step 2/3: writing handoff (gemini -p)..."
  gemini "${GEMINI_FLAGS[@]}" -p "$END_PROMPT" \
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
