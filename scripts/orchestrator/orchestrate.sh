#!/usr/bin/env bash
# scripts/orchestrator/orchestrate.sh — top-level autonomous loop for the
# AI App Factory gating model. Reads TASKS.md, picks the next actionable
# item, dispatches to the matching adapter, loops until the project is
# done or human intervention is needed.
#
# See docs/adr/0009-autonomous-orchestrator.md for the design.
#
# Usage:
#   orchestrate.sh                          # operate on current directory
#   orchestrate.sh --project /abs/path      # operate on a different project
#
# Env vars:
#   FACTORY_MAX_OUTER_ITER=200    — hard ceiling on outer loop iterations
#   FACTORY_WALL_TIME_SEC=1800    — per-adapter wall time (passed via env)
#   FACTORY_TOKEN_CAP=100000      — per-session token cap (passed via env)
#   RUN_PHASE_NO_PUSH=1           — commit but skip push (set on adapters)
#   RUN_PHASE_AUTO_BRANCH=1       — auto-create role-specific branch
#   RUN_PHASE_ALLOW_DIRTY=0       — refuse to start on a dirty tree
#
# Exit codes:
#   0  — all phases approved, project done
#   2  — human intervention needed (escalation written, see ESCALATIONS.md)
#   1  — unrecoverable error (adapter failure, missing files, etc.)

set -euo pipefail

PROJECT_PATH=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)
      PROJECT_PATH="$2"
      shift 2
      ;;
    -h|--help)
      sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      printf 'error: unknown argument: %s\n' "$1" >&2
      exit 1
      ;;
  esac
done

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

if [ -z "$PROJECT_PATH" ]; then
  PROJECT_PATH=$(pwd)
fi

if [ ! -d "$PROJECT_PATH" ]; then
  err "error: project path does not exist: $PROJECT_PATH"
  exit 1
fi
cd "$PROJECT_PATH"

[ -f TASKS.md ] || { err "error: no TASKS.md in $PROJECT_PATH (run /design first)"; exit 1; }
[ -f ESCALATIONS.md ] || { err "error: no ESCALATIONS.md in $PROJECT_PATH"; exit 1; }

# Set up orchestrator-level log dir (separate from adapter logs).
TOOL_NAME="Orchestrator"
TOOL_LOG_PREFIX="orchestrate"
TOOL_SCRIPT="orchestrate.sh"
ORCH_LOG_DIR=$(rpl_init_log_dir)
log "Orchestrator log dir: $ORCH_LOG_DIR"
log "Project: $PROJECT_PATH"

MAX_OUTER_ITER=${FACTORY_MAX_OUTER_ITER:-200}
OUTER_ITER=0

while true; do
  OUTER_ITER=$((OUTER_ITER + 1))
  if [ "$OUTER_ITER" -gt "$MAX_OUTER_ITER" ]; then
    err "halt: exceeded max outer iterations ($MAX_OUTER_ITER). Inspect TASKS.md and ESCALATIONS.md for state."
    exit 1
  fi

  ACTION=$(factory_next_action TASKS.md)
  read -r ROLE KIND ID <<<"$ACTION"

  printf '\n========== Step %d: role=%s kind=%s id=%s ==========\n' \
    "$OUTER_ITER" "$ROLE" "$KIND" "$ID"

  if [ "$ROLE" = "none" ]; then
    log "All slices and phase reviews are approved. Orchestrator done."
    exit 0
  fi

  # Check iteration cap BEFORE invoking the adapter.
  set +e
  factory_check_iteration_cap TASKS.md "$KIND" "$ID"
  cap_rc=$?
  set -e
  if [ "$cap_rc" -eq 2 ]; then
    err "halt: iteration cap reached for $KIND $ID. Writing escalation and stopping."
    factory_log_escalation \
      ESCALATIONS.md \
      "orchestrator" \
      "$KIND $ID" \
      "iteration-cap-hit" \
      "Iteration counter reached the cap defined in TASKS.md before this attempt." \
      "Previous attempts logged in .factory-logs/. See per-adapter logs for details." \
      "Review the slice/phase, decide whether to extend the cap, rescope the work, or pivot." \
      >>"$ORCH_LOG_DIR/escalations.log"
    exit 2
  fi

  # Dispatch.
  case "$ROLE-$KIND" in
    cursor-slice)
      ADAPTER="$SCRIPT_DIR/cursor-slice.sh"
      ;;
    codex-slice)
      ADAPTER="$SCRIPT_DIR/codex-slice-review.sh"
      ;;
    claude-phase-review)
      ADAPTER="$SCRIPT_DIR/claude-phase-review.sh"
      ;;
    *)
      err "halt: unknown role/kind combination: $ROLE / $KIND"
      exit 1
      ;;
  esac

  log "Dispatch: $ADAPTER $ID"
  set +e
  "$ADAPTER" "$ID" 2>&1 | tee "$ORCH_LOG_DIR/step_${OUTER_ITER}_${ROLE}_${ID}.log"
  rc=${PIPESTATUS[0]}
  set -e

  case "$rc" in
    0)
      log "Step $OUTER_ITER: adapter completed cleanly."
      ;;
    2)
      err "halt: adapter signaled escalation. See ESCALATIONS.md and .factory-logs/."
      exit 2
      ;;
    *)
      err "halt: adapter exited with code $rc."
      exit 1
      ;;
  esac
done
