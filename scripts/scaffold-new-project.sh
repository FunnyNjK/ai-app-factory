#!/usr/bin/env bash
# scripts/scaffold-new-project.sh — create a new factory project folder.
#
# Copies templates/project-skeleton/ into a new sibling directory of the
# factory repo, customizes the placeholders, copies relevant starter
# templates, and (optionally) initializes git. Backs the
# spawn-new-project skill and the /new-project slash command.
#
# Usage:
#   scripts/scaffold-new-project.sh \
#     --name acme-marketing-site \
#     --blueprint marketing-site \
#     [--parent /abs/path/to/parent-dir] \
#     [--factory-path /abs/path/to/factory] \
#     [--goal "Marketing site for ACME with contact form"] \
#     [--users "Prospective customers and SEO traffic"] \
#     [--no-git]
#
# Defaults:
#   --parent        sibling of the factory repo (i.e. the factory's parent dir)
#   --factory-path  the directory that contains this script's repo root
#   --no-git        unset; git init runs by default. Pass --no-git to skip.
#
# Exit codes:
#   0   success
#   1   bad arguments or precondition failed
#   2   target directory already exists

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
FACTORY_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)

NAME=""
BLUEPRINT=""
PARENT=""
FACTORY_PATH="$FACTORY_ROOT"
GOAL=""
USERS=""
LAUNCH_DATE="none"
OPERATOR="product owner"
DO_GIT=1

usage() {
  sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)           NAME="$2"; shift 2 ;;
    --blueprint)      BLUEPRINT="$2"; shift 2 ;;
    --parent)         PARENT="$2"; shift 2 ;;
    --factory-path)   FACTORY_PATH="$2"; shift 2 ;;
    --goal)           GOAL="$2"; shift 2 ;;
    --users)          USERS="$2"; shift 2 ;;
    --launch-date)    LAUNCH_DATE="$2"; shift 2 ;;
    --operator)       OPERATOR="$2"; shift 2 ;;
    --no-git)         DO_GIT=0; shift ;;
    -h|--help)        usage; exit 0 ;;
    *) printf 'error: unknown argument: %s\n' "$1" >&2; usage >&2; exit 1 ;;
  esac
done

# --- Validate inputs ------------------------------------------------------

if [ -z "$NAME" ] || [ -z "$BLUEPRINT" ]; then
  printf 'error: --name and --blueprint are required.\n' >&2
  usage >&2
  exit 1
fi

if ! printf '%s' "$NAME" | grep -Eq '^[a-z][a-z0-9-]*[a-z0-9]$'; then
  printf 'error: --name must be kebab-case (lowercase, digits, hyphens; no leading/trailing hyphen): got %q\n' "$NAME" >&2
  exit 1
fi

BLUEPRINT_FILE="$FACTORY_PATH/blueprints/${BLUEPRINT}.md"
if [ ! -f "$BLUEPRINT_FILE" ]; then
  printf 'error: blueprint not found at %s\n' "$BLUEPRINT_FILE" >&2
  printf 'available blueprints:\n' >&2
  ls "$FACTORY_PATH/blueprints/" 2>/dev/null | sed 's/\.md$//; s/^/  - /' >&2 || true
  exit 1
fi

SKELETON_DIR="$FACTORY_PATH/templates/project-skeleton"
if [ ! -d "$SKELETON_DIR" ]; then
  printf 'error: skeleton not found at %s\n' "$SKELETON_DIR" >&2
  exit 1
fi

if [ -z "$PARENT" ]; then
  PARENT=$(cd -- "$FACTORY_PATH/.." && pwd)
fi

if [ ! -d "$PARENT" ]; then
  printf 'error: parent directory does not exist: %s\n' "$PARENT" >&2
  exit 1
fi

TARGET="$PARENT/$NAME"
if [ -e "$TARGET" ]; then
  printf 'error: target already exists: %s\n' "$TARGET" >&2
  exit 2
fi

# --- Copy skeleton --------------------------------------------------------

printf '==> Scaffolding %s\n' "$NAME"
printf '    Blueprint:    %s\n' "$BLUEPRINT"
printf '    Parent:       %s\n' "$PARENT"
printf '    Factory:      %s\n' "$FACTORY_PATH"
printf '    Target:       %s\n' "$TARGET"

mkdir -p "$TARGET"

# Copy the skeleton verbatim. cp -a preserves dotfiles (.gitignore, .claude/, .cursor/).
cp -a "$SKELETON_DIR/." "$TARGET/"

