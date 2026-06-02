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
# The interactive UI renders INLINE in the terminal (Claude Code look and feel:
# accent ❯ pointer, arrow-key pickers, rounded banner). Action output always
# stays visible in the scrollback — no fullscreen dialogs. Non-interactive
# callers (pipes, CI, tests) get plain numbered prompts.
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

# --- UI helpers (Claude Code look and feel — ADR-0012 amendment) -----------
#
# Everything renders INLINE in the terminal: no fullscreen dialogs, no external
# picker. Output from every action stays in the scrollback with the menu drawn
# below it, so nothing is ever hidden behind a dialog. Styling follows Claude
# Code: a rounded banner box, the ✻ marker, an accent-orange ❯ pointer, and dim
# secondary text. Colors engage only on capable interactive terminals.

# ui_init — set the C_* style variables. Colors require: stderr is a TTY, TERM
# is not dumb, and NO_COLOR is unset (https://no-color.org). Safe when sourced
# by tests: everything degrades to empty strings.
ui_init() {
  UI_COLOR=0
  if [ -t 2 ] && [ "${TERM:-dumb}" != "dumb" ] && [ -z "${NO_COLOR:-}" ]; then
    UI_COLOR=1
  fi
  if [ "$UI_COLOR" = "1" ]; then
    C_ACCENT=$'\033[38;5;173m'  # Claude's terracotta orange (#D97757 ~ xterm 173)
    C_DIM=$'\033[2m'
    C_BOLD=$'\033[1m'
    C_RESET=$'\033[0m'
  else
    C_ACCENT='' C_DIM='' C_BOLD='' C_RESET=''
  fi
}
ui_init

