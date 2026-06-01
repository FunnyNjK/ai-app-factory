#!/usr/bin/env bash
# scripts/orchestrator/codex-slice-verify.sh — one VERIFICATION slice via Codex.
# Used when the architect assigns a slice Owner: codex (a verification slice
# with no separate implementer). Codex does the verification work itself; this
# is NOT a review of another agent's code (that is codex-slice-review.sh).
#
# Usage: codex-slice-verify.sh <slice-id>   (e.g. codex-slice-verify.sh 5.2)
#
# See docs/adr/0009-autonomous-orchestrator.md for the design.

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

SLICE_ID="${1:?Usage: codex-slice-verify.sh <slice-id>   e.g.  codex-slice-verify.sh 5.2}"

# The Tester role's tool and display name come from .factory-roles.json
# (ADR-0013); defaults to Codex. factory_tool_invoke honors the same
# RUN_PHASE_* overrides the old inline invocation did.
ROLE_KEY="tester"
TOOL=$(factory_role_tool "$ROLE_KEY")
ROLE_NAME=$(factory_role_name "$ROLE_KEY")
TOOL_NAME="$(factory_tool_label "$TOOL")"
TOOL_LOG_PREFIX="codex_verify"
TOOL_SCRIPT="codex-slice-verify.sh"

factory_tool_require "$TOOL"

rpl_preflight
LOG_DIR=$(rpl_init_log_dir)

WALL_TIME=${FACTORY_WALL_TIME_SEC:-1800}

PROMPT=$(cat <<PROMPT_EOF
You are ${ROLE_NAME}, the Quality Engineer. The architect assigned slice ${SLICE_ID} to you (Owner: codex) as a verification slice — there is no separate implementer; you do the verification work yourself. This is NOT a review of code written by another agent.

Steps:

1. Read AGENTS.md, ARCHITECTURE.md, CODEX_HANDOFF.md if present, TASKS.md, and TEST_PLAN.md if it exists.
2. Find slice ${SLICE_ID} in TASKS.md. Set its Status to in-progress. Leave the Owner field exactly as the architect set it (codex) — do not change it; the orchestrator owns routing.
3. Read the acceptance criteria for the slice from ARCHITECTURE.md Work Breakdown and the handoff.
4. Do the verification the slice specifies: run the commands, scripts, or checks needed to prove the acceptance criteria, and add a small verification script or report if the slice calls for one. Inspect source files only — do not grep, cat, or read files inside node_modules/, .factory-logs/, dist/, or build/.
5. Decide:

   (A) VERIFIED — every acceptance criterion is demonstrably met:
       - Set slice ${SLICE_ID} Status to approved in TASKS.md.
       - End with:
         Work completed: verified slice ${SLICE_ID}
         FACTORY_STATUS={"role":"codex","action":"slice-verify","slice":"${SLICE_ID}","status":"verification-complete","details":"<one-line evidence summary>"}

   (B) BLOCKED — you cannot verify (missing secret, environment limit, or a real failure you cannot resolve; remember code changes are a developer task, not yours):
       - Set slice ${SLICE_ID} Status to human-needed in TASKS.md.
       - Append a new entry to ESCALATIONS.md with reason, context, what you tried, and recommended action.
       - End with:
         Work completed: escalated slice ${SLICE_ID}
         FACTORY_STATUS={"role":"codex","action":"slice-verify","slice":"${SLICE_ID}","status":"escalated","details":"<short reason>"}

6. Do NOT commit changes — the orchestrator commits.

Do not work on slices other than ${SLICE_ID}. Do not edit the phase review entry — the orchestrator manages it. Before the final two lines of your response, include a short Self-critique section — assumptions you made, anything you skipped or deferred, and what the next session should double-check. Be blunt; write "none" for any item that is empty.
PROMPT_EOF
)

log "Invoking $TOOL to verify slice $SLICE_ID (role '$ROLE_NAME', wall-time cap ${WALL_TIME}s)..."
set +e
factory_tool_invoke "$TOOL" "$PROMPT" "$LOG_DIR/work.log" "$WALL_TIME"
codex_rc=$?
set -e

if [ "$codex_rc" -eq 124 ]; then
  err "$TOOL timed out after ${WALL_TIME}s"
  factory_log_escalation ESCALATIONS.md "codex" "slice $SLICE_ID" "iteration-cap-hit" \
    "Codex CLI exceeded the per-session wall-time cap during slice verification." \
    "Single invocation hit timeout at ${WALL_TIME}s. Log: $LOG_DIR/work.log" \
    "Review the slice scope or increase FACTORY_WALL_TIME_SEC for this project." \
    >>"$LOG_DIR/escalation.log"
  echo 'FACTORY_STATUS={"role":"codex","action":"slice-verify","slice":"'"$SLICE_ID"'","status":"escalated","details":"wall-time-exceeded"}'
  exit 2
fi
if [ "$codex_rc" -ne 0 ]; then
  err "$TOOL exited with code $codex_rc"
  echo 'FACTORY_STATUS={"role":"codex","action":"slice-verify","slice":"'"$SLICE_ID"'","status":"error","details":"cli-failed-rc-'"$codex_rc"'"}'
  exit 1
fi

STATUS_LINE=$(factory_extract_status_line "$LOG_DIR/work.log")
if [ -z "$STATUS_LINE" ]; then
  err "$TOOL did not emit FACTORY_STATUS line. Check log: $LOG_DIR/work.log"
  exit 1
fi
log "Adapter status: $STATUS_LINE"

STATUS_FIELD=$(printf '%s' "$STATUS_LINE" | python3 -c 'import sys, json; print(json.loads(sys.stdin.read()).get("status",""))')

# Drop node_modules/ noise from the saved log now that the status line is parsed.
factory_strip_log_noise "$LOG_DIR/work.log"

# A verified slice is now approved: resolve its escalations and, if it was the
# last slice in the phase, flip the phase review to awaiting-review (same commit).
if [ "$STATUS_FIELD" = "verification-complete" ]; then
  PHASE_NUM="${SLICE_ID%%.*}"
  factory_resolve_escalations_for_slice "." "$SLICE_ID"
  if factory_is_last_slice_in_phase TASKS.md "$SLICE_ID"; then
    log "Slice $SLICE_ID is the last approved slice in Phase $PHASE_NUM; setting Phase $PHASE_NUM review to awaiting-review."
    factory_set_phase_review_awaiting TASKS.md "$PHASE_NUM"
  fi
fi

SUBJECT=$(rpl_extract_subject "$LOG_DIR/work.log" "Codex verify slice ${SLICE_ID}")
set +e
rpl_commit_and_push "$SUBJECT" "$LOG_DIR/work.log"
commit_rc=$?
set -e
case "$commit_rc" in
  0) log "Committed and pushed." ;;
  2) log "No changes to commit." ;;
  *) err "Commit/push failed (rc=$commit_rc)"; exit 1 ;;
esac

echo "$STATUS_LINE"

case "$STATUS_FIELD" in
  verification-complete) exit 0 ;;
  escalated) exit 2 ;;
  error) exit 1 ;;
  *) log "Unknown status field '$STATUS_FIELD'; treating as continue."; exit 0 ;;
esac
