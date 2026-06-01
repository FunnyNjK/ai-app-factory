#!/usr/bin/env bash
# scripts/factory.sh — context-aware interactive launcher for the AI App Factory.
#
# Run it with no arguments:
#   - inside the factory repo            -> kickoff menu (status, scaffold, open a project)
#   - inside a scaffolded project folder -> build menu (status, next step, autopilot, settings)
#
# Non-interactive (scriptable, testable):
#   factory.sh --next      print the next command to run in the current project
#   factory.sh --status    print current project status (next action + escalations)
#   factory.sh -h|--help   show this help
#
# This is a thin launcher: all real work stays in the existing scripts and in
# the claude/codex/agent CLIs. See docs/adr/0012-interactive-factory-tui.md.

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
FACTORY_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
ORCH_DIR="$SCRIPT_DIR/orchestrator"
LIB="$ORCH_DIR/lib.sh"

# Session settings (inherit from the environment, then let the menu toggle them).
SETTING_NO_PUSH="${RUN_PHASE_NO_PUSH:-0}"
SETTING_CODEX_SANDBOX="${RUN_PHASE_CODEX_APPROVAL_FLAG:-}"

say() { printf '%s\n' "$*"; }
hr()  { printf -- '------------------------------------------------------------\n'; }

# Map an orchestrator role+kind to its adapter script (mirrors orchestrate.sh's dispatch).
adapter_for() {
  case "$1-$2" in
    cursor-slice)                echo "cursor-slice.sh" ;;
    codex-slice)                 echo "codex-slice-review.sh" ;;
    codex-slice-verify)          echo "codex-slice-verify.sh" ;;
    claude-phase-review)         echo "claude-phase-review.sh" ;;
    orchestrator-gate-d-signoff) echo "gate-d-signoff.sh" ;;
    *)                           echo "" ;;
  esac
}

# Echo "ROLE KIND ID" for the project in $PWD ("error - -" / "none - -" at the edges).
next_action_raw() {
  [ -f TASKS.md ] || { echo "error - -"; return 0; }
  local out
  out=$( set +e; . "$LIB" >/dev/null 2>&1; factory_next_action TASKS.md 2>/dev/null ) || true
  [ -n "$out" ] || out="none - -"
  echo "$out"
}

# Human-facing: print the next command to run.
cmd_next() {
  local action role kind id adapter
  action=$(next_action_raw); read -r role kind id <<<"$action"
  case "$role" in
    error) say "Next: no TASKS.md here — not a scaffolded project (run /design first)."; return 1 ;;
    none)  say "Next: nothing pending. If every phase review is approved, run gate-d-signoff.sh; otherwise the project is done."; return 0 ;;
  esac
  adapter=$(adapter_for "$role" "$kind")
  [ -n "$adapter" ] || { say "Next: (unrecognized action: role=$role kind=$kind)"; return 1; }
  if [ -n "${id:-}" ] && [ "$id" != "-" ]; then say "Next: $adapter $id"; else say "Next: $adapter"; fi
}

# Run the resolved next adapter.
run_next() {
  local action role kind id adapter
  action=$(next_action_raw); read -r role kind id <<<"$action"
  case "$role" in error|none) cmd_next; return 0 ;; esac
  adapter=$(adapter_for "$role" "$kind")
  [ -n "$adapter" ] || { say "Unrecognized action: role=$role kind=$kind"; return 1; }
  if [ -n "${id:-}" ] && [ "$id" != "-" ]; then
    say ">> $adapter $id"; "$ORCH_DIR/$adapter" "$id"
  else
    say ">> $adapter"; "$ORCH_DIR/$adapter"
  fi
}

cmd_status() {
  hr
  say "Project: $(basename "$PWD")"
  [ -f .factory-version ] && sed 's/^/  /' .factory-version 2>/dev/null || true
  if [ -f TASKS.md ]; then
    local total
    total=$(grep -cE '^### [0-9]+\.[0-9]+' TASKS.md 2>/dev/null || echo 0)
    say "  slices defined: $total"
  fi
  cmd_next || true
  if [ -f ESCALATIONS.md ] && sed -n '/^## Open/,/^## Resolved/p' ESCALATIONS.md | grep -qE '^### ESC-'; then
    say "  ** open escalations present — see ESCALATIONS.md **"
  fi
  hr
}

apply_settings() {
  export RUN_PHASE_NO_PUSH="$SETTING_NO_PUSH"
  if [ -n "$SETTING_CODEX_SANDBOX" ]; then
    export RUN_PHASE_CODEX_APPROVAL_FLAG="$SETTING_CODEX_SANDBOX"
  else
    unset RUN_PHASE_CODEX_APPROVAL_FLAG 2>/dev/null || true
  fi
}

