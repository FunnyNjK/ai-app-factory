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
#   FACTORY_TOKEN_CAP=100000      — reserved; NOT enforced (no universal CLI
#                                   token flag). FACTORY_WALL_TIME_SEC is the
#                                   active per-session bound.
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
# Re-exec under bash >= 4 before parsing the prompt heredocs below (ADR-0015).
# shellcheck source=require-bash4.sh
. "$SCRIPT_DIR/require-bash4.sh"
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

# Load persisted per-project settings (push / Codex-sandbox choices) so a direct
# orchestrate.sh run honors them without re-exporting env vars each session.
# Explicit environment still wins; adapters inherit whatever we export here.
factory_load_settings

# Set up orchestrator-level log dir (separate from adapter logs).
TOOL_NAME="Orchestrator"
TOOL_LOG_PREFIX="orchestrate"
TOOL_SCRIPT="orchestrate.sh"
ORCH_LOG_DIR=$(rpl_init_log_dir)
log "Orchestrator log dir: $ORCH_LOG_DIR"
log "Project: $PROJECT_PATH"

# Single-flight lock: refuse a second orchestrator run on the same project,
# which would race the working tree and the main fast-forward. mkdir is atomic
# and portable (Linux, macOS, Git Bash); the lock is released on any exit.
LOCK_DIR=".factory-logs/orchestrate.lock"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  err "halt: another orchestrator run holds $PROJECT_PATH/$LOCK_DIR (or it is stale)."
  err "If no run is active, remove it:  rmdir '$LOCK_DIR'"
  exit 1
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT
trap 'exit 130' INT TERM
log "Acquired single-flight lock: $LOCK_DIR"

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
    # No actionable slice or phase review remains. Resolve the Gate D end-game:
    # depending on how much of SIGNOFF.md is filled, the run is done, waiting on
    # the human product-owner sign-off, or only partially signed.
    if factory_all_phases_approved TASKS.md && [ -f SIGNOFF.md ]; then
      SIGNOFF_STATE=$(factory_signoff_state SIGNOFF.md)
      case "$SIGNOFF_STATE" in
        complete)
          log "Gate D: all six sign-offs present in SIGNOFF.md. Project is release-ready."
          if ! factory_advance_main "$ORCH_LOG_DIR"; then
            err "halt: could not fast-forward main after the final sign-off (see ESCALATIONS.md)."
            exit 2
          fi
          exit 0
          ;;
        agents-signed)
          log "Gate D: five agent sign-offs complete; product-owner sign-off required."
          log "Complete the product-owner section in SIGNOFF.md (see ESCALATIONS.md), then re-run."
          exit 2
          ;;
        partial)
          err "Gate D: SIGNOFF.md is only partially signed — a sign-off sub-session did not complete."
          err "Inspect SIGNOFF.md and .factory-logs/, re-run gate-d-signoff.sh, or finish the sign-offs by hand."
          exit 2
          ;;
        *)
          log "All slices and phase reviews are approved. Orchestrator done."
          exit 0
          ;;
      esac
    fi
    log "All slices and phase reviews are approved. Orchestrator done."
    exit 0
  fi

  # Check iteration cap BEFORE invoking the adapter. Orchestrator-level actions
  # (e.g. gate-d-signoff) carry no iteration counter, so skip the check for them.
  if [ "$ROLE" != "orchestrator" ]; then
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
  fi

  # Dispatch — the (role, kind) -> adapter map lives in lib.sh
  # (factory_adapter_for), shared with scripts/factory.sh so the two cannot
  # drift (ADR-0012 follow-up).
  ADAPTER=$(factory_adapter_for "$ROLE" "$KIND")
  if [ -z "$ADAPTER" ]; then
    err "halt: unknown role/kind combination: $ROLE / $KIND"
    exit 1
  fi
  ADAPTER="$SCRIPT_DIR/$ADAPTER"

  log "Dispatch: $ADAPTER $ID"
  set +e
  "$ADAPTER" "$ID" 2>&1 | tee "$ORCH_LOG_DIR/step_${OUTER_ITER}_${ROLE}_${ID}.log"
  rc=${PIPESTATUS[0]}
  set -e

  case "$rc" in
    0)
      log "Step $OUTER_ITER: adapter completed cleanly."
      # A phase advances main only when ALL of its gates are approved — the
      # architect review, plus the security and code-review gates (ADR-0013).
      # factory_phase_fully_approved treats absent gates (older projects) as
      # satisfied, so a review-only phase still advances after its review.
      case "$KIND" in
        phase-review|phase-security|phase-code-review)
          if [ "$(factory_item_status TASKS.md "$KIND" "$ID")" = "approved" ] \
             && factory_phase_fully_approved TASKS.md "$ID"; then
            if ! factory_advance_main "$ORCH_LOG_DIR"; then
              err "halt: could not fast-forward main after Phase $ID completion (see ESCALATIONS.md)."
              exit 2
            fi
          fi
          ;;
      esac
      ;;
    2)
      # gate-d-signoff ends in human-needed, but its SIGNOFF.md and escalation
      # edits should still land on main before we halt.
      if [ "$ROLE" = "orchestrator" ] && [ "$KIND" = "gate-d-signoff" ]; then
        factory_advance_main "$ORCH_LOG_DIR" || err "warning: could not fast-forward main after gate-d-signoff (see ESCALATIONS.md)."
      fi
      err "halt: adapter signaled escalation. See ESCALATIONS.md and .factory-logs/."
      exit 2
      ;;
    *)
      err "halt: adapter exited with code $rc."
      exit 1
      ;;
  esac
done
