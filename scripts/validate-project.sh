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

printf '\n[2] Unfilled scaffold placeholders (in persona/planning files)\n'

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

# Scaffold tokens that scripts/scaffold-new-project.sh fills in at scaffold
# time. If any of these remain in a persona or planning file, the scaffold
# step was incomplete. Keep in sync with the sed replacements in
# scripts/scaffold-new-project.sh.
#
# This is a WHITELIST (only these tokens fail validation). HTML tags
# (`<title>`, `<meta>`, `<head>`, `<script>`), URL patterns (`<branch>`),
# ADR naming examples (`<title>` in 00XX-<title>.md), and other
# documentation-only `<...>` tokens pass through unchanged because they are
# not scaffold tokens.
SCAFFOLD_PLACEHOLDERS=(
  "<project-name>"
  "<blueprint-name>"
  "<blueprint>"
  "<factory-path>"
  "<one-line-goal>"
  "<primary-users>"
  "<date-or-none>"
  "<who>"
)

for f in "${PLACEHOLDER_TARGETS[@]}"; do
  [ -f "$f" ] || continue

  # Strip fenced code blocks so example placeholders inside ```...``` are ignored.
  raw_content=$(awk '
    /^```/ { in_fence = !in_fence; next }
    !in_fence { print }
  ' "$f")

  # grep -F with multiple -e args searches for any of the scaffold tokens as
  # fixed strings (no regex interpretation). Each token must appear
  # literally — `<who>` will not match `<whoever>` or `<whodunit>`.
  found=$(printf '%s' "$raw_content" | grep -nF "${SCAFFOLD_PLACEHOLDERS[@]/#/-e}" 2>/dev/null || true)
  if [ -n "$found" ]; then
    fail "$f has unfilled scaffold placeholders:"
    printf '%s\n' "$found" | sed 's/^/        /'
  else
    pass "$f has no unfilled scaffold placeholders"
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
  # sensitive pattern from the orchestrator's lib.sh, then exclude known-safe
  # placeholder files. `.env.example`, `.env.sample`, and `.env.template`
  # are the canonical safe forms — they hold placeholder values only and
  # are committed on purpose so contributors know which variables exist.
  sensitive_re='(^|/)(\.env(\..+)?|\.envrc|\.netrc|\.npmrc|\.pypirc|\.pgpass|\.kube/config|credentials(\.json)?|secrets?(\.ya?ml|\.json|\.env)?|.*\.pem|.*\.key|.*\.p12|.*\.pfx|.*\.crt|.*\.cer|id_rsa|id_dsa|id_ecdsa|id_ed25519|.*\.sqlite3?|.*\.db|.*\.mdb|.*\.dump|.*\.bak)$'
  safe_placeholder_re='(^|/)\.env\.(example|sample|template)$'
  bad=$(git ls-files | grep -E "$sensitive_re" | grep -vE "$safe_placeholder_re" || true)
  if [ -n "$bad" ]; then
    fail "tracked files match sensitive pattern (review and gitignore):"
    printf '%s\n' "$bad" | sed 's/^/        /'
  else
    pass "no tracked files match sensitive pattern (.env.example excluded)"
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
