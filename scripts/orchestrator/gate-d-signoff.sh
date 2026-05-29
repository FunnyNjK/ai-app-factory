#!/usr/bin/env bash
# scripts/orchestrator/gate-d-signoff.sh — run the Gate D four-party sign-off
# ceremony for a project whose every phase review is already approved.
# Called by orchestrate.sh when factory_next_action returns
# "orchestrator gate-d-signoff -"; can also be invoked directly for recovery.
#
# Usage: gate-d-signoff.sh [ignored-id]
#
# Runs three headless sub-sessions in order — Claude (architect), Codex
# (quality engineer), Cursor (developer) — each filling ITS OWN section of
# SIGNOFF.md. The product-owner section is left for a human; an escalation is
# written and the adapter exits 2 (human-needed) so the orchestrator halts.
#
# See docs/adr/0006-three-agent-signoff.md (four-party sign-off) and
# docs/adr/0010-gate-d-signoff-adapter.md (this adapter).

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

TOOL_NAME="Orchestrator"
TOOL_LOG_PREFIX="gate_d_signoff"
TOOL_SCRIPT="gate-d-signoff.sh"

# The orchestrator dispatches with a placeholder id ("-"); it is unused here.
: "${1:-}"

rpl_require_tool claude \
  "npm install -g @anthropic-ai/claude-code" \
  "https://docs.anthropic.com/en/docs/claude-code"
rpl_require_tool codex \
  "npm install -g @openai/codex" \
  "https://github.com/openai/codex"
rpl_require_tool agent \
  "curl https://cursor.com/install -fsS | bash" \
  "https://cursor.com/docs/cli"

rpl_preflight
LOG_DIR=$(rpl_init_log_dir)

WALL_TIME=${FACTORY_WALL_TIME_SEC:-1800}
DATE=$(date +%Y-%m-%d)

# --- Preconditions --------------------------------------------------------

if ! factory_all_phases_approved TASKS.md; then
  err "Gate D sign-off requires every phase review in TASKS.md to be approved."
  err "factory_all_phases_approved reported at least one phase review is not approved."
  echo 'FACTORY_STATUS={"role":"orchestrator","action":"gate-d-signoff","status":"error","details":"not all phase reviews approved"}'
  exit 1
fi

if [ ! -f SIGNOFF.md ]; then
  err "No SIGNOFF.md in this project. Scaffolding copies templates/SIGNOFF.md; restore it before running Gate D."
  echo 'FACTORY_STATUS={"role":"orchestrator","action":"gate-d-signoff","status":"error","details":"SIGNOFF.md missing"}'
  exit 1
fi

# --- Sub-session runner ---------------------------------------------------
# Each tool keeps its own flag conventions (mirrors the per-role adapters).
run_session() {
  local tool="$1" logfile="$2" prompt="$3"
  local rc=0
  case "$tool" in
    claude)
      local flags=(--dangerously-skip-permissions)
      [ -n "${RUN_PHASE_CLAUDE_MODEL:-}" ] && flags+=(--model "$RUN_PHASE_CLAUDE_MODEL")
      [ -n "${RUN_PHASE_CLAUDE_MAX_TURNS:-}" ] && flags+=(--max-turns "$RUN_PHASE_CLAUDE_MAX_TURNS")
      set +e
      timeout "$WALL_TIME" claude -p "$prompt" "${flags[@]}" 2>&1 | tee "$logfile"
      rc=${PIPESTATUS[0]}
      set -e
      ;;
    codex)
      local flags=(--sandbox workspace-write)
      [ -n "${RUN_PHASE_CODEX_MODEL:-}" ] && flags+=(--model "$RUN_PHASE_CODEX_MODEL")
      if [ -n "${RUN_PHASE_CODEX_APPROVAL_FLAG:-}" ]; then
        local _approval
        read -r -a _approval <<<"$RUN_PHASE_CODEX_APPROVAL_FLAG"
        flags+=("${_approval[@]}")
      fi
      set +e
      timeout "$WALL_TIME" codex exec "${flags[@]}" "$prompt" 2>&1 | tee "$logfile"
      rc=${PIPESTATUS[0]}
      set -e
      ;;
    cursor)
      local flags=(--trust --force --sandbox disabled --output-format text)
      [ -n "${RUN_PHASE_CURSOR_MODEL:-}" ] && flags+=(--model "$RUN_PHASE_CURSOR_MODEL")
      set +e
      timeout "$WALL_TIME" agent -p "${flags[@]}" -- "$prompt" 2>&1 | tee "$logfile"
      rc=${PIPESTATUS[0]}
      set -e
      ;;
  esac
  return "$rc"
}

