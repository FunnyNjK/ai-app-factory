#!/usr/bin/env bash
# scripts/factory.sh — context-aware interactive launcher for the AI App Factory.
#
# Run it with no arguments:
#   - inside the factory repo            -> kickoff menu (status, scaffold, open a project)
#   - inside a scaffolded project folder -> build menu (status, next step, autopilot, settings)
#
# Non-interactive (scriptable, testable):
#   factory.sh --next [dir]    print the next command to run (project DIR, else $PWD)
#   factory.sh --status [dir]  print current project status (next action + escalations)
#   factory.sh -h|--help       show this help
#
# This is a thin launcher: all real work stays in the existing scripts and in
# the claude/codex/agent CLIs. See docs/adr/0012-interactive-factory-tui.md.

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
FACTORY_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
ORCH_DIR="$SCRIPT_DIR/orchestrator"
LIB="$ORCH_DIR/lib.sh"

# Source the shared library for the tool-registry and role-config helpers
# (ADR-0013). lib.sh only defines functions and constants, so this is safe under
# `set -euo pipefail`. Guarded so the launcher degrades gracefully if moved.
if [ -f "$LIB" ]; then
  # shellcheck source=orchestrator/lib.sh
  . "$LIB"
fi

# The agent CLIs the factory can drive, in display order (ADR-0013).
FACTORY_TOOLS="claude gemini cursor codex"

# Pool of suggested agent names, offered as Enter-to-accept defaults in the role
# wizard (distinct per project run).
FACTORY_NAME_POOL="Atlas Nova Orion Sage Echo Iris Juno Vega Cosmo Pixel Forge Quill Beacon Pioneer Maverick Cipher Halcyon Onyx Ember Flux Zenith Tycho Lyra Aria Indigo Wren Dash Bolt Specter Tess"

# Most recently scaffolded project this session (pre-fills "Open a project").
LAST_PROJECT=""

# Session settings (inherit from the environment, then let the menu toggle them).
SETTING_NO_PUSH="${RUN_PHASE_NO_PUSH:-0}"
SETTING_CODEX_SANDBOX="${RUN_PHASE_CODEX_APPROVAL_FLAG:-}"

say() { printf '%s\n' "$*"; }
hr()  { printf -- '------------------------------------------------------------\n'; }

# detect_tools_report — print which of the four agent CLIs are on PATH (ADR-0013).
detect_tools_report() {
  say "Agent CLIs the factory can drive:"
  local t bin
  for t in $FACTORY_TOOLS; do
    bin=$(factory_tool_binary "$t")
    if factory_tool_detect "$t"; then
      say "  [found]    $(factory_tool_label "$t")  ($bin -> $(command -v "$bin"))"
    else
      say "  [missing]  $(factory_tool_label "$t")  ($bin not on PATH)"
    fi
  done
}

# show_roles — print the five role -> name [tool] mappings for a project config.
# Arg: $1 path to .factory-roles.json (default ./.factory-roles.json).
show_roles() {
  local cfg="${1:-.factory-roles.json}"
  local spec key label
  say "  roles (.factory-roles.json):"
  for spec in "architect:Architect" "developer:Developer" "tester:Tester" "security:Security" "code_review:Code Review"; do
    IFS=':' read -r key label <<<"$spec"
    say "    $(printf '%-12s' "$label") $(factory_role_name "$key" "$cfg")  [$(factory_role_tool "$key" "$cfg")]"
  done
}