# Starter templates that every project gets.
for f in PROJECT.md ARCHITECTURE.md SECURITY.md .env.example RELEASE_CHECKLIST.md RUNBOOK.md SIGNOFF.md; do
  src="$FACTORY_PATH/templates/$f"
  dest="$TARGET/$f"
  if [ -f "$src" ] && [ ! -e "$dest" ]; then
    cp "$src" "$dest"
  fi
done

# Conditional templates by blueprint family.
case "$BLUEPRINT" in
  api-service|azure-functions|stripe-app|plaid-app|postmark-email|full-stack-web-app)
    cp "$FACTORY_PATH/templates/API_SPEC.md" "$TARGET/API_SPEC.md" 2>/dev/null || true
    ;;
esac

case "$BLUEPRINT" in
  stripe-app|plaid-app|full-stack-web-app|api-service|azure-functions)
    cp "$FACTORY_PATH/templates/THREAT_MODEL.md" "$TARGET/THREAT_MODEL.md" 2>/dev/null || true
    ;;
esac

# Cost estimate goes with any cloud-hosted blueprint.
case "$BLUEPRINT" in
  marketing-site|static-web-app|full-stack-web-app|api-service|azure-functions|stripe-app|plaid-app|postmark-email)
    cp "$FACTORY_PATH/templates/COST_ESTIMATE.md" "$TARGET/COST_ESTIMATE.md" 2>/dev/null || true
    ;;
esac

# Infra starter for anything that lands on Azure.
case "$BLUEPRINT" in
  marketing-site|static-web-app|full-stack-web-app|api-service|azure-functions|stripe-app|plaid-app)
    if [ -d "$FACTORY_PATH/templates/infra" ]; then
      cp -a "$FACTORY_PATH/templates/infra" "$TARGET/infra"
    fi
    ;;
esac

mkdir -p "$TARGET/docs/adr"

# --- Replace placeholders in the new project's files ----------------------

# Default values for placeholders we always know.
GOAL_FILLED="${GOAL:-<one-line-goal>}"
USERS_FILLED="${USERS:-<primary-users>}"

esc() {
  # Escape forward slashes, backslashes, ampersands for sed replacement.
  printf '%s' "$1" | sed -e 's/[\/&]/\\&/g'
}

NAME_E=$(esc "$NAME")
BLUEPRINT_E=$(esc "$BLUEPRINT")
FACTORY_PATH_E=$(esc "$FACTORY_PATH")
GOAL_E=$(esc "$GOAL_FILLED")
USERS_E=$(esc "$USERS_FILLED")
LAUNCH_E=$(esc "$LAUNCH_DATE")
OPERATOR_E=$(esc "$OPERATOR")

# Replace in every .md and .mdc file in the new project.
find "$TARGET" -type f \( -name '*.md' -o -name '*.mdc' \) -print0 |
while IFS= read -r -d '' file; do
  sed -i \
    -e "s/<project-name>/$NAME_E/g" \
    -e "s/<blueprint-name>/$BLUEPRINT_E/g" \
    -e "s/<blueprint>/$BLUEPRINT_E/g" \
    -e "s/<factory-path>/$FACTORY_PATH_E/g" \
    -e "s/<one-line-goal>/$GOAL_E/g" \
    -e "s/<primary-users>/$USERS_E/g" \
    -e "s/<date-or-none>/$LAUNCH_E/g" \
    -e "s/<who>/$OPERATOR_E/g" \
    "$file"
done

# --- Stamp the factory baseline -------------------------------------------

# Record which factory commit this project was scaffolded from, so a later
# scripts/refresh-project.sh run can detect and reconcile convention drift.
{
  printf 'factory_commit: %s\n' "$(git -C "$FACTORY_PATH" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  printf 'scaffolded: %s\n' "$(date -u +%Y-%m-%d)"
} > "$TARGET/.factory-version"

# --- Initialize git -------------------------------------------------------

if [ "$DO_GIT" = "1" ]; then
  (
    cd "$TARGET"
    git init -q
    git add .
    printf '==> git initialized; first commit is staged but NOT created (your call).\n'
  )
else
  printf '==> Skipped git init (--no-git).\n'
fi

# --- Done -----------------------------------------------------------------

cat <<EOF

✅ Scaffolded: $TARGET

Next steps:
  1. cd $TARGET
  2. Review CLAUDE.md, AGENTS.md, .cursor/rules/developer.mdc — confirm placeholders are filled.
  3. Run the intake slash command (/intake in Claude Code) to begin Project Intake Mode.
  4. After intake, run /design to produce the Architecture Package, then /handoff-cursor and /handoff-codex.
  5. When you have an architecture and TASKS.md is populated, the orchestrator can take over: $FACTORY_PATH/scripts/orchestrator/orchestrate.sh

To validate the project state at any time: $FACTORY_PATH/scripts/validate-project.sh $TARGET
EOF