# ui_banner <title> [subtitle ...] — rounded box in the Claude Code welcome
# style, rendered to stderr. Width adapts to the longest line.
ui_banner() {
  local title="$1"; shift
  local w=$(( ${#title} + 4 )) line
  for line in "$@"; do
    [ $(( ${#line} + 4 )) -gt "$w" ] && w=$(( ${#line} + 4 ))
  done
  {
    printf '%s╭' "$C_ACCENT"
    printf '─%.0s' $(seq 1 "$w")
    printf '╮%s\n' "$C_RESET"
    printf '%s│%s %s✻%s %s%s%*s%s│%s\n' \
      "$C_ACCENT" "$C_RESET" "$C_ACCENT" "$C_RESET" "$C_BOLD" "$title" \
      $(( w - ${#title} - 3 )) "" "$C_ACCENT" "$C_RESET"
    for line in "$@"; do
      printf '%s│%s   %s%s%s%*s%s│%s\n' \
        "$C_ACCENT" "$C_RESET" "$C_DIM" "$line" "$C_RESET" \
        $(( w - ${#line} - 3 )) "" "$C_ACCENT" "$C_RESET"
    done
    printf '%s╰' "$C_ACCENT"
    printf '─%.0s' $(seq 1 "$w")
    printf '╯%s\n' "$C_RESET"
  } 1>&2
}

# ui_pause — hold the screen so action output stays readable before the menu
# redraws. Interactive terminals only; a no-op for tests, pipes, and CI.
ui_pause() {
  { [ -t 0 ] && [ -t 2 ]; } || return 0
  local _x
  printf '\n%s  press Enter to return to the menu …%s ' "$C_DIM" "$C_RESET" 1>&2
  IFS= read -r _x || true
}

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
  say "${C_BOLD}Project:${C_RESET} $(basename "$PWD")"
  [ -f .factory-version ] && sed 's/^/  /' .factory-version 2>/dev/null || true
  if [ -f TASKS.md ]; then
    local total
    total=$(grep -cE '^### [0-9]+\.[0-9]+' TASKS.md 2>/dev/null || echo 0)
    say "  slices defined: $total"
  fi
  show_roles
  cmd_next || true
  if [ -f ESCALATIONS.md ] && sed -n '/^## Open/,/^## Resolved/p' ESCALATIONS.md | grep -qE '^### ESC-'; then
    say "  ${C_ACCENT}** open escalations present — see ESCALATIONS.md **${C_RESET}"
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
# stderr, so a caller can capture the key with $(...). Returns nonzero on cancel.
#
# Interactive terminals get an inline, Claude Code-style picker: an accent ❯
# pointer, ↑/↓ (or j/k) to move, a digit to jump straight to that option, Enter
# to choose, q or Esc to cancel. The picker draws BELOW the current scrollback
# (never over it — the whiptail fullscreen dialog hid action output, which is
# why it was removed; see the ADR-0012 amendment) and collapses to a single
# "❯ <label>" line once chosen.
#
# Non-interactive callers (tests, pipes, CI, dumb terminals) get the
# dependency-free numbered fallback: title + labels to stderr, one line read
# from stdin, chosen key to stdout.
_select() {
  local title="$1" prompt="$2"; shift 2
  local keys=() labels=()
  while [ "$#" -ge 2 ]; do keys+=("$1"); labels+=("$2"); shift 2; done
  local i sel

  # Fallback path: anything non-interactive.
  if [ ! -t 0 ] || [ ! -t 2 ] || [ "${TERM:-dumb}" = "dumb" ]; then
    {
      say "$title"
      for i in "${!keys[@]}"; do say "  ${keys[$i]}) ${labels[$i]}"; done
    } 1>&2
    read -rp "$prompt" sel || return 1
    printf '%s\n' "$sel"
    return 0
  fi

  # Interactive inline picker.
  local n=${#keys[@]} cur=0 ch rest picked=-1

  # The picker hides the terminal cursor while live; make sure it comes back
  # even on Ctrl-C. (Menu callers run _select via $(...), so this trap lives in
  # that subshell; registering it at script level would also be harmless.)
  trap 'printf "\033[?25h" 1>&2' EXIT INT TERM

  # Draw the option list (pointer on $cur). Every line is fully redrawn, so a
  # repaint only needs to move the cursor back up $n lines.
  _select_draw() {
    local j
    for (( j = 0; j < n; j++ )); do
      printf '\033[2K' 1>&2  # clear the line before redrawing it
      if [ "$j" -eq "$cur" ]; then
        printf ' %s❯ %s. %s%s\n' "$C_ACCENT" "${keys[$j]}" "${labels[$j]}" "$C_RESET" 1>&2
      else
        printf '   %s%s. %s%s\n' "$C_DIM" "${keys[$j]}" "${labels[$j]}" "$C_RESET" 1>&2
      fi
    done
  }

  printf '\033[?25l' 1>&2  # hide cursor while the picker is live
  printf '\n %s%s%s  %s↑/↓ move · Enter select · q cancel%s\n' \
    "$C_BOLD" "$title" "$C_RESET" "$C_DIM" "$C_RESET" 1>&2
  _select_draw

  while true; do
    IFS= read -rsn1 ch || { picked=-1; break; }
    if [ "$ch" = $'\033' ]; then
      # Arrow keys arrive as ESC [ A/B; a bare Esc (timeout) cancels.
      rest=""
      IFS= read -rsn2 -t 1 rest || rest=""
      case "$rest" in
        '[A') ch="UP" ;;
        '[B') ch="DOWN" ;;
        *)    ch="CANCEL" ;;
      esac
    fi
    case "$ch" in
      UP|k)    cur=$(( (cur - 1 + n) % n )) ;;
      DOWN|j)  cur=$(( (cur + 1) % n )) ;;
      "")      picked=$cur; break ;;            # Enter
      q|Q|CANCEL) picked=-1; break ;;
      *)
        # A digit (or any key string) that matches an option key jumps + selects.
        for i in "${!keys[@]}"; do
          if [ "${keys[$i]}" = "$ch" ]; then cur=$i; picked=$cur; break; fi
        done
        [ "$picked" -ge 0 ] && break ;;
    esac
    printf '\033[%dA' "$n" 1>&2
    _select_draw
  done

  # Collapse the picker (the title/hint line + n option lines) and restore the
  # cursor. The blank spacer line above the title is left in place.
  printf '\033[%dA\033[J\033[?25h' $(( n + 1 )) 1>&2
  if [ "$picked" -lt 0 ]; then
    printf ' %s❯ cancelled%s\n' "$C_DIM" "$C_RESET" 1>&2
    return 1
  fi
  printf ' %s❯%s %s\n' "$C_ACCENT" "$C_RESET" "${labels[$picked]}" 1>&2
  printf '%s\n' "${keys[$picked]}"
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
  # Full status once on entry. Inside the loop the menu redraws compactly so
  # action output above it stays in view (ADR-0012 amendment).
  ui_banner "$(basename "$PWD")" "factory project · $(basename "$FACTORY_ROOT")"
  cmd_status
  while true; do
    if [ "$SETTING_NO_PUSH" = "1" ]; then push_state="push OFF (local only)"; else push_state="push ON"; fi
    choice=$(_select "$(basename "$PWD")  ·  $push_state" "> " \
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
      1) cmd_status ;;
      2) run_next || say "(step exited non-zero — see the log above)"; ui_pause ;;
      3) run_autopilot; ui_pause ;;
      4) "$SCRIPT_DIR/validate-project.sh" . || true; ui_pause ;;
      5) "$SCRIPT_DIR/refresh-project.sh" . || true; ui_pause ;;
      6) if [ -f ESCALATIONS.md ]; then sed -n '/^## Open/,/^## Resolved/p' ESCALATIONS.md; else say "no ESCALATIONS.md"; fi; ui_pause ;;
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
  ui_banner "AI App Factory" "$FACTORY_ROOT"
  detect_tools_report
  local choice defp p
  while true; do
    choice=$(_select "AI App Factory" "> " \
      1 "Factory status" \
      2 "Detect agent CLIs (claude / gemini / cursor / codex)" \
      3 "Check CLI tools (install help)" \
      4 "New project (scaffold + configure roles)" \
      5 "Open a project (build menu)" \
      0 "Quit") || exit 0
    case "$choice" in
      1) "$SCRIPT_DIR/factory-status.sh" || true; ui_pause ;;
      2) hr; detect_tools_report; hr; ui_pause ;;
      3) "$SCRIPT_DIR/check-cli-tools.sh" || true; ui_pause ;;
      4) new_project; ui_pause ;;
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