# _random_names <count> — echo <count> distinct random names from the pool,
# space-separated. Used to pre-fill the role-name prompts.
_random_names() {
  local count="$1"
  local pool=()
  # shellcheck disable=SC2206
  pool=($FACTORY_NAME_POOL)
  local out=() idx
  while [ "${#out[@]}" -lt "$count" ] && [ "${#pool[@]}" -gt 0 ]; do
    idx=$(( RANDOM % ${#pool[@]} ))
    out+=("${pool[$idx]}")
    pool=("${pool[@]:0:$idx}" "${pool[@]:$((idx + 1))}")
  done
  printf '%s\n' "${out[*]}"
}

# Role wizard state, filled by _roles_collect and consumed by _roles_write.
ROLE_KEYS=()
ROLE_TOOLS=()
ROLE_NAMES=()

# _roles_collect [cfg] — interactive wizard filling ROLE_KEYS/ROLE_TOOLS/
# ROLE_NAMES for the five roles. If [cfg] is a readable .factory-roles.json its
# values seed the defaults; otherwise a distinct random name is suggested per
# role (press Enter to accept). Reads from stdin (works in the menu loop).
_roles_collect() {
  local cfg="${1:-}"
  ROLE_KEYS=(); ROLE_TOOLS=(); ROLE_NAMES=()
  hr
  detect_tools_report
  hr
  say "Assign a tool and a name to each of the five roles for this app."
  say "Tools: claude / gemini / cursor / codex. Press Enter to accept the default shown."
  say ""
  local sugg=()
  # shellcheck disable=SC2207
  sugg=($(_random_names 5))
  local i=0 spec key label def cur_tool cur_name pick name
  for spec in "architect:Architect:claude" "developer:Developer:cursor" "tester:Tester:codex" "security:Security:codex" "code_review:Code Review:claude"; do
    IFS=':' read -r key label def <<<"$spec"
    cur_tool="$def"
    cur_name="${sugg[$i]:-$label}"
    if [ -n "$cfg" ] && [ -f "$cfg" ]; then
      cur_tool=$(factory_role_tool "$key" "$cfg")
      cur_name=$(factory_role_name "$key" "$cfg")
    fi
    read -rp "  $label — tool [$cur_tool]: " pick || pick=""
    pick="${pick:-$cur_tool}"
    if ! factory_tool_is_supported "$pick"; then
      say "    '$pick' is not a supported tool (claude/gemini/cursor/codex); keeping $cur_tool."
      pick="$cur_tool"
    fi
    factory_tool_detect "$pick" || say "    note: $pick is not on PATH yet — install it before this role runs."
    read -rp "  $label — name [$cur_name]: " name || name=""
    name="${name:-$cur_name}"
    ROLE_KEYS+=("$key"); ROLE_TOOLS+=("$pick"); ROLE_NAMES+=("$name")
    i=$((i + 1))
    say ""
  done
}

# _roles_write <cfg-path> — write the collected ROLE_* arrays to a config file.
_roles_write() {
  local cfg="$1" i
  {
    for i in "${!ROLE_KEYS[@]}"; do
      printf '%s\t%s\t%s\n' "${ROLE_KEYS[$i]}" "${ROLE_TOOLS[$i]}" "${ROLE_NAMES[$i]}"
    done
  } | python3 -c '
import json, sys
roles = {}
for line in sys.stdin:
    line = line.rstrip("\n")
    if not line:
        continue
    key, tool, name = line.split("\t")
    roles[key] = {"tool": tool, "name": name}
sys.stdout.write(json.dumps({"roles": roles}, indent=2) + "\n")
' > "$cfg.tmp" && mv "$cfg.tmp" "$cfg"
}

# configure_roles [dir] — collect + write .factory-roles.json for an existing
# project (build-menu option). Seeds defaults from the current config.
configure_roles() {
  local target="${1:-.}"
  local cfg="$target/.factory-roles.json"
  say ""
  _roles_collect "$cfg"
  _roles_write "$cfg"
  say "Wrote $cfg:"
  show_roles "$cfg"
  hr
}

# pick_blueprint — list every blueprint and read a choice (number or name) from
# stdin into the global PICKED_BLUEPRINT. Defaults to static-web-app.
PICKED_BLUEPRINT=""
pick_blueprint() {
  PICKED_BLUEPRINT=""
  local dir="$FACTORY_ROOT/blueprints" default_bp="static-web-app"
  local bps=() f b
  for f in "$dir"/*.md; do
    [ -f "$f" ] || continue
    bps+=("$(basename "$f" .md)")
  done
  if [ "${#bps[@]}" -eq 0 ]; then
    read -rp "Blueprint: " PICKED_BLUEPRINT || PICKED_BLUEPRINT=""
    [ -n "$PICKED_BLUEPRINT" ] || PICKED_BLUEPRINT="$default_bp"
    return 0
  fi
  say "Blueprints:"
  local i=1
  for b in "${bps[@]}"; do say "  $i) $b"; i=$((i + 1)); done
  local choice
  read -rp "Choose a blueprint (number or name) [$default_bp]: " choice || choice=""
  choice="${choice:-$default_bp}"
  if printf '%s' "$choice" | grep -qE '^[0-9]+$'; then
    local idx=$((choice - 1))
    if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#bps[@]}" ]; then
      PICKED_BLUEPRINT="${bps[$idx]}"
    else
      say "  out of range; using $default_bp."; PICKED_BLUEPRINT="$default_bp"
    fi
  else
    local ok=0
    for b in "${bps[@]}"; do [ "$b" = "$choice" ] && ok=1; done
    if [ "$ok" = "1" ]; then PICKED_BLUEPRINT="$choice"; else
      say "  '$choice' is not a known blueprint; using $default_bp."; PICKED_BLUEPRINT="$default_bp"
    fi
  fi
}

# default_project_path — echo a sensible default for "Open a project": the most
# recently scaffolded project this session, else the most-recently-modified
# sibling folder that carries a .factory-version stamp.
default_project_path() {
  if [ -n "${LAST_PROJECT:-}" ] && [ -d "$LAST_PROJECT" ]; then
    printf '%s\n' "$LAST_PROJECT"; return 0
  fi
  local parent d
  parent=$(cd -- "$FACTORY_ROOT/.." && pwd 2>/dev/null) || return 0
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    if [ -f "${d%/}/.factory-version" ]; then printf '%s\n' "${d%/}"; return 0; fi
  done < <(ls -dt "$parent"/*/ 2>/dev/null)
}

# Map an orchestrator role+kind to its adapter script. Delegates to
# factory_adapter_for in lib.sh — the single source of truth for the dispatch
# map, shared with orchestrate.sh so the two cannot drift (ADR-0012 follow-up).
adapter_for() { factory_adapter_for "$1" "$2"; }

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
  show_roles
  cmd_next || true
  if [ -f ESCALATIONS.md ] && sed -n '/^## Open/,/^## Resolved/p' ESCALATIONS.md | grep -qE '^### ESC-'; then
    say "  ** open escalations present — see ESCALATIONS.md **"
  fi
  hr
}

# Per-project persisted settings file (gitignored). Holds the operator's push
# and Codex-sandbox choices so they survive across launcher sessions.
SETTINGS_FILE=".factory-settings"

# load_settings — read SETTING_* from ./.factory-settings if present. The file
# is the persisted per-project choice and wins over the environment defaults
# captured at launch. No-op when the file is absent (env/defaults stand).
load_settings() {
  [ -f "$SETTINGS_FILE" ] || return 0
  local key val
  while IFS='=' read -r key val; do
    case "$key" in
      RUN_PHASE_NO_PUSH)             SETTING_NO_PUSH="$val" ;;
      RUN_PHASE_CODEX_APPROVAL_FLAG) SETTING_CODEX_SANDBOX="$val" ;;
    esac
  done <"$SETTINGS_FILE"
  return 0
}

