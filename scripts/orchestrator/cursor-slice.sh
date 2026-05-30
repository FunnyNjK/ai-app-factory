#!/usr/bin/env bash
# scripts/orchestrator/cursor-slice.sh — one slice implementation via Cursor CLI.
# Called by orchestrate.sh; can also be invoked directly for debugging.
#
# Usage: cursor-slice.sh <slice-id>   (e.g. cursor-slice.sh 1.2)
#
# Reads from CWD (must be a project root with TASKS.md, ESCALATIONS.md,
# ARCHITECTURE.md, CURSOR_HANDOFF.md, .cursor/rules/developer.mdc).
#
# See docs/adr/0009-autonomous-orchestrator.md for the design.

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

TOOL_NAME="Cursor"
TOOL_LOG_PREFIX="cursor_slice"
TOOL_SCRIPT="cursor-slice.sh"

SLICE_ID="${1:?Usage: cursor-slice.sh <slice-id>   e.g.  cursor-slice.sh 1.2}"

rpl_require_tool agent \
  "curl https://cursor.com/install -fsS | bash" \
  "https://cursor.com/docs/cli"

rpl_preflight
LOG_DIR=$(rpl_init_log_dir)

WALL_TIME=${FACTORY_WALL_TIME_SEC:-1800}

PROMPT=$(cat <<PROMPT_EOF
You are Cursor, the Developer for this AI App Factory project. Your task this session: implement slice ${SLICE_ID} from TASKS.md.

Steps:

1. Read CLAUDE.md, .cursor/rules/developer.mdc, ARCHITECTURE.md, CURSOR_HANDOFF.md, TASKS.md, and every docs/adr/*.md.
2. Find slice ${SLICE_ID} in TASKS.md. Note its acceptance criteria (in ARCHITECTURE.md Work Breakdown and CURSOR_HANDOFF.md) and any Sub-tasks listed from prior Codex review.
3. Update TASKS.md: set slice ${SLICE_ID} Status to in-progress. Leave the Owner field exactly as the architect set it — Owner is the slice's work type (cursor = coding), not a runtime marker, and the orchestrator owns routing. Do not change it.
4. If sub-tasks exist for this slice: fix only those sub-tasks (focused changes, no unrelated refactors). Otherwise: implement the slice end-to-end per CURSOR_HANDOFF.md (UI, API, integration, tests, docs as scoped).
5. Run local tests and confirm they pass. If tests do not exist yet for what you built, add them per standards/testing-standards.md.
6. Update TASKS.md: set slice ${SLICE_ID} Status to awaiting-review. Increment the slice's Iterations counter ONLY if you were fixing sub-tasks; leave it at its current value if this was the first implementation.
7. Do NOT commit changes — the orchestrator commits.
8. At the very end of your response, write these two lines exactly:
   Work completed: <one-line summary of what you implemented>
   FACTORY_STATUS={"role":"cursor","action":"slice","slice":"${SLICE_ID}","status":"implementation-complete","details":"<short summary>"}

If you cannot proceed (missing secret, ambiguous requirement, architecture conflict, or any real blocker you cannot resolve):
- Update TASKS.md: set Status to blocked or human-needed.
- Append a new entry to ESCALATIONS.md with reason, context, what you tried, and recommended action.
- End with:
   Work completed: escalated — <one-line reason>
   FACTORY_STATUS={"role":"cursor","action":"slice","slice":"${SLICE_ID}","status":"escalated","details":"<short reason>"}

Do not modify slices other than ${SLICE_ID}. Do not start a different slice. Do not commit. Inspect source files only — do not grep, cat, or read files inside node_modules/, .factory-logs/, dist/, or build/.
PROMPT_EOF
)

CURSOR_FLAGS=(--trust --force --sandbox disabled --output-format text)
[ -n "${RUN_PHASE_CURSOR_MODEL:-}" ] && CURSOR_FLAGS+=(--model "$RUN_PHASE_CURSOR_MODEL")

log "Invoking Cursor for slice $SLICE_ID (wall-time cap ${WALL_TIME}s)..."
set +e
timeout "$WALL_TIME" agent -p "${CURSOR_FLAGS[@]}" -- "$PROMPT" 2>&1 | tee "$LOG_DIR/work.log"
agent_rc=${PIPESTATUS[0]}
set -e

if [ "$agent_rc" -eq 124 ]; then
  err "Cursor CLI timed out after ${WALL_TIME}s"
  factory_log_escalation ESCALATIONS.md "cursor" "slice $SLICE_ID" "iteration-cap-hit" \
    "Cursor CLI exceeded the per-session wall-time cap." \
    "Single invocation hit timeout at ${WALL_TIME}s. Log: $LOG_DIR/work.log" \
    "Review the slice scope or increase FACTORY_WALL_TIME_SEC for this project." \
    >>"$LOG_DIR/escalation.log"
  echo 'FACTORY_STATUS={"role":"cursor","action":"slice","slice":"'"$SLICE_ID"'","status":"escalated","details":"wall-time-exceeded"}'
  exit 2
fi
if [ "$agent_rc" -ne 0 ]; then
  err "Cursor CLI exited with code $agent_rc"
  echo 'FACTORY_STATUS={"role":"cursor","action":"slice","slice":"'"$SLICE_ID"'","status":"error","details":"cli-failed-rc-'"$agent_rc"'"}'
  exit 1
fi

STATUS_LINE=$(factory_extract_status_line "$LOG_DIR/work.log")
if [ -z "$STATUS_LINE" ]; then
  err "Cursor did not emit FACTORY_STATUS line. Check log: $LOG_DIR/work.log"
  exit 1
fi
log "Adapter status: $STATUS_LINE"

STATUS_FIELD=$(printf '%s' "$STATUS_LINE" | python3 -c 'import sys, json; print(json.loads(sys.stdin.read()).get("status",""))')

# Drop node_modules/ noise from the saved log now that the status line is parsed.
factory_strip_log_noise "$LOG_DIR/work.log"

SUBJECT=$(rpl_extract_subject "$LOG_DIR/work.log" "Cursor slice ${SLICE_ID}")
set +e
rpl_commit_and_push "$SUBJECT" "$LOG_DIR/work.log"
commit_rc=$?
set -e
case "$commit_rc" in
  0) log "Committed and pushed." ;;
  2) log "No changes to commit (Cursor may have decided no code change was needed)." ;;
  *) err "Commit/push failed (rc=$commit_rc)"; exit 1 ;;
esac

echo "$STATUS_LINE"

case "$STATUS_FIELD" in
  implementation-complete) exit 0 ;;
  escalated) exit 2 ;;
  error) exit 1 ;;
  *) log "Unknown status field '$STATUS_FIELD'; treating as continue."; exit 0 ;;
esac
