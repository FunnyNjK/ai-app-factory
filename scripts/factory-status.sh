#!/usr/bin/env bash
# scripts/factory-status.sh — quick health check for the AI App Factory.
# Reports: git state, required CLI tools, ADR/blueprint counts, validator pass/fail.
# Useful before starting a new project or after pulling factory updates.
#
# Usage:
#   factory-status.sh              # report against the factory containing this script
#   factory-status.sh --no-cli     # skip the CLI-tools check (faster)
#
# Exit codes:
#   0 — all green
#   1 — factory state has problems (validator failed, missing required tools, etc.)

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
FACTORY_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)

SKIP_CLI=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-cli) SKIP_CLI=1; shift ;;
    -h|--help)
      sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) printf 'error: unknown argument: %s\n' "$1" >&2; exit 1 ;;
  esac
done

cd "$FACTORY_ROOT"

PROBLEMS=0

printf 'AI App Factory — Status\n'
printf '=======================\n'
printf 'Root: %s\n\n' "$FACTORY_ROOT"

# --- Git state ------------------------------------------------------------

printf '[git]\n'
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git symbolic-ref --quiet --short HEAD || echo '(detached)')
  last_commit=$(git log -1 --format='%h %s' 2>/dev/null || echo '(no commits)')
  dirty=$(git status --porcelain --untracked-files=normal | wc -l | tr -d ' ')
  printf '  branch:       %s\n' "$branch"
  printf '  last commit:  %s\n' "$last_commit"
  printf '  dirty files:  %s\n' "$dirty"
  if [ "$dirty" -gt 0 ]; then
    printf '  note: working tree is dirty — commit, stash, or discard before scaffolding.\n'
  fi
else
  printf '  WARNING — not inside a git worktree.\n'
  PROBLEMS=$((PROBLEMS + 1))
fi

# --- Factory artifact counts ---------------------------------------------

printf '\n[artifacts]\n'
adr_count=$(find docs/adr -name '0*.md' -type f 2>/dev/null | wc -l | tr -d ' ')
blueprint_count=$(find blueprints -name '*.md' -type f 2>/dev/null | wc -l | tr -d ' ')
standard_count=$(find standards -name '*.md' -type f 2>/dev/null | wc -l | tr -d ' ')
template_count=$(find templates -maxdepth 2 -name '*.md' -type f 2>/dev/null | wc -l | tr -d ' ')
example_count=$(find examples -name 'sample-*.md' -type f 2>/dev/null | wc -l | tr -d ' ')
adapter_count=$(find scripts/orchestrator -name '*.sh' -type f 2>/dev/null | wc -l | tr -d ' ')

printf '  ADRs:         %s\n' "$adr_count"
printf '  Blueprints:   %s\n' "$blueprint_count"
printf '  Standards:    %s\n' "$standard_count"
printf '  Templates:    %s\n' "$template_count"
printf '  Examples:     %s\n' "$example_count"
printf '  Orchestrator scripts: %s\n' "$adapter_count"

# --- Required CLI tools --------------------------------------------------

if [ "$SKIP_CLI" = "0" ]; then
  printf '\n[CLIs]\n'
  for tool in claude codex agent; do
    if command -v "$tool" >/dev/null 2>&1; then
      printf '  %-7s present at %s\n' "$tool" "$(command -v "$tool")"
    else
      printf '  %-7s MISSING — run scripts/check-cli-tools.sh for install instructions.\n' "$tool"
      PROBLEMS=$((PROBLEMS + 1))
    fi
  done
fi

# --- Validator -----------------------------------------------------------

printf '\n[validator]\n'
if command -v node >/dev/null 2>&1 && [ -f scripts/validate-factory.mjs ]; then
  if node scripts/validate-factory.mjs >/dev/null 2>&1; then
    printf '  node scripts/validate-factory.mjs: PASS\n'
  else
    printf '  node scripts/validate-factory.mjs: FAIL — run it directly to see errors.\n'
    PROBLEMS=$((PROBLEMS + 1))
  fi
else
  printf '  validator skipped — node or scripts/validate-factory.mjs missing.\n'
fi

# --- Summary -------------------------------------------------------------

printf '\n=======================\n'
if [ "$PROBLEMS" -eq 0 ]; then
  printf 'Factory is healthy.\n'
  exit 0
fi
printf 'Factory has %d problem(s) above. Fix before scaffolding a new project.\n' "$PROBLEMS"
exit 1