# save_settings — persist SETTING_* to ./.factory-settings (atomic write).
save_settings() {
  {
    printf 'RUN_PHASE_NO_PUSH=%s\n' "$SETTING_NO_PUSH"
    printf 'RUN_PHASE_CODEX_APPROVAL_FLAG=%s\n' "$SETTING_CODEX_SANDBOX"
  } >"$SETTINGS_FILE.tmp" && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
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
    say "Settings (saved to ./.factory-settings — persist across launcher sessions):"
    say "  1) RUN_PHASE_NO_PUSH = $SETTING_NO_PUSH   (1 = commit locally, skip git push)"
    say "  2) Codex sandbox flag = ${SETTING_CODEX_SANDBOX:-<unset>}"
    say "  0) Back"
    read -rp "> " s || return 0
    case "$s" in
      1) if [ "$SETTING_NO_PUSH" = "1" ]; then SETTING_NO_PUSH=0; else SETTING_NO_PUSH=1; fi; apply_settings; save_settings ;;
      2) read -rp "Codex sandbox flag (e.g. --sandbox danger-full-access; blank to clear): " SETTING_CODEX_SANDBOX || true; apply_settings; save_settings ;;
      0) return 0 ;;
      *) say "?" ;;
    esac
  done
}

# _select <title> <prompt> <key1> <label1> [<key2> <label2> ...]
# Single-choice menu. Echoes the chosen KEY on stdout and renders the menu UI on
# stderr, so a caller can capture the key with $(...). Uses fzf, then whiptail,
# when present (a boxed/fuzzy picker), and otherwise falls back to a numbered
# `read` prompt that needs no extra runtime (ADR-0012). Returns nonzero on cancel.
_select() {
  local title="$1" prompt="$2"; shift 2
  local keys=() labels=()
  while [ "$#" -ge 2 ]; do keys+=("$1"); labels+=("$2"); shift 2; done
  local i sel

  if command -v fzf >/dev/null 2>&1; then
    local lines=""
    for i in "${!keys[@]}"; do lines+="${keys[$i]}) ${labels[$i]}"$'\n'; done
    sel=$(printf '%s' "$lines" | fzf --height=40% --reverse --header="$title" --prompt="$prompt") || return 1
    printf '%s\n' "${sel%%)*}"
    return 0
  fi

  if command -v whiptail >/dev/null 2>&1; then
    local args=()
    for i in "${!keys[@]}"; do args+=("${keys[$i]}" "${labels[$i]}"); done
    sel=$(whiptail --title "$title" --menu "$prompt" 20 76 "${#keys[@]}" "${args[@]}" 3>&1 1>&2 2>&3) || return 1
    printf '%s\n' "$sel"
    return 0
  fi

  # Plain fallback — menu UI to stderr, chosen key to stdout.
  {
    say "$title"
    for i in "${!keys[@]}"; do say "  ${keys[$i]}) ${labels[$i]}"; done
  } 1>&2
  read -rp "$prompt" sel || return 1
  printf '%s\n' "$sel"
}

