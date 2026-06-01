#!/usr/bin/env bash
# scripts/orchestrator/codereview-phase-review.sh — one post-phase CODE REVIEW
# & REFACTORING gate. Called by orchestrate.sh; can also be invoked directly.
#
# Usage: codereview-phase-review.sh <phase-id>   (e.g. codereview-phase-review.sh 1)
#
# The Code Review role is one of the five per-app delivery roles (ADR-0013). The
# tool that drives it is read from the project's .factory-roles.json
# (role "code_review"); the operator's chosen display name is injected into the
# prompt. This gate runs AFTER the security gate is approved and is the LAST gate
# of the phase; when it approves, the phase is fully done and the orchestrator
# fast-forwards main.
#
# Reads from CWD (a project root with TASKS.md, ESCALATIONS.md, ARCHITECTURE.md).
#
# See docs/adr/0013-configurable-roles-and-tools.md.

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

PHASE_ID="${1:?Usage: codereview-phase-review.sh <phase-id>   e.g.  codereview-phase-review.sh 1}"

ROLE_KEY="code_review"
TOOL=$(factory_role_tool "$ROLE_KEY")
ROLE_NAME=$(factory_role_name "$ROLE_KEY")

TOOL_NAME="$(factory_tool_label "$TOOL")"
TOOL_LOG_PREFIX="codereview_phase"
TOOL_SCRIPT="codereview-phase-review.sh"

factory_tool_require "$TOOL"

rpl_preflight
LOG_DIR=$(rpl_init_log_dir)

WALL_TIME=${FACTORY_WALL_TIME_SEC:-1800}

log "Code-review gate for Phase $PHASE_ID — role '$ROLE_NAME' driven by tool '$TOOL'."

PROMPT=$(cat <<PROMPT_EOF
You are ${ROLE_NAME}, the Code Review and Refactoring reviewer for this AI App Factory project. Your task this session: run the CODE REVIEW gate for Phase ${PHASE_ID} as a whole. This gate runs after the security gate is approved and is the last gate of the phase; it blocks the phase until it passes.

Steps:

1. Read ARCHITECTURE.md, TASKS.md, and the factory standard standards/coding-standards.md if it is referenced.
2. Find the "Phase ${PHASE_ID} code-review" entry in TASKS.md. Confirm its Status is awaiting-review. Confirm "Phase ${PHASE_ID} review" and "Phase ${PHASE_ID} security" are already approved. If not, abort with status=error.
3. Inspect what the phase produced as a whole. Use \`git log --oneline\` and \`git diff\` to see what changed across the phase. Assess maintainability, not behavior:
   - Readability, naming, and consistency of conventions across the slices in this phase.
   - Duplication that should be factored out; dead code or unused exports introduced this phase.
   - Over-complex functions, leaky abstractions, or inconsistent error handling across slices.
   - Drift from standards/coding-standards.md.
4. Decide:

   (A) APPROVED — the phase code is clean, or you applied safe, behavior-preserving refactors and the tests still pass:
       - Apply only behavior-preserving refactors (rename, extract, de-duplicate, delete dead code). Do NOT change behavior, contracts, or scope. Run the project tests and confirm they still pass after refactoring.
       - Update TASKS.md: set "Phase ${PHASE_ID} code-review" Status to approved. In its Notes, name what you reviewed and (if any) what you refactored.
       - End with:
         Work completed: code-review gate approved for Phase ${PHASE_ID}
         FACTORY_STATUS={"role":"codereview","action":"phase-code-review","phase":"${PHASE_ID}","status":"approved","details":"<one-line evidence summary>"}

   (C) ESCALATE — a maintainability problem needs a change that would alter behavior or needs design input, or you cannot safely refactor it:
       - Update TASKS.md: set "Phase ${PHASE_ID} code-review" Status to human-needed.
       - Append a new entry to ESCALATIONS.md with reason=judgment-call, the specific concern, what you tried, and the recommended action.
       - End with:
         Work completed: code-review gate escalated for Phase ${PHASE_ID}
         FACTORY_STATUS={"role":"codereview","action":"phase-code-review","phase":"${PHASE_ID}","status":"escalated","details":"<short reason>"}

5. Do NOT commit changes — the orchestrator commits.

Stay within maintainability scope: behavior-preserving refactors only. Do not add features, change public contracts, or fix security issues (those were the prior gate). If a refactor would change behavior, escalate instead. Inspect source files only — do not grep, cat, or read files inside node_modules/, .factory-logs/, dist/, or build/. Before the final two lines of your response, include a short Self-critique section — assumptions you made, anything you skipped or deferred, and what the product owner or next session should double-check. Be blunt; write "none" for any item that is empty.
PROMPT_EOF
)

log "Invoking $TOOL for Phase $PHASE_ID code-review gate (wall-time cap ${WALL_TIME}s)..."
set +e
factory_tool_invoke "$TOOL" "$PROMPT" "$LOG_DIR/work.log" "$WALL_TIME"
tool_rc=$?
set -e

if [ "$tool_rc" -eq 124 ]; then
  err "$TOOL timed out after ${WALL_TIME}s"
  factory_log_escalation ESCALATIONS.md "codereview" "Phase $PHASE_ID code-review" "iteration-cap-hit" \
    "The code-review tool exceeded the per-session wall-time cap during the Phase ${PHASE_ID} code-review gate." \
    "Single invocation hit timeout at ${WALL_TIME}s. Log: $LOG_DIR/work.log" \
    "Code-review may be over-scoped; split the phase or increase FACTORY_WALL_TIME_SEC." \
    >>"$LOG_DIR/escalation.log"
  echo 'FACTORY_STATUS={"role":"codereview","action":"phase-code-review","phase":"'"$PHASE_ID"'","status":"escalated","details":"wall-time-exceeded"}'
  exit 2
fi
if [ "$tool_rc" -ne 0 ]; then
  err "$TOOL exited with code $tool_rc"
  echo 'FACTORY_STATUS={"role":"codereview","action":"phase-code-review","phase":"'"$PHASE_ID"'","status":"error","details":"cli-failed-rc-'"$tool_rc"'"}'
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

# On approval: resolve any escalations open against this phase. This is the last
# gate — the orchestrator detects full-phase approval and fast-forwards main.
if [ "$STATUS_FIELD" = "approved" ]; then
  factory_resolve_escalations_for_slice "." "$PHASE_ID"
fi

SUBJECT=$(rpl_extract_subject "$LOG_DIR/work.log" "Code-review gate Phase ${PHASE_ID}")
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
  escalated) exit 2 ;;
  error) exit 1 ;;
  *) log "Unknown status field '$STATUS_FIELD'; treating as continue."; exit 0 ;;
esac
