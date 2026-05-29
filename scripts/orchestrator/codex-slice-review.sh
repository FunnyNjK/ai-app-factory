#!/usr/bin/env bash
# scripts/orchestrator/codex-slice-review.sh — one slice review via Codex CLI.
# Called by orchestrate.sh; can also be invoked directly for debugging.
#
# Usage: codex-slice-review.sh <slice-id>   (e.g. codex-slice-review.sh 1.2)
#
# Reads from CWD (must be a project root with TASKS.md, ESCALATIONS.md,
# ARCHITECTURE.md, AGENTS.md, TEST_PLAN.md if present).
#
# See docs/adr/0009-autonomous-orchestrator.md for the design.

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

TOOL_NAME="Codex"
TOOL_LOG_PREFIX="codex_review"
TOOL_SCRIPT="codex-slice-review.sh"

SLICE_ID="${1:?Usage: codex-slice-review.sh <slice-id>   e.g.  codex-slice-review.sh 1.2}"

rpl_require_tool codex \
  "npm install -g @openai/codex" \
  "https://github.com/openai/codex"

rpl_preflight
LOG_DIR=$(rpl_init_log_dir)

WALL_TIME=${FACTORY_WALL_TIME_SEC:-1800}

PROMPT=$(cat <<PROMPT_EOF
You are Codex, the Quality Engineer for this AI App Factory project. Your task this session: review slice ${SLICE_ID} from TASKS.md.

Steps:

1. Read AGENTS.md, ARCHITECTURE.md, CURSOR_HANDOFF.md, TASKS.md, and TEST_PLAN.md if it exists.
2. Find slice ${SLICE_ID} in TASKS.md. Confirm its Status is awaiting-review. If it is not, abort with status=error.
3. Read the slice's acceptance criteria from ARCHITECTURE.md Work Breakdown and CURSOR_HANDOFF.md.
4. Read the recent git diff for changes Cursor made to implement this slice (use \`git log --oneline -n 5\` and \`git diff HEAD~1\`).
5. Execute the slice's acceptance criteria. Run any tests Cursor added; confirm they pass. Spot-check the code for the per-project-type checklist in factory AGENTS.md (security smoke, accessibility baseline as applicable, integration points, error handling).
6. Decide:

   (A) APPROVED — every acceptance criterion passes, tests pass, no significant defect:
       - Update TASKS.md: set slice ${SLICE_ID} Status to approved.
       - End with:
         Work completed: approved slice ${SLICE_ID}
         FACTORY_STATUS={"role":"codex","action":"slice-review","slice":"${SLICE_ID}","status":"approved","details":"<one-line evidence summary>"}

   (B) SUB-TASKS NEEDED — one or more defects, missing tests, or contract gaps:
       - Update TASKS.md: set slice ${SLICE_ID} Status to in-progress, append numbered sub-tasks to the slice's Sub-tasks line (use ${SLICE_ID}.a, ${SLICE_ID}.b, ...). Each sub-task must be specific (file/function/line) and testable.
       - Do NOT increment Iterations — the orchestrator handles that on the next cursor-slice run.
       - End with:
         Work completed: filed N sub-tasks for slice ${SLICE_ID}
         FACTORY_STATUS={"role":"codex","action":"slice-review","slice":"${SLICE_ID}","status":"sub-tasks-filed","details":"<short list>","sub_tasks":["${SLICE_ID}.a ...","${SLICE_ID}.b ..."]}

   (C) ESCALATE — you cannot decide (architecture problem, ambiguous requirement, scope confusion):
       - Update TASKS.md: set Status to human-needed.
       - Append a new entry to ESCALATIONS.md with reason, context, what you tried, recommended action.
       - End with:
         Work completed: escalated slice ${SLICE_ID}
         FACTORY_STATUS={"role":"codex","action":"slice-review","slice":"${SLICE_ID}","status":"escalated","details":"<short reason>"}

7. Do NOT commit changes — the orchestrator commits.

Do not review slices other than ${SLICE_ID}. Do not modify code. Code-level changes are Cursor's responsibility. Do not edit the phase review entry — the orchestrator sets the phase review to awaiting-review automatically once every slice in the phase is approved.
PROMPT_EOF
)

CODEX_FLAGS=(--sandbox workspace-write)
[ -n "${RUN_PHASE_CODEX_MODEL:-}" ] && CODEX_FLAGS+=(--model "$RUN_PHASE_CODEX_MODEL")
if [ -n "${RUN_PHASE_CODEX_APPROVAL_FLAG:-}" ]; then
  read -r -a _approval <<<"$RUN_PHASE_CODEX_APPROVAL_FLAG"
  CODEX_FLAGS+=("${_approval[@]}")
fi

log "Invoking Codex for slice $SLICE_ID review (wall-time cap ${WALL_TIME}s)..."
set +e
timeout "$WALL_TIME" codex exec "${CODEX_FLAGS[@]}" "$PROMPT" 2>&1 | tee "$LOG_DIR/work.log"
codex_rc=${PIPESTATUS[0]}
set -e

if [ "$codex_rc" -eq 124 ]; then
  err "Codex CLI timed out after ${WALL_TIME}s"
  factory_log_escalation ESCALATIONS.md "codex" "slice $SLICE_ID" "iteration-cap-hit" \
    "Codex CLI exceeded the per-session wall-time cap during slice review." \
    "Single invocation hit timeout at ${WALL_TIME}s. Log: $LOG_DIR/work.log" \
    "Review the slice scope or increase FACTORY_WALL_TIME_SEC for this project." \
    >>"$LOG_DIR/escalation.log"
  echo 'FACTORY_STATUS={"role":"codex","action":"slice-review","slice":"'"$SLICE_ID"'","status":"escalated","details":"wall-time-exceeded"}'
  exit 2
fi
if [ "$codex_rc" -ne 0 ]; then
  err "Codex CLI exited with code $codex_rc"
  echo 'FACTORY_STATUS={"role":"codex","action":"slice-review","slice":"'"$SLICE_ID"'","status":"error","details":"cli-failed-rc-'"$codex_rc"'"}'
  exit 1
fi

STATUS_LINE=$(factory_extract_status_line "$LOG_DIR/work.log")
if [ -z "$STATUS_LINE" ]; then
  err "Codex did not emit FACTORY_STATUS line. Check log: $LOG_DIR/work.log"
  exit 1
fi
log "Adapter status: $STATUS_LINE"

STATUS_FIELD=$(printf '%s' "$STATUS_LINE" | python3 -c 'import sys, json; print(json.loads(sys.stdin.read()).get("status",""))')

# If sub-tasks were filed, increment the iteration counter against the cap from TASKS.md header.
if [ "$STATUS_FIELD" = "sub-tasks-filed" ]; then
  PER_TASK_CAP=$(python3 -c 'import re,sys
with open("TASKS.md") as f:
    for line in f:
        m=re.match(r"\|\s*Per-task iterations\s*\|\s*(\d+)\s*\|", line)
        if m: print(m.group(1)); sys.exit(0)
print(3)')
  set +e
  factory_increment_iterations TASKS.md slice "$SLICE_ID" "$PER_TASK_CAP"
  inc_rc=$?
  set -e
  if [ "$inc_rc" -eq 2 ]; then
    log "Iteration cap reached for slice $SLICE_ID after this sub-tasks-filed review."
    factory_log_escalation ESCALATIONS.md "codex" "slice $SLICE_ID" "iteration-cap-hit" \
      "Codex filed sub-tasks that pushed slice ${SLICE_ID} to the per-task iteration cap." \
      "See sub-task list in TASKS.md and Codex review log at $LOG_DIR/work.log." \
      "Review the recurring failure pattern. Rescope, add prerequisite work, or accept the slice with documented risk." \
      >>"$LOG_DIR/escalation.log"
    # Re-emit as escalated so the orchestrator halts.
    echo 'FACTORY_STATUS={"role":"codex","action":"slice-review","slice":"'"$SLICE_ID"'","status":"escalated","details":"iteration-cap-hit-after-sub-tasks"}'
    SUBJECT=$(rpl_extract_subject "$LOG_DIR/work.log" "Codex review slice ${SLICE_ID} (cap hit)")
    rpl_commit_and_push "$SUBJECT" "$LOG_DIR/work.log" || true
    exit 2
  fi
fi

# When this approval makes every slice in the phase approved, deterministically
# flip the phase review to awaiting-review so the orchestrator routes it to
# Claude. The adapter owns this transition (it is no longer left to the prompt),
# and the change rides in the same commit as Codex's slice approval below.
if [ "$STATUS_FIELD" = "approved" ]; then
  PHASE_NUM="${SLICE_ID%%.*}"
  # Resolve any escalations that were open against this slice now that it is approved.
  factory_resolve_escalations_for_slice "." "$SLICE_ID"
  if factory_is_last_slice_in_phase TASKS.md "$SLICE_ID"; then
    log "Slice $SLICE_ID is the last approved slice in Phase $PHASE_NUM; setting Phase $PHASE_NUM review to awaiting-review."
    factory_set_phase_review_awaiting TASKS.md "$PHASE_NUM"
  fi
fi

SUBJECT=$(rpl_extract_subject "$LOG_DIR/work.log" "Codex review slice ${SLICE_ID}")
set +e
rpl_commit_and_push "$SUBJECT" "$LOG_DIR/work.log"
commit_rc=$?
set -e
case "$commit_rc" in
  0) log "Committed and pushed." ;;
  2) log "No changes to commit (review-only with no TASKS.md edit?)." ;;
  *) err "Commit/push failed (rc=$commit_rc)"; exit 1 ;;
esac

echo "$STATUS_LINE"

case "$STATUS_FIELD" in
  approved) exit 0 ;;
  sub-tasks-filed) exit 0 ;;
  escalated) exit 2 ;;
  error) exit 1 ;;
  *) log "Unknown status field '$STATUS_FIELD'; treating as continue."; exit 0 ;;
esac
