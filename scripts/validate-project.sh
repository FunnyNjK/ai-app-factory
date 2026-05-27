#!/usr/bin/env bash
# scripts/validate-project.sh — lint a spawned factory project for common
# setup issues. Mirrors validate-factory.mjs but targets per-project state.
#
# Checks:
#   1. Required persona and planning files exist:
#        CLAUDE.md, AGENTS.md, .cursor/rules/developer.mdc,
#        TASKS.md, ESCALATIONS.md, ARCHITECTURE.md, PROJECT.md,
#        SECURITY.md, .env.example
#   2. No unfilled <placeholder> tokens remain in persona/planning files
#      (excludes fenced code-block examples and the `<placeholder>` literals
#      used in documentation prose).
#   3. TASKS.md has at least one Phase section and one slice with a Status line.
#   4. ESCALATIONS.md is structurally intact (has the expected sections).
#   5. No obvious secrets in tracked files (.env, *.pem, id_rsa, etc.).
#
# Usage:
#   scripts/validate-project.sh [project-path]
#
# If no path is given, validates the current directory.
#
# Exit codes:
#   0   all checks pass
#   1   one or more checks failed

set -euo pipefail

PROJECT_PATH="${1:-$(pwd)}"

if [ ! -d "$PROJECT_PATH" ]; then
  printf 'error: not a directory: %s\n' "$PROJECT_PATH" >&2
  exit 1
fi

cd "$PROJECT_PATH"

ERRORS=0
fail() {
  printf 'FAIL  %s\n' "$*"
  ERRORS=$((ERRORS + 1))
}
note() {
  printf 'note  %s\n' "$*"
}
pass() {
  printf 'pass  %s\n' "$*"
}

printf 'Validating project: %s\n' "$PROJECT_PATH"
printf '====================\n'

# --- 1. Required files ----------------------------------------------------

REQUIRED_FILES=(
  "CLAUDE.md"
  "AGENTS.md"
  ".cursor/rules/developer.mdc"
  "TASKS.md"
  "ESCALATIONS.md"
  "ARCHITECTURE.md"
  "PROJECT.md"
  "SECURITY.md"
  ".env.example"
)

printf '\n[1] Required files\n'
for f in "${REQUIRED_FILES[@]}"; do
  if [ -f "$f" ]; then
    pass "$f"
  else
    fail "missing: $f"
  fi
done

# --- 2. Unfilled placeholders ---------------------------------------------

printf '\n[2] Unfilled placeholders (in persona/planning files)\n'

# Files we lint. .gitignore is intentionally not lint'd — placeholder-like
# tokens there would be path globs, not unfilled values.
PLACEHOLDER_TARGETS=(
  "CLAUDE.md"
  "AGENTS.md"
  ".cursor/rules/developer.mdc"
  "TASKS.md"
  "ESCALATIONS.md"
  "ARCHITECTURE.md"
  "PROJECT.md"
  "SECURITY.md"
)

# Tokens that are intentionally documentation-only and should NOT be flagged
# as unfilled placeholders. Add to this list when you find new docs-only
# placeholder tokens.
DOC_PLACEHOLDER_TOKENS=(
  "<placeholder>"
  "<slice-name>"
  "<slice-id>"
  "<phase-name>"
  "<what-this-phase-delivers>"
  "<number-or-default>"
  "<short>"
  "<short summary>"
  "<short reason>"
  "<short list>"
  "<one-line evidence summary>"
  "<one-line reason>"
  "<one-line summary of what you implemented>"
  "<one-line summary of what you did>"
  "<short>"
)

# Build a grep-friendly pattern (escape <, >).
strip_doc_placeholders() {
  local content="$1"
  for tok in "${DOC_PLACEHOLDER_TOKENS[@]}"; do
    content=$(printf '%s' "$content" | sed "s|$tok||g")
  done
  printf '%s' "$content"
}