menu_settings() {
  while true; do
    say ""
    say "Settings (apply to steps launched from this menu):"
    say "  1) RUN_PHASE_NO_PUSH = $SETTING_NO_PUSH   (1 = commit locally, skip git push)"
    say "  2) Codex sandbox flag = ${SETTING_CODEX_SANDBOX:-<unset>}"
    say "  0) Back"
    read -rp "> " s || return 0
    case "$s" in
      1) if [ "$SETTING_NO_PUSH" = "1" ]; then SETTING_NO_PUSH=0; else SETTING_NO_PUSH=1; fi; apply_settings ;;
      2) read -rp "Codex sandbox flag (e.g. --sandbox danger-full-access; blank to clear): " SETTING_CODEX_SANDBOX || true; apply_settings ;;
      0) return 0 ;;
      *) say "?" ;;
    esac
  done
}

new_project() {
  local name blueprint goal users
  read -rp "Project name: " name || return 0
  read -rp "Blueprint (static-web-app, marketing-site, full-stack-web-app, ...): " blueprint || return 0
  read -rp "One-line goal: " goal || return 0
  read -rp "Primary users: " users || return 0
  [ -n "$name" ] || { say "name is required."; return 0; }
  "$SCRIPT_DIR/scaffold-new-project.sh" --name "$name" --blueprint "$blueprint" --goal "$goal" --users "$users"
  say ""
  say "Scaffolded. Open the new project in Claude for /intake, or use 'Open a project' here."
}

menu_project() {
  apply_settings
  while true; do
    cmd_status
    local push_state
    if [ "$SETTING_NO_PUSH" = "1" ]; then push_state="OFF (local only)"; else push_state="ON"; fi
    say "Build menu  [push: $push_state]"
    say "  1) Refresh status"
    say "  2) Run next step"
    say "  3) Autopilot (orchestrate.sh, until it needs you)"
    say "  4) Validate project"
    say "  5) View open escalations"
    say "  6) Settings (push / Codex sandbox)"
    say "  7) Open a Claude session"
    say "  0) Quit"
    read -rp "> " choice || return 0
    case "$choice" in
      1) : ;;
      2) run_next || say "(step exited non-zero — see the log above)" ;;
      3) "$ORCH_DIR/orchestrate.sh" || say "(orchestrator halted — read ESCALATIONS.md)" ;;
      4) "$SCRIPT_DIR/validate-project.sh" . || true ;;
      5) if [ -f ESCALATIONS.md ]; then sed -n '/^## Open/,/^## Resolved/p' ESCALATIONS.md; else say "no ESCALATIONS.md"; fi ;;
      6) menu_settings ;;
      7) if command -v claude >/dev/null 2>&1; then claude || true; else say "claude not on PATH (see check-cli-tools.sh)"; fi ;;
      0) return 0 ;;
      *) say "?" ;;
    esac
  done
}

menu_factory() {
  while true; do
    say ""
    hr; say "AI App Factory"; say "  $FACTORY_ROOT"; hr
    say "  1) Factory status"
    say "  2) Check CLI tools"
    say "  3) New project (scaffold)"
    say "  4) Open a project (build menu)"
    say "  0) Quit"
    read -rp "> " choice || exit 0
    case "$choice" in
      1) "$SCRIPT_DIR/factory-status.sh" || true ;;
      2) "$SCRIPT_DIR/check-cli-tools.sh" || true ;;
      3) new_project ;;
      4) read -rp "Project path: " p || true
         if [ -n "${p:-}" ] && [ -d "$p" ]; then ( cd "$p" && menu_project ); else say "not a directory: ${p:-}"; fi ;;
      0) exit 0 ;;
      *) say "?" ;;
    esac
  done
}

# --- argument parsing -----------------------------------------------------

case "${1:-}" in
  -h|--help) sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  --next)    cmd_next || exit 1; exit 0 ;;
  --status)  cmd_status; exit 0 ;;
  "")        ;;
  *)         say "unknown argument: $1 (try --help)"; exit 1 ;;
esac

# --- context dispatch -----------------------------------------------------

if [ -f "$PWD/TASKS.md" ] && [ -f "$PWD/.factory-version" ]; then
  menu_project
elif { [ -f "$PWD/MANIFEST.md" ] && [ -d "$PWD/templates/project-skeleton" ]; } || [ "$PWD" = "$FACTORY_ROOT" ]; then
  menu_factory
else
  say "Not in a factory repo or a scaffolded project."
  say "  cd into the factory (kickoff menu) or a project with TASKS.md (build menu),"
  say "  or run: factory.sh --help"
  exit 1
fi
