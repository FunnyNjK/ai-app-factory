#!/usr/bin/env bash
# scripts/test/project-scripts.test.sh — tests for the per-project lint and
# drift scripts: the .factory-roles.json validation in
# scripts/validate-project.sh (check [8]) and the ADR-0013 drift markers in
# scripts/refresh-project.sh.
#
# Fixtures are temp directories; validate-project.sh assertions key on the
# check-[8] output strings (the fixtures intentionally fail other checks), and
# refresh-project.sh assertions use full fixtures so exit codes are meaningful.
set -uo pipefail

TEST_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
FACTORY_ROOT=$(cd -- "$TEST_DIR/../.." && pwd)
CURRENT_SUITE="project scripts"

# shellcheck source=lib-assert.sh
. "$TEST_DIR/lib-assert.sh"

VALIDATE="$FACTORY_ROOT/scripts/validate-project.sh"
REFRESH="$FACTORY_ROOT/scripts/refresh-project.sh"
SKELETON="$FACTORY_ROOT/templates/project-skeleton"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# --- validate-project.sh check [8]: .factory-roles.json --------------------

# No roles file -> note, not FAIL.
P="$WORK/no-roles" && mkdir -p "$P"
out=$(bash "$VALIDATE" "$P" 2>&1)
assert_contains "$out" "no .factory-roles.json" "validate: missing roles file is reported as a note"
roles_section=$(printf '%s\n' "$out" | sed -n '/\[8\] Role configuration/,$p')
assert_eq "0" "$(printf '%s\n' "$roles_section" | grep -c '^FAIL')" "validate: missing roles file adds no failures"

# The factory default roles file -> pass.
P="$WORK/default-roles" && mkdir -p "$P"
cp "$FACTORY_ROOT/templates/factory-roles.default.json" "$P/.factory-roles.json"
out=$(bash "$VALIDATE" "$P" 2>&1)
assert_contains "$out" ".factory-roles.json maps every configured role to a supported tool" "validate: factory default roles file passes"

# Malformed JSON -> FAIL.
P="$WORK/bad-json" && mkdir -p "$P"
printf '{ not json' > "$P/.factory-roles.json"
out=$(bash "$VALIDATE" "$P" 2>&1)
assert_contains "$out" "not valid JSON" "validate: malformed JSON is a failure"

# Missing "roles" object -> FAIL.
P="$WORK/no-roles-key" && mkdir -p "$P"
printf '{ "team": {} }' > "$P/.factory-roles.json"
out=$(bash "$VALIDATE" "$P" 2>&1)
assert_contains "$out" 'no "roles" object' "validate: missing roles object is a failure"

# Unknown role key -> FAIL (role keys are structural, ADR-0013).
P="$WORK/unknown-role" && mkdir -p "$P"
printf '{ "roles": { "qa": { "tool": "codex", "name": "QA" } } }' > "$P/.factory-roles.json"
out=$(bash "$VALIDATE" "$P" 2>&1)
assert_contains "$out" 'unknown role key "qa"' "validate: unknown role key is a failure"

# Unsupported tool -> FAIL.
P="$WORK/bad-tool" && mkdir -p "$P"
printf '{ "roles": { "architect": { "tool": "vscode", "name": "VS Code" } } }' > "$P/.factory-roles.json"
out=$(bash "$VALIDATE" "$P" 2>&1)
assert_contains "$out" 'unsupported tool "vscode"' "validate: unsupported tool is a failure"

# Missing display name -> FAIL.
P="$WORK/no-name" && mkdir -p "$P"
printf '{ "roles": { "architect": { "tool": "claude" } } }' > "$P/.factory-roles.json"
out=$(bash "$VALIDATE" "$P" 2>&1)
assert_contains "$out" 'role "architect" has no display name' "validate: missing display name is a failure"

# Partial mapping (only some roles) -> note for the unmapped, no failure.
P="$WORK/partial-roles" && mkdir -p "$P"
printf '{ "roles": { "architect": { "tool": "gemini", "name": "Athena" } } }' > "$P/.factory-roles.json"
out=$(bash "$VALIDATE" "$P" 2>&1)
assert_contains "$out" ".factory-roles.json does not map:" "validate: partial mapping notes the unmapped roles"
assert_contains "$out" ".factory-roles.json maps every configured role to a supported tool" "validate: partial mapping with valid entries passes"

# --- validate-project.sh check [6]: accepted-risk re-review date (ADR-0010) -

# Helper: a one-phase project where every gate is approved, so the Gate D
# lifecycle checks (including the ADR-0010 re-review-date rule) actually run.
make_approved_project() {
  local dir="$1"
  mkdir -p "$dir"
  cat > "$dir/TASKS.md" <<'TASKS'
# Project Tasks — test

## Phase 1 — Test

### 1.1 test slice

- Status: `approved`
- Owner: cursor
- Acceptance criteria: test
- Iterations: 1/3
- Notes: -

### Phase 1 review

- Status: `approved`
- Reviewer: architect
- Iterations: 1/2
- Notes: Approved 2026-06-01

### Phase 1 security

- Status: `approved`
- Reviewer: security
- Iterations: 1/2
- Notes: Approved 2026-06-01

### Phase 1 code-review

- Status: `approved`
- Reviewer: code_review
- Iterations: 1/2
- Notes: Approved 2026-06-01
TASKS
}

