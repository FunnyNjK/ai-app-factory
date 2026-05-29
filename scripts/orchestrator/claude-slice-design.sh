#!/usr/bin/env bash
# scripts/orchestrator/claude-slice-design.sh — one DESIGN slice via Claude.
# Used when the architecture assigns a slice Owner: claude (design/architecture
# work rather than implementation). Claude produces the design artifact and
# sets the slice to awaiting-review so it re-enters the normal Codex review
# gate — the per-slice gate is preserved.
#
# Usage: claude-slice-design.sh <slice-id>   (e.g. claude-slice-design.sh 2.1)
#
# See docs/adr/0009-autonomous-orchestrator.md for the design.

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

TOOL_NAME="Claude"
TOOL_LOG_PREFIX="claude_design"
TOOL_SCRIPT="claude-slice-design.sh"

SLICE_ID="${1:?Usage: claude-slice-design.sh <slice-id>   e.g.  claude-slice-design.sh 2.1}"

rpl_require_tool claude \
  "npm install -g @anthropic-ai/claude-code" \
  "https://docs.anthropic.com/en/docs/claude-code"

rpl_preflight
LOG_DIR=$(rpl_init_log_dir)

WALL_TIME=${FACTORY_WALL_TIME_SEC:-1800}

PROMPT=$(cat <<PROMPT_EOF
You are Claude, the Architect. The architecture assigns slice ${SLICE_ID} to you (Owner: claude) — this slice is design/architecture work, not implementation.

Steps:

1. Read CLAUDE.md, ARCHITECTURE.md, TASKS.md, SECURITY.md, and every docs/adr/*.md. Read CURSOR_HANDOFF.md and CODEX_HANDOFF.md if present.
2. Find slice ${SLICE_ID} in TASKS.md. Set its Status to in-progress and keep Owner as claude.
3. Produce the design artifact the slice's acceptance criteria call for — an ADR under docs/adr/, a design note, a schema, or an interface contract. Inspect source files only — do not grep, cat, or read files inside node_modules/, .factory-logs/, dist/, or build/.
4. When the design is complete, set slice ${SLICE_ID} Status to awaiting-review so Codex reviews it through the normal per-slice gate. Do NOT mark it approved yourself.
5. End with:
   Work completed: designed slice ${SLICE_ID}
   FACTORY_STATUS={"role":"claude","action":"slice-design","slice":"${SLICE_ID}","status":"design-complete","details":"<one-line summary>"}

If you cannot proceed (the slice needs a product-owner decision, or it is mis-scoped):
- Set slice ${SLICE_ID} Status to human-needed in TASKS.md.
- Append a new entry to ESCALATIONS.md with reason, context, what you tried, and recommended action.
- End with:
   Work completed: escalated slice ${SLICE_ID}
   FACTORY_STATUS={"role":"claude","action":"slice-design","slice":"${SLICE_ID}","status":"escalated","details":"<short reason>"}

Do NOT commit changes — the orchestrator commits. Do not work on slices other than ${SLICE_ID}. Do not edit the phase review entry — the orchestrator manages it.
PROMPT_EOF
)

CLAUDE_FLAGS=(--dangerously-skip-permissions)
[ -n "${RUN_PHASE_CLAUDE_MODEL:-}" ] && CLAUDE_FLAGS+=(--model "$RUN_PHASE_CLAUDE_MODEL")
if [ -n "${RUN_PHASE_CLAUDE_MAX_TURNS:-}" ]; then
  CLAUDE_FLAGS+=(--max-turns "$RUN_PHASE_CLAUDE_MAX_TURNS")
fi

log "Invoking Claude to design slice $SLICE_ID (wall-time cap ${WALL_TIME}s)..."
set +e
timeout "$WALL_TIME" claude -p "$PROMPT" "${CLAUDE_FLAGS[@]}" 2>&1 | tee "$LOG_DIR/work.log"
claude_rc=${PIPESTATUS[0]}
set -e

if [ "$claude_rc" -eq 124 ]; then
  err "Claude CLI timed out after ${WALL_TIME}s"
  factory_log_escalation ESCALATIONS.md "claude" "slice $SLICE_ID" "iteration-cap-hit" \
    "Claude CLI exceeded the per-session wall-time cap during slice design." \
    "Single invocation hit timeout at ${WALL_TIME}s. Log: $LOG_DIR/work.log" \
    "Review the slice scope or increase FACTORY_WALL_TIME_SEC for this project." \
    >>"$LOG_DIR/escalation.log"
  echo 'FACTORY_STATUS={"role":"claude","action":"slice-design","slice":"'"$SLICE_ID"'","status":"escalated","details":"wall-time-exceeded"}'
  exit 2
fi
if [ "$claude_rc" -ne 0 ]; then
  err "Claude CLI exited with code $claude_rc"
  echo 'FACTORY_STATUS={"role":"claude","action":"slice-design","slice":"'"$SLICE_ID"'","status":"error","details":"cli-failed-rc-'"$claude_rc"'"}'
  exit 1
fi

STATUS_LINE=$(factory_extract_status_line "$LOG_DIR/work.log")
if [ -z "$STATUS_LINE" ]; then
  err "Claude did not emit FACTORY_STATUS line. Check log: $LOG_DIR/work.log"
  exit 1
fi
log "Adapter status: $STATUS_LINE"

STATUS_FIELD=$(printf '%s' "$STATUS_LINE" | python3 -c 'import sys, json; print(json.loads(sys.stdin.read()).get("status",""))')

# Drop node_modules/ noise from the saved log now that the status line is parsed.
factory_strip_log_noise "$LOG_DIR/work.log"

SUBJECT=$(rpl_extract_subject "$LOG_DIR/work.log" "Claude design slice ${SLICE_ID}")
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
  design-complete) exit 0 ;;
  escalated) exit 2 ;;
  error) exit 1 ;;
  *) log "Unknown status field '$STATUS_FIELD'; treating as continue."; exit 0 ;;
esac
