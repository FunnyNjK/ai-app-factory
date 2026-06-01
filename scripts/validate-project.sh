#!/usr/bin/env bash
# scripts/validate-project.sh -lint a spawned factory project for common
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

# Files we lint. .gitignore is intentionally not lint'd -placeholder-like
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
  # literally -`<who>` will not match `<whoever>` or `<whodunit>`.
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
  # are the canonical safe forms -they hold placeholder values only and
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

# --- 6. Lifecycle consistency (Gate D sign-off, escalations, phase reviews) -
#
# These cross-reference TASKS.md, SIGNOFF.md, and ESCALATIONS.md to catch the
# manual-intervention mistakes the first end-to-end run produced: an unfilled
# SIGNOFF.md after all phases approved, escalations left open against approved
# work, and a phase-review Status that disagrees with its own Notes. Reports
# only - the human fixes the mismatch.

printf '\n[6] Lifecycle consistency\n'

set +e
# Heredoc redirected to a temp file rather than wrapped in $(...): stock macOS
# bash 3.2 mis-parses a here-doc nested inside command substitution.
LIFECYCLE_TMP=$(mktemp "${TMPDIR:-/tmp}/factory-lifecycle.XXXXXX")
python3 - >"$LIFECYCLE_TMP" <<'PYEOF'
import os
import re
import sys

fails = 0


def emit_fail(msg):
    global fails
    fails += 1
    print(f"FAIL  {msg}")


def emit_pass(msg):
    print(f"pass  {msg}")


def strip_code_blocks(text):
    out = []
    in_fence = False
    for line in text.split("\n"):
        if line.startswith("```"):
            in_fence = not in_fence
            continue
        if not in_fence:
            out.append(line)
    return "\n".join(out)


tasks = ""
if os.path.exists("TASKS.md"):
    with open("TASKS.md", encoding="utf-8") as f:
        tasks = strip_code_blocks(f.read())

status_re = re.compile(r"^-\s+Status:\s+`?([a-z\-]+)`?", re.MULTILINE | re.IGNORECASE)
notes_re = re.compile(r"^-\s+Notes:\s*(.*)$", re.MULTILINE | re.IGNORECASE)
all_heads = [m.start() for m in re.finditer(r"^###\s", tasks, re.MULTILINE)]


def body(pos):
    nxt = min([h for h in all_heads if h > pos], default=len(tasks))
    return tasks[pos:nxt]


parsed = []  # (kind, id, status, notes)
for m in re.finditer(r"^###\s+(\d+\.\d+)\b", tasks, re.MULTILINE):
    b = body(m.start())
    sm, nm = status_re.search(b), notes_re.search(b)
    parsed.append(("slice", m.group(1), sm.group(1).lower() if sm else "pending", nm.group(1).strip() if nm else ""))
for m in re.finditer(r"^###\s+Phase\s+(\d+)\s+review\b", tasks, re.MULTILINE | re.IGNORECASE):
    b = body(m.start())
    sm, nm = status_re.search(b), notes_re.search(b)
    parsed.append(("phase-review", m.group(1), sm.group(1).lower() if sm else "pending", nm.group(1).strip() if nm else ""))

phase_reviews = [(i, s, n) for (k, i, s, n) in parsed if k == "phase-review"]
slice_status = {i: s for (k, i, s, n) in parsed if k == "slice"}
phase_status = {i: s for (k, i, s, n) in parsed if k == "phase-review"}

# Per-phase security and code-review gates (ADR-0013) must also be approved
# before Gate D is due. Absent gates (older projects) impose no requirement.
extra_gate_status = []
for word in ("security", "code-review"):
    for m in re.finditer(r"^###\s+Phase\s+(\d+)\s+" + word + r"\b", tasks, re.MULTILINE | re.IGNORECASE):
        sm = status_re.search(body(m.start()))
        extra_gate_status.append(sm.group(1).lower() if sm else "pending")

# Check 1: SIGNOFF.md must be filled once every phase gate is approved.
all_approved = (
    bool(phase_reviews)
    and all(s == "approved" for (_, s, _) in phase_reviews)
    and all(s == "approved" for s in extra_gate_status)
)
if not all_approved:
    emit_pass("Gate D sign-off not due (not every phase gate is approved)")