# Filled product-owner sign-off accepting risks WITHOUT a re-review date -> FAIL.
P="$WORK/risks-no-date"
make_approved_project "$P"
cat > "$P/SIGNOFF.md" <<'SIGN'
## Product owner / technical owner sign-off

**Decision:** Release approved with accepted risks

**Notes:**

Accepting the risk of no rate limiting in v1.

**Signed:** Test Owner (product owner) — 2026-06-01
SIGN
out=$(bash "$VALIDATE" "$P" 2>&1)
assert_contains "$out" "no 'Accepted risks re-review date:' line (ADR-0010)" "validate: accepted risks without a re-review-date line is a failure"

# Same, but the re-review-date line still holds the template placeholder -> FAIL.
P="$WORK/risks-placeholder-date"
make_approved_project "$P"
cat > "$P/SIGNOFF.md" <<'SIGN'
## Product owner / technical owner sign-off

**Decision:** Release approved with accepted risks

**Notes:**

Accepting the risk of no rate limiting in v1.

**Accepted risks re-review date:** none

**Signed:** Test Owner (product owner) — 2026-06-01
SIGN
out=$(bash "$VALIDATE" "$P" 2>&1)
assert_contains "$out" "without an explicit re-review date (ADR-0010)" "validate: accepted risks with 'none' as the re-review date is a failure"

# Same, with a real re-review date -> pass.
P="$WORK/risks-with-date"
make_approved_project "$P"
cat > "$P/SIGNOFF.md" <<'SIGN'
## Product owner / technical owner sign-off

**Decision:** Release approved with accepted risks

**Notes:**

Accepting the risk of no rate limiting in v1.

**Accepted risks re-review date:** 2026-09-01

**Signed:** Test Owner (product owner) — 2026-06-01
SIGN
out=$(bash "$VALIDATE" "$P" 2>&1)
assert_contains "$out" "accepted risks carry a re-review date (2026-09-01)" "validate: accepted risks with a real re-review date pass"

# No risks accepted -> the re-review rule does not apply.
P="$WORK/no-risks"
make_approved_project "$P"
cat > "$P/SIGNOFF.md" <<'SIGN'
## Product owner / technical owner sign-off

**Decision:** Release approved

**Notes:**

No risks accepted.

**Accepted risks re-review date:** none

**Signed:** Test Owner (product owner) — 2026-06-01
SIGN
out=$(bash "$VALIDATE" "$P" 2>&1)
risk_fails=$(printf '%s\n' "$out" | grep -c 'ADR-0010' || true)
assert_eq "0" "$risk_fails" "validate: plain approval is exempt from the re-review-date rule"

# --- refresh-project.sh: ADR-0013 drift markers -----------------------------

# Full fixture: skeleton + the files the scaffolder adds -> no drift, exit 0.
P="$WORK/up-to-date"
cp -R "$SKELETON" "$P"
printf 'factory-baseline test\n' > "$P/.factory-version"
cp "$FACTORY_ROOT/templates/SIGNOFF.md" "$P/SIGNOFF.md"
cp "$FACTORY_ROOT/templates/factory-roles.default.json" "$P/.factory-roles.json"
out=$(bash "$REFRESH" "$P" 2>&1)
rc=$?
assert_code "0" "$rc" "refresh: fully scaffolded project has no drift"
assert_contains "$out" ".factory-roles.json present" "refresh: roles file marker is ok"
assert_contains "$out" "TASKS.md has the per-phase security and code-review gates" "refresh: phase-gate marker is ok"
assert_contains "$out" "Gate D six-party sign-off" "refresh: SIGNOFF marker uses six-party language"

# Same fixture minus .factory-roles.json -> drift, exit 1.
P="$WORK/pre-adr-0013"
cp -R "$SKELETON" "$P"
printf 'factory-baseline test\n' > "$P/.factory-version"
cp "$FACTORY_ROOT/templates/SIGNOFF.md" "$P/SIGNOFF.md"
out=$(bash "$REFRESH" "$P" 2>&1)
rc=$?
assert_code "1" "$rc" "refresh: missing roles file is drift"
assert_contains "$out" ".factory-roles.json missing" "refresh: missing roles file is reported"

# Pre-ADR-0013 TASKS.md (review gate only, no security/code-review gates) -> drift.
P="$WORK/old-tasks"
cp -R "$SKELETON" "$P"
printf 'factory-baseline test\n' > "$P/.factory-version"
cp "$FACTORY_ROOT/templates/SIGNOFF.md" "$P/SIGNOFF.md"
cp "$FACTORY_ROOT/templates/factory-roles.default.json" "$P/.factory-roles.json"
grep -viE '^### Phase [0-9]+ (security|code-review)' "$P/TASKS.md" > "$P/TASKS.md.tmp" \
  && mv "$P/TASKS.md.tmp" "$P/TASKS.md"
out=$(bash "$REFRESH" "$P" 2>&1)
rc=$?
assert_code "1" "$rc" "refresh: TASKS.md without phase gates is drift"
assert_contains "$out" "missing the per-phase security and/or code-review gate" "refresh: missing phase gates are reported"

assert_summary
