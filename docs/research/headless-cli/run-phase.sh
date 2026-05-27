#!/usr/bin/env bash
# run-phase.sh — run N consecutive tasks autonomously via Claude Code (`claude`).
# Each task: work → handoff → commit → push.
#
# This is the Anthropic Claude Code adapter. It is one of FIVE
# tool-specific harnesses — see also run-phase-codex.sh,
# run-phase-cursor.sh, run-phase-copilot.sh, run-phase-gemini.sh.
# The five scripts share safety/session mechanics via
# scripts/run-phase-lib.sh, but each keeps its own CLI invocation
# because the five CLIs differ in sub-commands, flag names, approval
# flow, and resume semantics.
#
# Usage:
#   ./run-phase.sh <num_tasks>                    # commit + push (default)
#   RUN_PHASE_NO_PUSH=1 ./run-phase.sh <num_tasks> # commit, skip push
#
# Prerequisites:
#   - Claude Code CLI installed: npm install -g @anthropic-ai/claude-code
#   - Authenticate once: `claude` (interactive flow) or set ANTHROPIC_API_KEY
#     for headless / CI use.
#   - Docs: https://docs.anthropic.com/en/docs/claude-code
#
# Optional env vars:
#   - RUN_PHASE_NO_PUSH=1                — commit but skip push.
#   - RUN_PHASE_CLAUDE_MODEL="..."       — pin a specific model
#                                          (e.g. "claude-opus-4-7").
#   - RUN_PHASE_CLAUDE_MAX_TURNS="100"   — cap turns per task. Some Claude
#                                          Code versions support this
#                                          flag; others don't. Verify
#                                          with `claude --help` before
#                                          setting. Leave unset to omit.
#   - RUN_PHASE_AUTO_BRANCH=0            — fail instead of auto-creating
#                                          a claude/* branch when needed.
#   - RUN_PHASE_ALLOW_DIRTY=1            — allow a dirty worktree before
#                                          the run starts. NOT recommended.
#   - RUN_PHASE_ALLOWLIST_REGEX="..."    — extra ERE restricting which
#                                          changed paths may be staged
#                                          (in addition to the built-in
#                                          sensitive-path refusal).
#   - RUN_PHASE_FORCE_UNSAFE=1           — override sensitive-path
#                                          refusal. NOT recommended.
#
# Staging safety: the shared library stages only files this session
# actually changed, refuses to stage files that look like secrets,
# credentials, keys, local DBs, or backups, and prints a status summary
# before each commit. See scripts/run-phase-lib.sh for the full rules.
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

# Source the shared safety/session library. Resolve relative to this
# script so it works regardless of the caller's CWD as long as the
# script and scripts/ dir ship together.
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/run-phase-lib.sh
. "$SCRIPT_DIR/scripts/run-phase-lib.sh"

TOOL_NAME="Claude"
TOOL_LOG_PREFIX="run_claude"
TOOL_SCRIPT="run-phase.sh"

rpl_require_tool claude \
  "npm install -g @anthropic-ai/claude-code" \
  "https://docs.anthropic.com/en/docs/claude-code"

TASKS=${1:?Usage: $0 <num_tasks>   e.g.  ./run-phase.sh 8}

rpl_preflight

LOG_DIR=$(rpl_init_log_dir)
START_PROMPT=$(rpl_start_prompt)
END_PROMPT=$(rpl_end_prompt)

# --- Tool-specific CLI flags. Keep distinct from other adapters. ---
CLAUDE_FLAGS=(
  --dangerously-skip-permissions
)

# Optional: cap turns per task. `--max-turns` is supported by some Claude
# Code versions but not all; verify with `claude --help` before setting
# RUN_PHASE_CLAUDE_MAX_TURNS, otherwise leave it unset.
if [ -n "${RUN_PHASE_CLAUDE_MAX_TURNS:-}" ]; then
  CLAUDE_FLAGS+=(--max-turns "$RUN_PHASE_CLAUDE_MAX_TURNS")
fi

# Optional: pin model, e.g. RUN_PHASE_CLAUDE_MODEL="claude-opus-4-7"
if [ -n "${RUN_PHASE_CLAUDE_MODEL:-}" ]; then
  CLAUDE_FLAGS+=(--model "$RUN_PHASE_CLAUDE_MODEL")
fi

echo "Starting $TOOL_NAME phase run: $TASKS tasks. Logs -> $LOG_DIR"

for i in $(seq 1 "$TASKS"); do
  printf '\n========== Task %d of %d ==========\n' "$i" "$TASKS"

  log "Step 1/3: working on next task (claude -p)..."
  claude -p "$START_PROMPT" "${CLAUDE_FLAGS[@]}" \
    2>&1 | tee "$LOG_DIR/task_${i}_work.log"

  log "Step 2/3: writing handoff (claude --continue -p)..."
  claude --continue -p "$END_PROMPT" "${CLAUDE_FLAGS[@]}" \
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