for f in "${PLACEHOLDER_TARGETS[@]}"; do
  [ -f "$f" ] || continue

  # Strip fenced code blocks so example placeholders inside ```...``` are ignored.
  raw_content=$(awk '
    /^```/ { in_fence = !in_fence; next }
    !in_fence { print }
  ' "$f")

  # Strip known doc-only placeholders.
  stripped=$(strip_doc_placeholders "$raw_content")

  # Find remaining <something> patterns (must start with a letter/digit, hyphen-tolerant).
  found=$(printf '%s' "$stripped" | grep -nE '<[A-Za-z][A-Za-z0-9_-]*>' || true)
  if [ -n "$found" ]; then
    fail "$f has unfilled placeholders:"
    printf '%s\n' "$found" | sed 's/^/        /'
  else
    pass "$f has no unfilled placeholders"
  fi
done

# --- 3. TASKS.md structure ------------------------------------------------

printf '\n[3] TASKS.md structure\n'

if [ -f TASKS.md ]; then
  phase_count=$(grep -cE '^## Phase [0-9]+' TASKS.md || true)
  slice_count=$(awk '
    /^```/ { in_fence = !in_fence; next }
    !in_fence && /^### [0-9]+\.[0-9]+/ { count++ }
    END { print count + 0 }
  ' TASKS.md)
  status_count=$(awk '
    /^```/ { in_fence = !in_fence; next }
    !in_fence && /^- Status:/ { count++ }
    END { print count + 0 }
  ' TASKS.md)

  if [ "$phase_count" -lt 1 ]; then
    fail "TASKS.md has no '## Phase N' sections"
  else
    pass "TASKS.md has $phase_count phase section(s)"
  fi

  if [ "$slice_count" -lt 1 ]; then
    fail "TASKS.md has no '### N.M' slice entries"
  else
    pass "TASKS.md has $slice_count slice(s)"
  fi

  if [ "$status_count" -lt "$slice_count" ]; then
    fail "TASKS.md has fewer Status lines ($status_count) than slices ($slice_count)"
  else
    pass "TASKS.md has Status lines for every slice"
  fi
fi

# --- 4. ESCALATIONS.md structure ------------------------------------------

printf '\n[4] ESCALATIONS.md structure\n'

if [ -f ESCALATIONS.md ]; then
  if grep -qE '^## Open' ESCALATIONS.md; then
    pass "ESCALATIONS.md has '## Open' section"
  else
    fail "ESCALATIONS.md missing '## Open' section"
  fi
  if grep -qE '^## Resolved' ESCALATIONS.md; then
    pass "ESCALATIONS.md has '## Resolved' section"
  else
    fail "ESCALATIONS.md missing '## Resolved' section"
  fi
fi

# --- 5. Obvious secrets in tracked files ---------------------------------

printf '\n[5] Secrets in tracked files\n'

# Run only if we are inside a git worktree.
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  # Look for files git is tracking (or about to track) that match the
  # sensitive pattern from the orchestrator's lib.sh.
  sensitive_re='(^|/)(\.env(\..+)?|\.envrc|\.netrc|\.npmrc|\.pypirc|\.pgpass|\.kube/config|credentials(\.json)?|secrets?(\.ya?ml|\.json|\.env)?|.*\.pem|.*\.key|.*\.p12|.*\.pfx|.*\.crt|.*\.cer|id_rsa|id_dsa|id_ecdsa|id_ed25519|.*\.sqlite3?|.*\.db|.*\.mdb|.*\.dump|.*\.bak)$'
  bad=$(git ls-files | grep -E "$sensitive_re" || true)
  if [ -n "$bad" ]; then
    fail "tracked files match sensitive pattern (review and gitignore):"
    printf '%s\n' "$bad" | sed 's/^/        /'
  else
    pass "no tracked files match sensitive pattern"
  fi
else
  note "not inside a git worktree; skipping secret scan"
fi

# --- Summary --------------------------------------------------------------

printf '\n====================\n'
if [ "$ERRORS" -eq 0 ]; then
  printf 'Project validation passed.\n'
  exit 0
fi
printf 'Project validation FAILED with %d error(s).\n' "$ERRORS"
exit 1
