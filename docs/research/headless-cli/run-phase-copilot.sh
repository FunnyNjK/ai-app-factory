#!/usr/bin/env bash
# run-phase-copilot.sh — run N consecutive tasks autonomously via GitHub Copilot CLI (`copilot`).
# Each task: work → handoff → commit → push.
#
# This is the GitHub Copilot adapter. It is one of FIVE tool-specific
# harnesses — see also run-phase.sh (Claude), run-phase-codex.sh,
# run-phase-cursor.sh, run-phase-gemini.sh. Shared safety/session mechanics live in
# scripts/run-phase-lib.sh; this script keeps the Copilot-specific CLI
# invocation because Copilot CLI uses `--resume` / `--allow-all-tools`
# rather than the other CLIs' flag names.
#
# Usage:
#   ./run-phase-copilot.sh <num_tasks>                    # commit + push (default)
#   RUN_PHASE_NO_PUSH=1 ./run-phase-copilot.sh <num_tasks> # commit, skip push
#
# Prerequisites:
#   - GitHub Copilot CLI installed: npm install -g @github/copilot
#   - Active GitHub Copilot subscription on your GitHub account.
#   - Authenticate once: run `copilot` interactively to complete OAuth, or set
#     GH_TOKEN / GITHUB_TOKEN with Copilot scope for headless / CI.
#   - Docs: https://docs.github.com/en/copilot/concepts/agents/about-copilot-cli
#
# Optional env vars:
#   - RUN_PHASE_NO_PUSH=1            — commit but skip push.
#   - RUN_PHASE_COPILOT_MODEL="..."  — pin a specific model.
#   - RUN_PHASE_AUTO_BRANCH=0        — fail instead of auto-creating
#                                      a copilot/* branch when needed.
#   - RUN_PHASE_ALLOW_DIRTY=1        — allow a dirty worktree before
#                                      the run starts. NOT recommended.
#   - RUN_PHASE_ALLOWLIST_REGEX="..." — extra ERE restricting which
#                                       changed paths may be staged.
#   - RUN_PHASE_FORCE_UNSAFE=1       — override sensitive-path
#                                      refusal. NOT recommended.
#
# IMPORTANT: GitHub Copilot CLI is newer; flag names evolve. The flags below
# reflect a common configuration (allow all tools, suppress interactive
# approvals). Verify the current flag set against the Copilot CLI docs
# before relying on this script in production.
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

TOOL_NAME="Copilot"
TOOL_LOG_PREFIX="run_copilot"
TOOL_SCRIPT="run-phase-copilot.sh"

rpl_require_tool copilot \
  "npm install -g @github/copilot" \
  "https://docs.github.com/en/copilot/concepts/agents/about-copilot-cli"

TASKS=${1:?Usage: $0 <num_tasks>   e.g.  ./run-phase-copilot.sh 8}

rpl_preflight

LOG_DIR=$(rpl_init_log_dir)
START_PROMPT=$(rpl_start_prompt)
END_PROMPT=$(rpl_end_prompt)

# --- Tool-specific CLI flags. ---
# Headless automation: allow all tools, suppress interactive approvals.
# Verify these flag names against the current Copilot CLI docs.
COPILOT_FLAGS=(
  --allow-all-tools
)

# Optional: pin model, e.g. RUN_PHASE_COPILOT_MODEL="claude-sonnet-4-6"
if [ -n "${RUN_PHASE_COPILOT_MODEL:-}" ]; then
  COPILOT_FLAGS+=(--model "$RUN_PHASE_COPILOT_MODEL")
fi

echo "Starting $TOOL_NAME phase run: $TASKS tasks. Logs -> $LOG_DIR"

for i in $(seq 1 "$TASKS"); do
  printf '\n========== Task %d of %d ==========\n' "$i" "$TASKS"

  log "Step 1/3: working on next task (copilot -p)..."
  copilot -p "$START_PROMPT" "${COPILOT_FLAGS[@]}" \
    2>&1 | tee "$LOG_DIR/task_${i}_work.log"

  log "Step 2/3: writing handoff (copilot --resume -p)..."
  copilot --resume -p "$END_PROMPT" "${COPILOT_FLAGS[@]}" \
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
