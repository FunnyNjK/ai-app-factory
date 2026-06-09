#!/usr/bin/env bash
# scripts/orchestrator/gate-d-signoff.sh — run the Gate D six-party sign-off
# ceremony for a project whose every phase gate is already approved.
# Called by orchestrate.sh when factory_next_action returns
# "orchestrator gate-d-signoff -"; can also be invoked directly for recovery.
#
# Usage: gate-d-signoff.sh [ignored-id]
#
# Runs FIVE headless agent sub-sessions in order — Architect, Developer, Quality
# Engineer, Security, Code Review — each driven by the tool its role is mapped to
# in .factory-roles.json (ADR-0013) and each filling ITS OWN section of
# SIGNOFF.md. The sixth party, the product owner, is a human; an escalation is
# written and the adapter exits 2 (human-needed) so the orchestrator halts.
#
# See docs/adr/0013-configurable-roles-and-tools.md (five-role team, six-party
# Gate D — supersedes the three-agent model of ADR-0006) and
# docs/adr/0010-gate-d-signoff-adapter.md (this adapter).

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# Re-exec under bash >= 4 before parsing the prompt heredocs below (ADR-0015).
# shellcheck source=require-bash4.sh
. "$SCRIPT_DIR/require-bash4.sh"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

TOOL_NAME="Orchestrator"
TOOL_LOG_PREFIX="gate_d_signoff"
TOOL_SCRIPT="gate-d-signoff.sh"

# The orchestrator dispatches with a placeholder id ("-"); it is unused here.
: "${1:-}"

# --- Resolve the five roles -> tools + display names (ADR-0013) -----------

ARCHITECT_TOOL=$(factory_role_tool architect);   ARCHITECT_NAME=$(factory_role_name architect)
DEVELOPER_TOOL=$(factory_role_tool developer);   DEVELOPER_NAME=$(factory_role_name developer)
TESTER_TOOL=$(factory_role_tool tester);         TESTER_NAME=$(factory_role_name tester)
SECURITY_TOOL=$(factory_role_tool security);     SECURITY_NAME=$(factory_role_name security)
CODEREVIEW_TOOL=$(factory_role_tool code_review); CODEREVIEW_NAME=$(factory_role_name code_review)

# Require each role's tool (calling for a repeated tool is a harmless re-check).
factory_tool_require "$ARCHITECT_TOOL"
factory_tool_require "$DEVELOPER_TOOL"
factory_tool_require "$TESTER_TOOL"
factory_tool_require "$SECURITY_TOOL"
factory_tool_require "$CODEREVIEW_TOOL"

rpl_preflight
LOG_DIR=$(rpl_init_log_dir)

WALL_TIME=${FACTORY_WALL_TIME_SEC:-1800}
DATE=$(date +%Y-%m-%d)

# --- Preconditions --------------------------------------------------------

if ! factory_all_phases_approved TASKS.md; then
  err "Gate D sign-off requires every phase gate in TASKS.md to be approved."
  err "factory_all_phases_approved reported at least one phase gate is not approved."
  echo 'FACTORY_STATUS={"role":"orchestrator","action":"gate-d-signoff","status":"error","details":"not all phase gates approved"}'
  exit 1
fi

if [ ! -f SIGNOFF.md ]; then
  err "No SIGNOFF.md in this project. Scaffolding copies templates/SIGNOFF.md; restore it before running Gate D."
  echo 'FACTORY_STATUS={"role":"orchestrator","action":"gate-d-signoff","status":"error","details":"SIGNOFF.md missing"}'
  exit 1
fi

