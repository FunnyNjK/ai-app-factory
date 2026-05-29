#!/usr/bin/env bash
# scripts/orchestrator/claude-phase-review.sh — one phase review via Claude Code CLI.
# Called by orchestrate.sh; can also be invoked directly for debugging.
#
# Usage: claude-phase-review.sh <phase-id>   (e.g. claude-phase-review.sh 1)
#
# Reads from CWD (must be a project root with TASKS.md, ESCALATIONS.md,
# ARCHITECTURE.md, CLAUDE.md, and approved slices in the named phase).
#
# See docs/adr/0009-autonomous-orchestrator.md for the design.

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

TOOL_NAME="Claude"
TOOL_LOG_PREFIX="claude_phase"
TOOL_SCRIPT="claude-phase-review.sh"

PHASE_ID="${1:?Usage: claude-phase-review.sh <phase-id>   e.g.  claude-phase-review.sh 1}"

rpl_require_tool claude \
  "npm install -g @anthropic-ai/claude-code" \
  "https://docs.anthropic.com/en/docs/claude-code"

rpl_preflight
LOG_DIR=$(rpl_init_log_dir)

WALL_TIME=${FACTORY_WALL_TIME_SEC:-1800}

PROMPT=$(cat <<PROMPT_EOF
You are Claude, the Architect for this AI App Factory project. Your task this session: review Phase ${PHASE_ID} as a whole.

Steps:

1. Read CLAUDE.md, ARCHITECTURE.md, TASKS.md, SECURITY.md, and every docs/adr/*.md. If a THREAT_MODEL.md or COST_ESTIMATE.md exists, read those too. Read standards/observability-standards.md from the factory if it is referenced.
2. Find the "Phase ${PHASE_ID} review" entry in TASKS.md. Confirm its Status is awaiting-review. Confirm every slice in Phase ${PHASE_ID} has Status approved. If not, abort with status=error.
3. Read the phase intent from ARCHITECTURE.md Work Breakdown.
4. Inspect what the phase produced as a whole, not slice-by-slice. Use \`git log --oneline\` to see what changed across the phase. Look for the categories listed in templates/project-skeleton/CLAUDE.md Section 10:
   - Inconsistent error formats, naming conventions, or auth patterns across slices.
   - Missing integration boundary (slice A produces X, slice B expects Y, never wired).
   - A user journey advertised by the phase that no single slice owns end-to-end.
   - Missing observability defaults from standards/observability-standards.md (where applicable).
   - New threat-model gaps after this phase's code landed.
5. Decide:

   (A) APPROVED — the phase delivers the intended capability cohesively:
       - Update TASKS.md: set Phase ${PHASE_ID} review Status to approved.
       - End with:
         Work completed: approved Phase ${PHASE_ID}
         FACTORY_STATUS={"role":"claude","action":"phase-review","phase":"${PHASE_ID}","status":"approved","details":"<one-line evidence summary>"}

   (B) PHASE-LEVEL SUB-TASKS NEEDED — integration or intent issues exist:
       - Update TASKS.md: set Phase ${PHASE_ID} review Status to in-progress, append numbered phase-level sub-tasks under that entry (use ${PHASE_ID}.review.a, ${PHASE_ID}.review.b, ...). Each sub-task must reference the affected slice(s) and be specific and testable.
       - For each phase-level sub-task that requires Cursor work, also route the affected slice back to in-progress by editing its Status line in TASKS.md.
       - Do NOT increment the phase-review Iterations counter — the orchestrator handles that.
       - End with:
         Work completed: filed N phase-level sub-tasks for Phase ${PHASE_ID}
         FACTORY_STATUS={"role":"claude","action":"phase-review","phase":"${PHASE_ID}","status":"sub-tasks-filed","details":"<short list>","sub_tasks":["${PHASE_ID}.review.a ..."]}

   (C) ESCALATE — phase review surfaces an architecture-level question only the product owner can resolve:
       - Update TASKS.md: set Phase ${PHASE_ID} review Status to human-needed.
       - Append a new entry to ESCALATIONS.md.
       - End with:
         Work completed: escalated Phase ${PHASE_ID}
         FACTORY_STATUS={"role":"claude","action":"phase-review","phase":"${PHASE_ID}","status":"escalated","details":"<short reason>"}

6. Do NOT commit changes — the orchestrator commits.

Do not file slice-level code bugs. Those belong to Codex's slice review. If you find a code-level bug that slipped past Codex, mention it in your phase review notes but do not file it as a sub-task here — surface it as a Codex-process concern in ESCALATIONS.md instead.
PROMPT_EOF
)

CLAUDE_FLAGS=(--dangerously-skip-permissions)
[ -n "${RUN_PHASE_CLAUDE_MODEL:-}" ] && CLAUDE_FLAGS+=(--model "$RUN_PHASE_CLAUDE_MODEL")
if [ -n "${RUN_PHASE_CLAUDE_MAX_TURNS:-}" ]; then
  CLAUDE_FLAGS+=(--max-turns "$RUN_PHASE_CLAUDE_MAX_TURNS")
fi

log "Invoking Claude for Phase $PHASE_ID review (wall-time cap ${WALL_TIME}s)..."
set +e
timeout "$WALL_TIME" claude -p "$PROMPT" "${CLAUDE_FLAGS[@]}" 2>&1 | tee "$LOG_DIR/work.log"
claude_rc=${PIPESTATUS[0]}
set -e

if [ "$claude_rc" -eq 124 ]; then
  err "Claude CLI timed out after ${WALL_TIME}s"
  factory_log_escalation ESCALATIONS.md "claude" "Phase $PHASE_ID review" "iteration-cap-hit" \
    "Claude CLI exceeded the per-session wall-time cap during phase review." \
    "Single invocation hit timeout at ${WALL_TIME}s. Log: $LOG_DIR/work.log" \
    "Phase review may be over-scoped; consider splitting into smaller phase boundaries, or increase FACTORY_WALL_TIME_SEC." \
    >>"$LOG_DIR/escalation.log"
  echo 'FACTORY_STATUS={"role":"claude","action":"phase-review","phase":"'"$PHASE_ID"'","status":"escalated","details":"wall-time-exceeded"}'
  exit 2
fi
if [ "$claude_rc" -ne 0 ]; then
  err "Claude CLI exited with code $claude_rc"
  echo 'FACTORY_STATUS={"role":"claude","action":"phase-review","phase":"'"$PHASE_ID"'","status":"error","details":"cli-failed-rc-'"$claude_rc"'"}'
  exit 1
fi

STATUS_LINE=$(factory_extract_status_line "$LOG_DIR/work.log")
if [ -z "$STATUS_LINE" ]; then
  err "Claude did not emit FACTORY_STATUS line. Check log: $LOG_DIR/work.log"
  exit 1
fi
log "Adapter status: $STATUS_LINE"

STATUS_FIELD=$(printf '%s' "$STATUS_LINE" | python3 -c 'import sys, json; print(json.loads(sys.stdin.read()).get("status",""))')

# If phase-level sub-tasks were filed, increment the phase-review iteration counter.
if [ "$STATUS_FIELD" = "sub-tasks-filed" ]; then
  PER_PHASE_CAP=$(python3 -c 'import re,sys
with open("TASKS.md") as f:
    for line in f:
        m=re.match(r"\|\s*Per-phase iterations\s*\|\s*(\d+)\s*\|", line)
        if m: print(m.group(1)); sys.exit(0)
print(2)')
  set +e
  factory_increment_iterations TASKS.md phase-review "$PHASE_ID" "$PER_PHASE_CAP"
  inc_rc=$?
  set -e
  if [ "$inc_rc" -eq 2 ]; then
    log "Iteration cap reached for Phase $PHASE_ID review after this sub-tasks-filed review."
    factory_log_escalation ESCALATIONS.md "claude" "Phase $PHASE_ID review" "iteration-cap-hit" \
      "Claude filed phase-level sub-tasks that pushed Phase ${PHASE_ID} to the per-phase iteration cap." \
      "See sub-tasks in TASKS.md and Claude review log at $LOG_DIR/work.log." \
      "The phase keeps coming back with integration issues. Consider pausing for an architecture review with the product owner." \
      >>"$LOG_DIR/escalation.log"
    echo 'FACTORY_STATUS={"role":"claude","action":"phase-review","phase":"'"$PHASE_ID"'","status":"escalated","details":"iteration-cap-hit-after-sub-tasks"}'
    SUBJECT=$(rpl_extract_subject "$LOG_DIR/work.log" "Claude phase ${PHASE_ID} review (cap hit)")
    rpl_commit_and_push "$SUBJECT" "$LOG_DIR/work.log" || true
    exit 2
  fi
fi

# Resolve any escalations open against this phase now that it is approved.
# The change rides in the same commit as the phase-review approval below.
if [ "$STATUS_FIELD" = "approved" ]; then
  factory_resolve_escalations_for_slice "." "$PHASE_ID"
fi

SUBJECT=$(rpl_extract_subject "$LOG_DIR/work.log" "Claude phase ${PHASE_ID} review")
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
  approved) exit 0 ;;
  sub-tasks-filed) exit 0 ;;
  escalated) exit 2 ;;
  error) exit 1 ;;
  *) log "Unknown status field '$STATUS_FIELD'; treating as continue."; exit 0 ;;
esac
