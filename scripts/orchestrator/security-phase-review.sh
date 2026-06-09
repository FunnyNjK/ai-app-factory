#!/usr/bin/env bash
# scripts/orchestrator/security-phase-review.sh — one post-phase SECURITY gate.
# Called by orchestrate.sh; can also be invoked directly for debugging.
#
# Usage: security-phase-review.sh <phase-id>   (e.g. security-phase-review.sh 1)
#
# The Security role is one of the five per-app delivery roles (ADR-0013). The
# tool that drives it is read from the project's .factory-roles.json
# (role "security"); the operator's chosen display name is injected into the
# prompt. This gate runs AFTER the architect's phase review is approved and
# BEFORE the code-review gate; it blocks the phase.
#
# Reads from CWD (a project root with TASKS.md, ESCALATIONS.md, ARCHITECTURE.md,
# SECURITY.md, and THREAT_MODEL.md if present).
#
# See docs/adr/0013-configurable-roles-and-tools.md and
# docs/adr/0011-recurring-security-review-for-sensitive-projects.md.

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# Re-exec under bash >= 4 before parsing the prompt heredocs below (ADR-0015).
# shellcheck source=require-bash4.sh
. "$SCRIPT_DIR/require-bash4.sh"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

PHASE_ID="${1:?Usage: security-phase-review.sh <phase-id>   e.g.  security-phase-review.sh 1}"

ROLE_KEY="security"
TOOL=$(factory_role_tool "$ROLE_KEY")
ROLE_NAME=$(factory_role_name "$ROLE_KEY")

TOOL_NAME="$(factory_tool_label "$TOOL")"
TOOL_LOG_PREFIX="security_phase"
TOOL_SCRIPT="security-phase-review.sh"

factory_tool_require "$TOOL"

rpl_preflight
LOG_DIR=$(rpl_init_log_dir)

WALL_TIME=${FACTORY_WALL_TIME_SEC:-1800}

log "Security gate for Phase $PHASE_ID — role '$ROLE_NAME' driven by tool '$TOOL'."

PROMPT=$(cat <<PROMPT_EOF
You are ${ROLE_NAME}, the Security reviewer for this AI App Factory project. Your task this session: run the SECURITY gate for Phase ${PHASE_ID} as a whole. This gate runs after the architect phase review is approved and blocks the phase until it passes.

Steps:

1. Read SECURITY.md, ARCHITECTURE.md, TASKS.md, every docs/adr/*.md, and THREAT_MODEL.md if it exists. Read the factory standard standards/security-standards.md if it is referenced.
2. Find the "Phase ${PHASE_ID} security" entry in TASKS.md. Confirm its Status is awaiting-review. Confirm "Phase ${PHASE_ID} review" is already approved. If not, abort with status=error.
3. Inspect what the phase produced as a whole. Use \`git log --oneline\` and \`git diff\` to see what changed across the phase. Check for, at minimum:
   - Secrets, keys, tokens, or credentials committed to source (anything beyond .env.example placeholders).
   - Missing input validation at trust boundaries (API handlers, form posts, webhook bodies).
   - Authentication / authorization gaps on protected routes or operations.
   - Webhook signature verification and idempotency where external callbacks exist (Stripe, Plaid, Postmark).
   - Sensitive data logged, returned in errors, or stored when it should not be.
   - Risky dependencies or unsafe file/network/shell behavior introduced this phase.
4. Decide:

   (A) APPROVED — no security defect, or you fixed every defect you found with focused, behavior-preserving changes and the tests still pass:
       - If you made fixes, keep them minimal and in-scope for security hardening; run the project tests and confirm they pass.
       - Update TASKS.md: set "Phase ${PHASE_ID} security" Status to approved. In its Notes, name what you reviewed and (if any) what you hardened.
       - End with:
         Work completed: security gate approved for Phase ${PHASE_ID}
         FACTORY_STATUS={"role":"security","action":"phase-security","phase":"${PHASE_ID}","status":"approved","details":"<one-line evidence summary>"}

   (C) ESCALATE — a finding needs human judgment (secret/credential provisioning, a compliance question, or a fix large enough to need design input) or you cannot safely remediate it:
       - Update TASKS.md: set "Phase ${PHASE_ID} security" Status to human-needed.
       - Append a new entry to ESCALATIONS.md with reason=judgment-call (or secret-needed), the specific finding, what you tried, and the recommended action.
       - End with:
         Work completed: security gate escalated for Phase ${PHASE_ID}
         FACTORY_STATUS={"role":"security","action":"phase-security","phase":"${PHASE_ID}","status":"escalated","details":"<short reason>"}

5. Do NOT commit changes — the orchestrator commits.

Stay within security scope: do not add features or do unrelated refactors (that is the Code Review role gate, which runs next). Inspect source files only — do not grep, cat, or read files inside node_modules/, .factory-logs/, dist/, or build/. Before the final two lines of your response, include a short Self-critique section — assumptions you made, anything you skipped or deferred, and what the product owner or next session should double-check. Be blunt; write "none" for any item that is empty.
PROMPT_EOF
)

log "Invoking $TOOL for Phase $PHASE_ID security gate (wall-time cap ${WALL_TIME}s)..."
set +e
factory_tool_invoke "$TOOL" "$PROMPT" "$LOG_DIR/work.log" "$WALL_TIME"
tool_rc=$?
set -e

if [ "$tool_rc" -eq 124 ]; then
  err "$TOOL timed out after ${WALL_TIME}s"
  factory_log_escalation ESCALATIONS.md "security" "Phase $PHASE_ID security" "iteration-cap-hit" \
    "The security tool exceeded the per-session wall-time cap during the Phase ${PHASE_ID} security gate." \
    "Single invocation hit timeout at ${WALL_TIME}s. Log: $LOG_DIR/work.log" \
    "Security review may be over-scoped; split the phase or increase FACTORY_WALL_TIME_SEC." \
    >>"$LOG_DIR/escalation.log"
  echo 'FACTORY_STATUS={"role":"security","action":"phase-security","phase":"'"$PHASE_ID"'","status":"escalated","details":"wall-time-exceeded"}'
  exit 2
fi
if [ "$tool_rc" -ne 0 ]; then
  err "$TOOL exited with code $tool_rc"
  echo 'FACTORY_STATUS={"role":"security","action":"phase-security","phase":"'"$PHASE_ID"'","status":"error","details":"cli-failed-rc-'"$tool_rc"'"}'
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

# On approval: resolve any escalations open against this phase and chain to the
# code-review gate (ADR-0013). The change rides in the same commit below.
if [ "$STATUS_FIELD" = "approved" ]; then
  factory_resolve_escalations_for_slice "." "$PHASE_ID"
  factory_set_phase_item_awaiting TASKS.md phase-code-review "$PHASE_ID"
fi

SUBJECT=$(rpl_extract_subject "$LOG_DIR/work.log" "Security gate Phase ${PHASE_ID}")
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