# --- One sign-off sub-session ---------------------------------------------
# run_signoff TOOL NAME ROLE_TITLE SECTION OPTIONS SIGNER ROLE_JSON LOGFILE REVIEW
# The prompt is deliberately free of apostrophes and backticks so the unquoted
# heredoc inside $() is parsed identically across shells.
run_signoff() {
  local tool="$1" name="$2" title="$3" section="$4" options="$5" signer="$6" role_json="$7" logfile="$8" review="$9"
  local prompt
  prompt=$(cat <<PROMPT_EOF
You are ${name}, the ${title}, recording your Gate D sign-off for this project. Every phase gate in TASKS.md is approved; this is the release-readiness sign-off for the six-party Gate D (ADR-0013).

Review (read, do not change): ${review} Inspect source files only — do not grep, cat, or read files inside node_modules/, .factory-logs/, dist/, or build/.

Then edit SIGNOFF.md, the "${section}" section ONLY:
- Replace the Decision option list after "**Decision:**" with exactly one choice: ${options}.
- Replace the placeholder prose under "**Notes:**" with 2-6 sentences that name the specific artifacts you reviewed and what convinced you. Link any deviation to the ADR that covers it.
- In the "**Signed:**" line replace YYYY-MM-DD with ${DATE}. Set the signer text to "${signer}".
- If your section is already filled in (its Signed line shows a real date, not YYYY-MM-DD), make no changes and simply confirm.

Do NOT edit any other sign-off section, and do NOT edit any other file. Do NOT commit — the orchestrator commits.

End your response with exactly these two lines:
Work completed: ${title} Gate D sign-off recorded in SIGNOFF.md
FACTORY_STATUS={"role":"${role_json}","action":"gate-d-signoff","status":"signed","details":"<one-line decision>"}
PROMPT_EOF
)
  local rc=0
  set +e
  factory_tool_invoke "$tool" "$prompt" "$logfile" "$WALL_TIME"
  rc=$?
  set -e
  return "$rc"
}

# --- Run the five agent sessions in order ---------------------------------

log "Gate D: recording five agent sign-offs (wall-time cap ${WALL_TIME}s each)."

log "[1/5] Architect sign-off — ${ARCHITECT_NAME} via ${ARCHITECT_TOOL}..."
set +e
run_signoff "$ARCHITECT_TOOL" "$ARCHITECT_NAME" "Architect" "## Architect sign-off" \
  "Approved, or Approved with notes, or Blocked" "${ARCHITECT_NAME} (architect)" "claude" \
  "$LOG_DIR/architect.log" \
  "ARCHITECTURE.md against the implemented system; every docs/adr/*.md including project-local ADRs; the TASKS.md phase reviews; ESCALATIONS.md; THREAT_MODEL.md and COST_ESTIMATE.md if they exist; standards/observability-standards.md if referenced."
arch_rc=$?
set -e
[ "$arch_rc" -ne 0 ] && err "Architect sign-off session exited rc=$arch_rc (continuing; final state is checked below)."

log "[2/5] Developer sign-off — ${DEVELOPER_NAME} via ${DEVELOPER_TOOL}..."
set +e
run_signoff "$DEVELOPER_TOOL" "$DEVELOPER_NAME" "Developer" "## Developer sign-off" \
  "Approved, or Approved with notes, or Blocked" "${DEVELOPER_NAME} (developer)" "cursor" \
  "$LOG_DIR/developer.log" \
  "the acceptance criteria from CURSOR_HANDOFF.md and ARCHITECTURE.md; the test suite results; .env.example and the built bundle for secret leakage; README.md and RUNBOOK.md against the implementation; any escalation trails in ESCALATIONS.md."
dev_rc=$?
set -e
[ "$dev_rc" -ne 0 ] && err "Developer sign-off session exited rc=$dev_rc (continuing; final state is checked below)."

log "[3/5] Quality Engineer sign-off — ${TESTER_NAME} via ${TESTER_TOOL}..."
set +e
run_signoff "$TESTER_TOOL" "$TESTER_NAME" "Quality Engineer" "## Quality Engineer sign-off" \
  "Ready, or Ready with documented risks, or Not ready" "${TESTER_NAME} (quality engineer)" "codex" \
  "$LOG_DIR/tester.log" \
  "TEST_PLAN.md execution results if present; the critical user journeys against the implementation; security smoke checks; the accessibility baseline; the observability signal during a representative run; TASKS.md; ESCALATIONS.md."
qe_rc=$?
set -e
[ "$qe_rc" -ne 0 ] && err "Quality Engineer sign-off session exited rc=$qe_rc (continuing; final state is checked below)."