elif not os.path.exists("SIGNOFF.md"):
    emit_fail("every phase review is approved but SIGNOFF.md is missing - run gate-d-signoff.sh")
else:
    with open("SIGNOFF.md", encoding="utf-8") as f:
        sign = f.read()
    unfilled = []
    if "YYYY-MM-DD" in sign:
        unfilled.append("YYYY-MM-DD date placeholder")
    if re.search(r"^\*\*Decision:\*\*.*\|", sign, re.MULTILINE):
        unfilled.append("unchosen Decision option-list")
    if "name (product owner)" in sign:
        unfilled.append("name (product owner) placeholder")
    if unfilled:
        emit_fail("Gate D sign-off not complete - run gate-d-signoff.sh (" + "; ".join(unfilled) + ")")
    else:
        emit_pass("SIGNOFF.md is fully signed (all phase reviews approved)")

# Check 2: no escalation under ## Open references an already-approved item.
esc = ""
if os.path.exists("ESCALATIONS.md"):
    with open("ESCALATIONS.md", encoding="utf-8") as f:
        esc = f.read().replace("\r\n", "\n")
open_m = re.search(r"^##\s+Open\b", esc, re.MULTILINE)
resolved_m = re.search(r"^##\s+Resolved\b", esc, re.MULTILINE)
open_body = ""
if open_m:
    end = resolved_m.start() if (resolved_m and resolved_m.start() > open_m.start()) else len(esc)
    open_body = esc[open_m.end():end]
stale = []
for em in re.finditer(r"^###\s+(ESC-\d+)\b", open_body, re.MULTILINE):
    nxt = re.search(r"^###\s", open_body[em.end():], re.MULTILINE)
    block = open_body[em.start():em.end() + nxt.start()] if nxt else open_body[em.start():]
    esc_id = em.group(1)
    psm = re.search(r"^-\s+Phase/Slice:\s*(.*)$", block, re.MULTILINE)
    ps = psm.group(1).strip() if psm else ""
    sl = re.search(r"(?<!\d)(\d+\.\d+)(?!\d)", ps)
    if sl and slice_status.get(sl.group(1)) == "approved":
        stale.append(f"{esc_id} is open but slice {sl.group(1)} is approved - move it to Resolved")
        continue
    if not sl and "phase" in ps.lower():
        ph = re.search(r"(?<!\d)(\d+)(?!\d)", ps)
        if ph and phase_status.get(ph.group(1)) == "approved":
            stale.append(f"{esc_id} is open but phase {ph.group(1)} is approved - move it to Resolved")
if stale:
    for s in stale:
        emit_fail(s)
else:
    emit_pass("no open escalations reference an approved slice or phase")

# Check 3: a phase review whose Notes read "Approved" must have Status approved.
mismatches = []
for (i, s, n) in phase_reviews:
    note = n.lstrip("-* ").strip()
    looks_approved = note.startswith("Approved") or re.search(r"Approved\s+\d{4}-\d{2}-\d{2}", n)
    if looks_approved and s != "approved":
        mismatches.append(f"Phase {i} review Status/Notes mismatch - Notes say approved but Status is `{s}`")
if mismatches:
    for msg in mismatches:
        emit_fail(msg)
else:
    emit_pass("phase-review Status matches Notes")

sys.exit(fails)
PYEOF
lifecycle_rc=$?
set -e
cat "$LIFECYCLE_TMP"
rm -f "$LIFECYCLE_TMP"
ERRORS=$((ERRORS + lifecycle_rc))

# --- 7. Planning completeness (slice / phase / ADR required structure) -----
#
# Ports the prior project's lint-planning.py: every slice and phase review must
# carry its required fields, and every project ADR its required sections, so the
# work is fully specified before implementation (Gate B). Reports only.

printf '\n[7] Planning completeness\n'

set +e
COMPLETENESS_TMP=$(mktemp "${TMPDIR:-/tmp}/factory-completeness.XXXXXX")
python3 - >"$COMPLETENESS_TMP" <<'PYEOF'
import glob
import os
import re
import sys