# run_autopilot — preflight, then launch the autonomous orchestrator. Shows the
# resolved next action, the push state, and any open escalations, and requires an
# explicit confirm because autopilot runs unattended until it finishes or needs a
# human.
run_autopilot() {
  hr
  say "Autopilot runs orchestrate.sh until the project is done or it needs you."
  cmd_next || true
  if [ "$SETTING_NO_PUSH" = "1" ]; then
    say "  push: OFF (commits stay local)"
  else
    say "  push: ON — commits will be pushed to the remote"
  fi
  if [ -f ESCALATIONS.md ] && sed -n '/^## Open/,/^## Resolved/p' ESCALATIONS.md | grep -qE '^### ESC-'; then
    say "  ** open escalations present — resolve them first (see ESCALATIONS.md) **"
  fi
  local ans
  read -rp "Start autopilot? [y/N]: " ans || ans=""
  case "$ans" in
    y|Y|yes|Yes) "$ORCH_DIR/orchestrate.sh" || say "(orchestrator halted — read ESCALATIONS.md)" ;;
    *)           say "Autopilot cancelled." ;;
  esac
}

# open_claude_session — launch claude, optionally primed with the slash command
# that fits the project's stage (/intake before PROJECT.md exists, else
# /next-slice). A plain session is one keystroke away.
open_claude_session() {
  if ! command -v claude >/dev/null 2>&1; then
    say "claude not on PATH (see check-cli-tools.sh)."
    return 0
  fi
  local cmd
  if [ -f PROJECT.md ]; then cmd="/next-slice"; else cmd="/intake"; fi
  local ans
  read -rp "Launch claude primed with '$cmd'? [Y/n] (n = plain session): " ans || ans=""
  case "$ans" in
    n|N|no|No) claude || true ;;
    *)         claude "$cmd" || true ;;
  esac
}

new_project() {
  # Step 1 — configure the delivery team FIRST (random suggested names; Enter to
  # accept). Collected into ROLE_* arrays now, written into the project below.
  say ""
  say "=== Step 1 of 2: configure the delivery team ==="
  _roles_collect ""

  # Step 2 — the project itself.
  say "=== Step 2 of 2: about the project ==="
  local name goal users
  read -rp "Project name (kebab-case): " name || return 0
  [ -n "$name" ] || { say "name is required."; return 0; }
  pick_blueprint
  local blueprint="$PICKED_BLUEPRINT"
  read -rp "One-line goal: " goal || goal=""
  read -rp "Primary users: " users || users=""

  local parent target
  parent=$(cd -- "$FACTORY_ROOT/.." && pwd)
  target="$parent/$name"

  if ! "$SCRIPT_DIR/scaffold-new-project.sh" --name "$name" --blueprint "$blueprint" --goal "$goal" --users "$users"; then
    say "Scaffold failed."
    return 0
  fi
  [ -d "$target" ] || { say "Scaffold reported success but $target is missing."; return 0; }

  # Write the roles chosen in Step 1 into the new project (overrides the seeded default).
  _roles_write "$target/.factory-roles.json"
  say ""
  say "Delivery team for $name:"
  show_roles "$target/.factory-roles.json"

  # Offer to make the initial commit so the orchestrator does not refuse a dirty tree.
  # NOTE: assumes git user.name/user.email are configured globally (the common
  # case). Tracked follow-up: detect a missing git identity and prompt/configure
  # it rather than letting the commit fail.
  if [ -d "$target/.git" ]; then
    local ans
    say ""
    read -rp "Stage + commit the initial scaffold now, so the first slice runs on a clean tree? [Y/n]: " ans || ans=""
    case "$ans" in
      n|N|no|No)
        say "Skipped. NOTE: run 'git -C \"$target\" commit' before the orchestrator, or it will refuse a dirty tree." ;;
      *)
        if ( cd "$target" && git add -A && git commit -q -m "chore: initial scaffold ($blueprint)" ); then
          say "Committed the initial scaffold — tree is clean."
        else
          say "Commit failed (is git user.name/user.email configured?). Commit manually in $target before running the orchestrator."
        fi ;;
    esac
  fi

  LAST_PROJECT="$target"
  say ""
  say "Scaffolded $target."
  say "Open it in Claude for /intake, or pick 'Open a project' here (the path is pre-filled)."
}