log "[4/5] Security sign-off — ${SECURITY_NAME} via ${SECURITY_TOOL}..."
set +e
run_signoff "$SECURITY_TOOL" "$SECURITY_NAME" "Security" "## Security sign-off" \
  "Pass, or Pass with documented risks, or Fail" "${SECURITY_NAME} (security)" "security" \
  "$LOG_DIR/security.log" \
  "SECURITY.md and THREAT_MODEL.md if present against the implementation; the per-phase security gate results in TASKS.md; secret scanning of the tree; input validation, authorization, and webhook verification where applicable; dependency risk."
sec_rc=$?
set -e
[ "$sec_rc" -ne 0 ] && err "Security sign-off session exited rc=$sec_rc (continuing; final state is checked below)."

log "[5/5] Code Review sign-off — ${CODEREVIEW_NAME} via ${CODEREVIEW_TOOL}..."
set +e
run_signoff "$CODEREVIEW_TOOL" "$CODEREVIEW_NAME" "Code Review" "## Code Review sign-off" \
  "Approved, or Approved with notes, or Blocked" "${CODEREVIEW_NAME} (code review)" "codereview" \
  "$LOG_DIR/codereview.log" \
  "the per-phase code-review gate results in TASKS.md; readability, duplication, and complexity across the codebase; consistency with standards/coding-standards.md; any refactors noted during the build."
cr_rc=$?
set -e
[ "$cr_rc" -ne 0 ] && err "Code Review sign-off session exited rc=$cr_rc (continuing; final state is checked below)."

# Safety net: resolve any escalations still open against now-approved phases.
# Slice-level escalations were already resolved at slice approval.
while IFS= read -r _phase; do
  [ -n "$_phase" ] && factory_resolve_escalations_for_slice "." "$_phase"
done < <(factory_phase_numbers TASKS.md)

# --- Classify the result and escalate the product-owner sign-off ----------

STATE=$(factory_signoff_state SIGNOFF.md)
log "SIGNOFF.md state after the five agent sessions: $STATE"

if [ "$STATE" = "agents-signed" ] || [ "$STATE" = "complete" ]; then
  factory_log_escalation ESCALATIONS.md "orchestrator" "Gate D sign-off" "judgment-call" \
    "The five agent sign-offs (architect, developer, quality engineer, security, code review) are recorded in SIGNOFF.md. The sixth, the product-owner sign-off, is a human decision the factory cannot make on its own." \
    "Ran the five Gate D sign-off sessions; each wrote its own section of SIGNOFF.md. Session logs are under $LOG_DIR/." \
    "Review the five agent sign-offs and complete the product-owner section of SIGNOFF.md (Decision, Notes, the accepted-risks re-review date, Signed). If you accept documented risks, the re-review date must be a real date - an acceptance without one is not a valid sign-off (ADR-0010). Then re-run the orchestrator to close the run." \
    >>"$LOG_DIR/escalation.log"
  DETAILS="five agent sign-offs complete; product-owner sign-off required"
else
  factory_log_escalation ESCALATIONS.md "orchestrator" "Gate D sign-off" "judgment-call" \
    "One or more agent Gate D sign-off sub-sessions did not fill its section of SIGNOFF.md (state: ${STATE})." \
    "Ran the five sign-off sessions; at least one section was not completed. Per-session logs are under $LOG_DIR/." \
    "Inspect SIGNOFF.md and the session logs, re-run gate-d-signoff.sh (already-signed sections are left untouched) or complete the missing agent section(s) by hand, then complete the product-owner section." \
    >>"$LOG_DIR/escalation.log"
  DETAILS="gate-d sign-off incomplete (state: ${STATE}); human review required"
fi

SUBJECT="Gate D: record agent sign-offs in SIGNOFF.md"
set +e
rpl_commit_and_push "$SUBJECT" "$LOG_DIR"
commit_rc=$?
set -e
case "$commit_rc" in
  0) log "Committed Gate D sign-off changes." ;;
  2) log "No changes to commit (sign-off sessions made no edits)." ;;
  *) err "Commit/push failed (rc=$commit_rc)"; exit 1 ;;
esac

echo 'FACTORY_STATUS={"role":"orchestrator","action":"gate-d-signoff","status":"human-needed","details":"'"$DETAILS"'"}'
exit 2
