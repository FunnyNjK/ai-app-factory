#!/usr/bin/env bash
# scripts/test/factory.test.sh — tests for scripts/factory.sh and the shared
# dispatch map in scripts/orchestrator/lib.sh.
#
# Covers the surface ADR-0012 asked be tested first:
#   - the non-interactive CLI (--help / --next / --status), end to end
#   - factory_adapter_for, the shared dispatch map (the drift bug this kills)
#   - role-config reads with built-in fallback
#
# Dependency-free except python3, which the factory already requires (lib.sh
# parses TASKS.md and .factory-roles.json via python3).
set -uo pipefail

TEST_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
FACTORY_ROOT=$(cd -- "$TEST_DIR/../.." && pwd)
FACTORY="$FACTORY_ROOT/scripts/factory.sh"
LIB="$FACTORY_ROOT/scripts/orchestrator/lib.sh"
CURRENT_SUITE="factory.sh"

# shellcheck source=lib-assert.sh
. "$TEST_DIR/lib-assert.sh"

# --- fixtures -------------------------------------------------------------
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# A scaffolded project whose next action is a pending slice.
mk_slice_project() {
  local d="$WORK/slice"
  mkdir -p "$d"
  cat >"$d/TASKS.md" <<'EOF'
# Tasks

## Phase 1

### 1.1 First slice
- Status: pending
EOF
  printf '%s\n' "$d"
}

# A project whose slices are done and whose next action is a phase review.
mk_phase_project() {
  local d="$WORK/phase"
  mkdir -p "$d"
  cat >"$d/TASKS.md" <<'EOF'
# Tasks

### 1.1 First slice
- Status: approved

### Phase 1 review
- Status: awaiting-review
EOF
  printf '%s\n' "$d"
}

# run_factory <dir> <args...>  -> sets OUT (stdout+stderr) and RC (exit code)
run_factory() {
  local d="$1"
  shift
  OUT=$(cd "$d" && "$FACTORY" "$@" 2>&1)
  RC=$?
}

# --- 1. --help ------------------------------------------------------------
OUT=$("$FACTORY" --help 2>&1); RC=$?
assert_code 0 "$RC" "--help exits 0"
assert_contains "$OUT" "factory.sh" "--help mentions factory.sh"
assert_contains "$OUT" "--next" "--help documents --next"

# --- 2. shared adapter map (the ADR-0012 drift bug) -----------------------
# shellcheck source=../orchestrator/lib.sh
. "$LIB"
assert_eq "cursor-slice.sh"            "$(factory_adapter_for cursor slice)"                  "map: cursor slice"
assert_eq "codex-slice-review.sh"      "$(factory_adapter_for codex slice)"                   "map: codex slice"
assert_eq "codex-slice-verify.sh"      "$(factory_adapter_for codex slice-verify)"            "map: codex slice-verify"
assert_eq "claude-phase-review.sh"     "$(factory_adapter_for claude phase-review)"           "map: claude phase-review"
assert_eq "security-phase-review.sh"   "$(factory_adapter_for security phase-security)"       "map: security phase-security"
assert_eq "codereview-phase-review.sh" "$(factory_adapter_for codereview phase-code-review)"  "map: codereview phase-code-review"
assert_eq "gate-d-signoff.sh"          "$(factory_adapter_for orchestrator gate-d-signoff)"   "map: orchestrator gate-d-signoff"
assert_eq ""                           "$(factory_adapter_for bogus thing)"                   "map: unknown combo -> empty"

# --- 3. --next resolves a pending slice -----------------------------------
d=$(mk_slice_project); run_factory "$d" --next
assert_code 0 "$RC" "--next (pending slice) exits 0"
assert_contains "$OUT" "cursor-slice.sh 1.1" "--next points at cursor-slice.sh 1.1"

# --- 4. --next resolves a phase review ------------------------------------
d=$(mk_phase_project); run_factory "$d" --next
assert_code 0 "$RC" "--next (phase review) exits 0"
assert_contains "$OUT" "claude-phase-review.sh 1" "--next points at claude-phase-review.sh 1"

# --- 5. --next without TASKS.md is an error -------------------------------
mkdir -p "$WORK/empty"; run_factory "$WORK/empty" --next
assert_code 1 "$RC" "--next with no TASKS.md exits 1"
assert_contains "$OUT" "not a scaffolded project" "--next explains the missing TASKS.md"

# --- 6. --status summarizes the project -----------------------------------
d=$(mk_slice_project); run_factory "$d" --status
assert_code 0 "$RC" "--status exits 0"
assert_contains "$OUT" "Project:" "--status prints a Project line"
assert_contains "$OUT" "slices defined: 1" "--status counts slices"
assert_contains "$OUT" "cursor-slice.sh 1.1" "--status shows the next action"

# --- 7. unknown argument is rejected --------------------------------------
OUT=$("$FACTORY" --bogus 2>&1); RC=$?
assert_code 1 "$RC" "unknown arg exits 1"
assert_contains "$OUT" "unknown argument" "unknown arg is reported"

# --- 8. role config reads, with built-in fallback -------------------------
cfg="$WORK/roles.json"
cat >"$cfg" <<'EOF'
{ "roles": { "architect": { "tool": "gemini", "name": "Athena" } } }
EOF
assert_eq "gemini" "$(factory_role_tool architect "$cfg")" "role tool: explicit value from file"
assert_eq "Athena" "$(factory_role_name architect "$cfg")" "role name: explicit value from file"
assert_eq "cursor" "$(factory_role_tool developer "$cfg")" "role tool: built-in default when absent from file"

# --- 9. --next / --status accept a project path ---------------------------
d=$(mk_slice_project)
OUT=$("$FACTORY" --next "$d" 2>&1); RC=$?
assert_code 0 "$RC" "--next <path> exits 0"
assert_contains "$OUT" "cursor-slice.sh 1.1" "--next <path> resolves a project elsewhere"
OUT=$("$FACTORY" --status "$d" 2>&1); RC=$?
assert_code 0 "$RC" "--status <path> exits 0"
assert_contains "$OUT" "slices defined: 1" "--status <path> resolves a project elsewhere"
OUT=$("$FACTORY" --next "$WORK/nope" 2>&1); RC=$?
assert_code 1 "$RC" "--next <bad path> exits 1"
assert_contains "$OUT" "not a directory" "--next <bad path> is reported"

assert_summary