menu_project() {
  load_settings
  apply_settings
  local choice push_state
  while true; do
    cmd_status
    if [ "$SETTING_NO_PUSH" = "1" ]; then push_state="OFF (local only)"; else push_state="ON"; fi
    choice=$(_select "Build menu  [push: $push_state]" "> " \
      1 "Refresh status" \
      2 "Run next step" \
      3 "Autopilot (orchestrate.sh, until it needs you)" \
      4 "Validate project" \
      5 "Check factory drift (refresh-project.sh, read-only)" \
      6 "View open escalations" \
      7 "Settings (push / Codex sandbox)" \
      8 "Configure roles (tool + name per role)" \
      9 "Open a Claude session" \
      0 "Quit") || return 0
    case "$choice" in
      1) : ;;
      2) run_next || say "(step exited non-zero — see the log above)" ;;
      3) run_autopilot ;;
      4) "$SCRIPT_DIR/validate-project.sh" . || true ;;
      5) "$SCRIPT_DIR/refresh-project.sh" . || true ;;
      6) if [ -f ESCALATIONS.md ]; then sed -n '/^## Open/,/^## Resolved/p' ESCALATIONS.md; else say "no ESCALATIONS.md"; fi ;;
      7) menu_settings ;;
      8) configure_roles . ;;
      9) open_claude_session ;;
      0) return 0 ;;
      *) say "?" ;;
    esac
  done
}

menu_factory() {
  # Report which agent CLIs were found once, on entry (ADR-0013).
  say ""; hr; say "AI App Factory"; say "  $FACTORY_ROOT"; hr
  detect_tools_report
  local choice defp p
  while true; do
    say ""
    choice=$(_select "AI App Factory" "> " \
      1 "Factory status" \
      2 "Detect agent CLIs (claude / gemini / cursor / codex)" \
      3 "Check CLI tools (install help)" \
      4 "New project (scaffold + configure roles)" \
      5 "Open a project (build menu)" \
      0 "Quit") || exit 0
    case "$choice" in
      1) "$SCRIPT_DIR/factory-status.sh" || true ;;
      2) hr; detect_tools_report; hr ;;
      3) "$SCRIPT_DIR/check-cli-tools.sh" || true ;;
      4) new_project ;;
      5) defp=$(default_project_path)
         read -rp "Project path [${defp}]: " p || true
         p="${p:-$defp}"
         if [ -n "${p:-}" ] && [ -d "$p" ]; then ( cd "$p" && menu_project ); else say "not a directory: ${p:-}"; fi ;;
      0) exit 0 ;;
      *) say "?" ;;
    esac
  done
}

# When sourced (e.g. by scripts/test/*.test.sh) stop here: only the function
# definitions above are wanted, not the interactive menu / CLI below.
[ "${BASH_SOURCE[0]}" = "$0" ] || return 0

# --- argument parsing -----------------------------------------------------

case "${1:-}" in
  -h|--help) sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  --next)
    if [ -n "${2:-}" ]; then [ -d "$2" ] || { say "not a directory: $2"; exit 1; }; cd "$2"; fi
    cmd_next || exit 1; exit 0 ;;
  --status)
    if [ -n "${2:-}" ]; then [ -d "$2" ] || { say "not a directory: $2"; exit 1; }; cd "$2"; fi
    cmd_status; exit 0 ;;
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
