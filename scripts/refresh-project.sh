#!/usr/bin/env bash
# scripts/refresh-project.sh — read-only drift detector. Reports where a
# scaffolded project has fallen behind current factory conventions. It does
# NOT modify the project; the refresh-project skill (or a human) reconciles
# each item, preserving project-specific content.
#
# Drift is found via "smoking-gun" markers — the presence of a current factory
# convention in the project. Add a marker here whenever the factory introduces
# a convention that existing projects should pick up.
#
# Usage:
#   scripts/refresh-project.sh <project-path>
#
# Exit codes:
#   0   up to date with current factory conventions
#   1   drift found (informational)
#   2   bad usage

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
FACTORY_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
SKELETON="$FACTORY_ROOT/templates/project-skeleton"

PROJECT_PATH="${1:-}"
if [ -z "$PROJECT_PATH" ]; then
  printf 'usage: refresh-project.sh <project-path>\n' >&2
  exit 2
fi
if [ ! -d "$PROJECT_PATH" ]; then
  printf 'error: not a directory: %s\n' "$PROJECT_PATH" >&2
  exit 2
fi

DRIFT=0
drift() { printf 'DRIFT  %s\n' "$*"; DRIFT=$((DRIFT + 1)); }
ok() { printf 'ok     %s\n' "$*"; }

printf 'Refresh check: %s\n' "$PROJECT_PATH"
printf 'Against factory: %s\n' "$FACTORY_ROOT"
printf '====================\n'

# --- Marker: factory baseline stamp ---------------------------------------
if [ -f "$PROJECT_PATH/.factory-version" ]; then
  ok ".factory-version present ($(head -n 1 "$PROJECT_PATH/.factory-version"))"
else
  drift ".factory-version missing — stamp the factory baseline so future refreshes have a reference."
fi

# --- Marker: TASKS.md legends ---------------------------------------------
if [ -f "$PROJECT_PATH/TASKS.md" ]; then
  if grep -q '^## Status values' "$PROJECT_PATH/TASKS.md"; then
    ok "TASKS.md has the Status-values legend"
  else
    drift "TASKS.md is missing the '## Status values' legend."
  fi
  if grep -q '^## Owner values' "$PROJECT_PATH/TASKS.md"; then
    ok "TASKS.md has the Owner-values legend"
  else
    drift "TASKS.md is missing the '## Owner values' legend (added to the skeleton; copy it in below Status values)."
  fi
else
  drift "TASKS.md missing."
fi

# --- Marker: SIGNOFF.md (Gate D) -------------------------------------------
if [ -f "$PROJECT_PATH/SIGNOFF.md" ]; then
  ok "SIGNOFF.md present (Gate D six-party sign-off)"
else
  drift "SIGNOFF.md missing — copy templates/SIGNOFF.md (the Gate D sign-off artifact)."
fi

# --- Marker: .factory-roles.json (ADR-0013 five-role team) -----------------
if [ -f "$PROJECT_PATH/.factory-roles.json" ]; then
  ok ".factory-roles.json present (role→tool mapping)"
else
  drift ".factory-roles.json missing — copy templates/factory-roles.default.json to .factory-roles.json and customize the role→tool mapping (docs/adr/0013-configurable-roles-and-tools.md)."
fi

# --- Marker: per-phase security and code-review gates (ADR-0013) -----------
# A project scaffolded before ADR-0013 has '### Phase N review' entries but no
# '### Phase N security' / '### Phase N code-review' gates in TASKS.md.
if [ -f "$PROJECT_PATH/TASKS.md" ]; then
  if grep -qiE '^### Phase [0-9]+ review' "$PROJECT_PATH/TASKS.md"; then
    if grep -qiE '^### Phase [0-9]+ security' "$PROJECT_PATH/TASKS.md" \
      && grep -qiE '^### Phase [0-9]+ code-review' "$PROJECT_PATH/TASKS.md"; then
      ok "TASKS.md has the per-phase security and code-review gates"
    else
      drift "TASKS.md is missing the per-phase security and/or code-review gate entries — add a '### Phase N security' and '### Phase N code-review' section per phase (see templates/project-skeleton/TASKS.md and docs/adr/0013-configurable-roles-and-tools.md)."
    fi
  fi
fi

# --- Marker: the current .claude/commands set -----------------------------
# The factory skeleton is the source of truth for which commands a project
# should ship. Anything the skeleton has that the project lacks is drift.
if [ -d "$SKELETON/.claude/commands" ]; then
  for cmd in "$SKELETON/.claude/commands"/*.md; do
    [ -e "$cmd" ] || continue
    name=$(basename "$cmd")
    if [ -f "$PROJECT_PATH/.claude/commands/$name" ]; then
      ok ".claude/commands/$name present"
    else
      drift ".claude/commands/$name missing — the skeleton now ships it; copy it in."
    fi
  done
fi

printf '====================\n'
if [ "$DRIFT" -eq 0 ]; then
  printf 'Up to date with current factory conventions.\n'
  exit 0
fi
printf '%d drift item(s) found. Run the refresh-project skill to reconcile them\n' "$DRIFT"
printf '(it preserves project-specific content and writes a migration note).\n'
exit 1