# --- Prompts (one section each) -------------------------------------------
# Unquoted heredoc so ${DATE} expands; deliberately free of backticks so the
# shell does not treat any token as a command substitution.

CLAUDE_PROMPT=$(cat <<PROMPT_EOF
You are Claude, the Architect, recording your Gate D sign-off for this project. Every phase review in TASKS.md is approved; this is the release-readiness sign-off defined in docs/adr/0006-three-agent-signoff.md.

Review (read, do not change): ARCHITECTURE.md against the implemented system; every docs/adr/*.md including project-local ADRs; the TASKS.md phase reviews; ESCALATIONS.md; THREAT_MODEL.md and COST_ESTIMATE.md if they exist; standards/observability-standards.md if referenced. Inspect source files only — do not grep, cat, or read files inside node_modules/, .factory-logs/, dist/, or build/.

Then edit SIGNOFF.md, the "## Architect (Claude) sign-off" section ONLY:
- Replace the Decision option list after "**Decision:**" with exactly one choice: Approved, or Approved with notes, or Blocked.
- Replace the placeholder prose under "**Notes:**" with 2-6 sentences that name the specific artifacts you reviewed (the ADRs, the phase reviews, the threat model) and what convinced you. Link any deviation to the ADR that covers it.
- In the "**Signed:**" line replace YYYY-MM-DD with ${DATE}. Keep the signer text "Claude (architect)".
- If your section is already filled in (its Signed line shows a real date, not YYYY-MM-DD), make no changes and simply confirm.

Do NOT edit the Developer, Quality Engineer, or Product owner sections. Do NOT edit any other file. Do NOT commit — the orchestrator commits.

End your response with exactly these two lines:
Work completed: architect Gate D sign-off recorded in SIGNOFF.md
FACTORY_STATUS={"role":"claude","action":"gate-d-signoff","status":"signed","details":"<one-line decision>"}
PROMPT_EOF
)

CODEX_PROMPT=$(cat <<PROMPT_EOF
You are Codex, the Quality Engineer, recording your Gate D sign-off for this project. Every phase review in TASKS.md is approved.

Review (read, do not change): TEST_PLAN.md execution results if present; the critical user journeys against the implementation; security smoke checks (secret scan, webhook verification, auth where applicable); the accessibility baseline; the observability signal during a representative run; TASKS.md; ESCALATIONS.md; and the Architect sign-off already written in SIGNOFF.md (you may reference it). Inspect source files only — do not grep, cat, or read files inside node_modules/, .factory-logs/, dist/, or build/.

Then edit SIGNOFF.md, the "## Quality Engineer (Codex) sign-off" section ONLY:
- Replace the Decision option list after "**Decision:**" with exactly one choice: Ready, or Ready with documented risks, or Not ready.
- Replace the placeholder prose under "**Notes:**" with 2-6 sentences. If Ready with documented risks, link each risk explicitly and name the residual coverage gaps.
- In the "**Signed:**" line replace YYYY-MM-DD with ${DATE}. Keep the signer text "Codex (quality engineer)".
- If your section is already filled in (its Signed line shows a real date, not YYYY-MM-DD), make no changes and simply confirm.

Do NOT edit the Architect, Developer, or Product owner sections. Do NOT edit any other file. Do NOT commit.

End your response with exactly these two lines:
Work completed: quality-engineer Gate D sign-off recorded in SIGNOFF.md
FACTORY_STATUS={"role":"codex","action":"gate-d-signoff","status":"signed","details":"<one-line decision>"}
PROMPT_EOF
)

CURSOR_PROMPT=$(cat <<PROMPT_EOF
You are Cursor, the Developer, recording your Gate D sign-off for this project. Every phase review in TASKS.md is approved.

Review (read, do not change): the acceptance criteria from CURSOR_HANDOFF.md and ARCHITECTURE.md; the test suite results; .env.example and the built bundle for secret leakage; README.md and RUNBOOK.md against the implementation; any escalation trails in ESCALATIONS.md; and the Architect and Quality Engineer sign-offs already in SIGNOFF.md (you may reference them). Inspect source files only — do not grep, cat, or read files inside node_modules/, .factory-logs/, dist/, or build/.

Then edit SIGNOFF.md, the "## Developer (Cursor) sign-off" section ONLY:
- Replace the Decision option list after "**Decision:**" with exactly one choice: Approved, or Approved with notes, or Blocked.
- Replace the placeholder prose under "**Notes:**" with 2-6 sentences. Name any known limitations and where they are documented; if approval is conditional, name the condition.
- In the "**Signed:**" line replace YYYY-MM-DD with ${DATE}. Keep the signer text "Cursor (developer)".
- If your section is already filled in (its Signed line shows a real date, not YYYY-MM-DD), make no changes and simply confirm.

Do NOT edit the Architect, Quality Engineer, or Product owner sections. Do NOT edit any other file. Do NOT commit.

End your response with exactly these two lines:
Work completed: developer Gate D sign-off recorded in SIGNOFF.md
FACTORY_STATUS={"role":"cursor","action":"gate-d-signoff","status":"signed","details":"<one-line decision>"}
PROMPT_EOF
)

# --- Run the three sessions in order: Claude -> Codex -> Cursor -----------

log "Gate D: recording three agent sign-offs (wall-time cap ${WALL_TIME}s each)."

log "[1/3] Claude (architect) sign-off..."
set +e
run_session claude "$LOG_DIR/claude.log" "$CLAUDE_PROMPT"
claude_rc=$?
set -e
[ "$claude_rc" -ne 0 ] && err "Claude sign-off session exited rc=$claude_rc (continuing; final state is checked below)."

log "[2/3] Codex (quality engineer) sign-off..."
set +e
run_session codex "$LOG_DIR/codex.log" "$CODEX_PROMPT"
codex_rc=$?
set -e
[ "$codex_rc" -ne 0 ] && err "Codex sign-off session exited rc=$codex_rc (continuing; final state is checked below)."

log "[3/3] Cursor (developer) sign-off..."
set +e
run_session cursor "$LOG_DIR/cursor.log" "$CURSOR_PROMPT"
cursor_rc=$?
set -e
[ "$cursor_rc" -ne 0 ] && err "Cursor sign-off session exited rc=$cursor_rc (continuing; final state is checked below)."

# --- Classify the result and escalate the product-owner sign-off ----------

STATE=$(factory_signoff_state SIGNOFF.md)
log "SIGNOFF.md state after the three agent sessions: $STATE"

if [ "$STATE" = "agents-signed" ] || [ "$STATE" = "complete" ]; then
  factory_log_escalation ESCALATIONS.md "orchestrator" "Gate D sign-off" "judgment-call" \
    "The three agent sign-offs (architect, developer, quality engineer) are recorded in SIGNOFF.md. The fourth, the product-owner sign-off, is a human decision the factory cannot make on its own." \
    "Ran the Claude, Codex, and Cursor Gate D sign-off sessions; each wrote its own section of SIGNOFF.md. Session logs are under $LOG_DIR/." \
    "Review the three agent sign-offs and complete the product-owner section of SIGNOFF.md (Decision, Notes, Signed), then re-run the orchestrator to close the run." \
    >>"$LOG_DIR/escalation.log"
  DETAILS="three agent sign-offs complete; product-owner sign-off required"
else
  factory_log_escalation ESCALATIONS.md "orchestrator" "Gate D sign-off" "judgment-call" \
    "One or more agent Gate D sign-off sub-sessions did not fill its section of SIGNOFF.md (state: ${STATE})." \
    "Ran the Claude, Codex, and Cursor sign-off sessions; at least one section was not completed. Per-session logs are under $LOG_DIR/." \
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