fails = 0


def emit_fail(msg):
    global fails
    fails += 1
    print(f"FAIL  {msg}")


def emit_pass(msg):
    print(f"pass  {msg}")


def strip_code_blocks(text):
    out = []
    in_fence = False
    for line in text.split("\n"):
        if line.startswith("```"):
            in_fence = not in_fence
            continue
        if not in_fence:
            out.append(line)
    return "\n".join(out)


tasks = ""
if os.path.exists("TASKS.md"):
    with open("TASKS.md", encoding="utf-8") as f:
        tasks = strip_code_blocks(f.read())

all_heads = [m.start() for m in re.finditer(r"^###\s", tasks, re.MULTILINE)]


def body(pos):
    nxt = min([h for h in all_heads if h > pos], default=len(tasks))
    return tasks[pos:nxt]


def has_field(text, label):
    return re.search(r"^-\s+" + re.escape(label) + r":", text, re.MULTILINE | re.IGNORECASE) is not None


SLICE_FIELDS = ["Status", "Owner", "Acceptance criteria", "Iterations"]
PHASE_FIELDS = ["Status", "Reviewer", "Iterations"]

missing = []
for m in re.finditer(r"^###\s+(\d+\.\d+)\b", tasks, re.MULTILINE):
    b = body(m.start())
    for field in SLICE_FIELDS:
        if not has_field(b, field):
            missing.append(f"slice {m.group(1)} is missing its '{field}' line")
for m in re.finditer(r"^###\s+Phase\s+(\d+)\s+review\b", tasks, re.MULTILINE | re.IGNORECASE):
    b = body(m.start())
    for field in PHASE_FIELDS:
        if not has_field(b, field):
            missing.append(f"Phase {m.group(1)} review is missing its '{field}' line")
# Security and code-review gates (ADR-0013) carry the same required fields.
for word in ("security", "code-review"):
    for m in re.finditer(r"^###\s+Phase\s+(\d+)\s+" + word + r"\b", tasks, re.MULTILINE | re.IGNORECASE):
        b = body(m.start())
        for field in PHASE_FIELDS:
            if not has_field(b, field):
                missing.append(f"Phase {m.group(1)} {word} is missing its '{field}' line")
if missing:
    for msg in missing:
        emit_fail(msg)
else:
    emit_pass("every slice and phase review has its required fields")

# Required ADR sections (matches templates/ADR.md; 'Alternatives' covers both
# 'Alternatives considered' and the older 'Alternatives Considered').
ADR_SECTIONS = ["Status", "Context", "Decision", "Alternatives", "Consequences"]
# ADRs follow the NNNN-title.md naming convention. Only those files are ADRs;
# skip any non-ADR file in the folder (e.g. an index README.md) that legitimately
# has none of the ADR sections.
adr_files = sorted(
    p for p in glob.glob(os.path.join("docs", "adr", "*.md"))
    if re.match(r"\d", os.path.basename(p))
)
if adr_files:
    adr_missing = []
    for path in adr_files:
        with open(path, encoding="utf-8") as f:
            text = f.read()
        for sec in ADR_SECTIONS:
            if not re.search(r"^##\s+" + re.escape(sec), text, re.MULTILINE | re.IGNORECASE):
                adr_missing.append(f"{os.path.basename(path)} is missing its '## {sec}' section")
    if adr_missing:
        for msg in adr_missing:
            emit_fail(msg)
    else:
        emit_pass(f"every ADR ({len(adr_files)}) has its required sections")
else:
    emit_pass("no project ADRs yet")

sys.exit(fails)
PYEOF
completeness_rc=$?
set -e
cat "$COMPLETENESS_TMP"
rm -f "$COMPLETENESS_TMP"
ERRORS=$((ERRORS + completeness_rc))

# --- Summary --------------------------------------------------------------

printf '\n====================\n'
if [ "$ERRORS" -eq 0 ]; then
  printf 'Project validation passed.\n'
  exit 0
fi
printf 'Project validation FAILED with %d error(s).\n' "$ERRORS"
exit 1
