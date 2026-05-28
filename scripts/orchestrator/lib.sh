#!/usr/bin/env bash
# scripts/orchestrator/lib.sh — shared mechanics for the factory orchestrator
# and its per-role adapters.
#
# Two layers of functions:
#   - rpl_*       — universal safety mechanics. Ported from
#                   docs/research/headless-cli/run-phase-lib.sh with the
#                   factory's log-dir convention. Preserves the
#                   sensitive-path refusal, NUL-safe enumeration,
#                   dirty-tree check, push-on-failure stop, etc.
#                   Origin: see ADR-0009 ("References").
#   - factory_*   — factory-specific helpers (TASKS.md parsing/updating,
#                   ESCALATIONS.md appending, status-line parsing).
#
# This file is sourced, not executed. Callers must run `set -euo pipefail`
# themselves. Callers must also set:
#
#   TOOL_NAME       — short pretty name for log lines (e.g. "Cursor")
#   TOOL_LOG_PREFIX — directory prefix for log dir (e.g. "cursor_slice")
#   TOOL_SCRIPT     — script filename for commit-message footer
#
# Sources of truth for the gating model and budget caps:
#   docs/adr/0008-per-slice-and-per-phase-gating.md
#   docs/adr/0009-autonomous-orchestrator.md

# ---------------------------------------------------------------------------
# Logging helpers
# ---------------------------------------------------------------------------
log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
err() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*" >&2; }

# ---------------------------------------------------------------------------
# rpl_init_log_dir — create and echo the per-run log directory.
# Logs land under <project>/.factory-logs/<prefix>_<timestamp>/.
# Usage: LOG_DIR=$(rpl_init_log_dir)
# ---------------------------------------------------------------------------
rpl_init_log_dir() {
  local prefix="${TOOL_LOG_PREFIX:?TOOL_LOG_PREFIX must be set}"
  local stamp
  stamp=$(date +%Y%m%d_%H%M%S)
  local dir=".factory-logs/${prefix}_${stamp}"
  mkdir -p "$dir"
  printf '%s\n' "$dir"
}

# ---------------------------------------------------------------------------
# rpl_preflight — keep unattended runs on a role-specific branch and refuse
# to start with a dirty worktree.
# ---------------------------------------------------------------------------
rpl_preflight() {
  local expected branch target_branch status_output
  expected=$(printf '%s' "${TOOL_NAME:?TOOL_NAME must be set}" | tr '[:upper:]' '[:lower:]')

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    err "error: run the orchestrator from inside a git worktree."
    exit 1
  fi

  status_output=$(git status --porcelain --untracked-files=normal)
  if [ -n "$status_output" ] && [ "${RUN_PHASE_ALLOW_DIRTY:-0}" != "1" ]; then
    err "error: working tree is dirty before the run starts."
    err "The orchestrator only commits changes made during the run. Commit,"
    err "stash, or discard these files first, or set RUN_PHASE_ALLOW_DIRTY=1"
    err "if you intentionally want to include them:"
    printf '%s\n' "$status_output" | sed 's/^/  /' >&2
    exit 1
  fi
  if [ -n "$status_output" ]; then
    err "warning: RUN_PHASE_ALLOW_DIRTY=1 set; pre-existing dirty files may be committed."
  fi

  branch=$(git symbolic-ref --quiet --short HEAD || true)
  if [ -z "$branch" ]; then
    err "error: detached HEAD. Check out a branch before running the orchestrator."
    exit 1
  fi

  case "$branch" in
    "$expected"/*)
      log "Preflight: branch '$branch' matches expected $expected/* prefix."
      ;;
    *)
      if [ "${RUN_PHASE_AUTO_BRANCH:-1}" = "0" ]; then
        err "error: current branch '$branch' does not match expected $expected/* prefix."
        err "Create/switch to a $expected/* branch, or unset RUN_PHASE_AUTO_BRANCH (defaults to auto-create)."
        exit 1
      fi
      target_branch="${expected}/phase-$(date +%Y%m%d-%H%M%S)"
      log "Preflight: creating AI work branch '$target_branch' from '$branch'."
      git checkout -b "$target_branch"
      ;;
  esac
}

# ---------------------------------------------------------------------------
# rpl_extract_subject — parse a commit subject from the handoff log.
# Looks for the "Work completed:" header that the END_PROMPT instructs the
# AI to write.
# Usage: SUBJECT=$(rpl_extract_subject "$LOG_DIR/handoff.log" "<fallback>")
# ---------------------------------------------------------------------------
rpl_extract_subject() {
  local log_file="$1"
  local fallback="$2"
  local subject
  subject=$(awk '
    /Work completed/ {
      line = $0
      gsub(/`/, "", line)
      gsub(/\*/, "", line)
      sub(/^[[:space:]]*[-][[:space:]]*/, "", line)
      sub(/^Work completed[[:space:]]*/, "", line)
      sub(/^[^[:alnum:]]+[[:space:]]*/, "", line)
      if (length(line) > 0) { print line; exit }
      inheader = 1; next
    }
    inheader && /^[[:space:]]*$/ { next }
    inheader { sub(/^[*-][[:space:]]*/, ""); print; exit }
  ' "$log_file" 2>/dev/null \
  | sed 's/`//g; s/\*\*//g' \
  | cut -c1-72 || true)
  [ -z "$subject" ] && subject="$fallback"
  printf '%s\n' "$subject"
}

# ---------------------------------------------------------------------------
# Safe-staging guardrails. Fail-closed for sensitive paths.
# RUN_PHASE_ALLOWLIST_REGEX restricts to a sub-tree.
# RUN_PHASE_FORCE_UNSAFE=1 bypasses refusal (NOT recommended).
# ---------------------------------------------------------------------------
RPL_SENSITIVE_PATTERNS_DEFAULT='((^|/)(\.env(\..+)?|\.envrc|\.netrc|\.npmrc|\.pypirc|\.pgpass|\.my\.cnf|\.kube/config|kubeconfig|credentials(\.json)?|secrets?(\.ya?ml|\.json|\.env)?|.*\.pem|.*\.key|.*\.p12|.*\.pfx|.*\.jks|.*\.keystore|.*\.crt|.*\.cer|id_rsa|id_dsa|id_ecdsa|id_ed25519|.*\.sqlite3?|.*\.db|.*\.mdb|.*\.dump|.*\.bak)$)|((^|/)(\.aws|\.azure|\.gcp|\.config/gcloud|\.ssh|\.gnupg)/)'

# Files that LOOK sensitive (match the pattern above) but are canonical
# safe placeholders that should be committed. These contain placeholder
# values only, by convention. Override via RPL_SAFE_PLACEHOLDER_PATTERNS.
RPL_SAFE_PLACEHOLDER_PATTERNS_DEFAULT='(^|/)\.env\.(example|sample|template)$'

rpl_session_changed_paths() {
  local rec records=() i=0 n code path skip_next=0
  while IFS= read -r -d '' rec; do
    records+=("$rec")
  done < <(git status --porcelain=v1 -z --untracked-files=normal)

  n=${#records[@]}
  while [ "$i" -lt "$n" ]; do
    rec="${records[i]}"
    if [ "$skip_next" = "1" ]; then
      printf '%s\0' "$rec"
      skip_next=0
    else
      code="${rec:0:2}"
      path="${rec:3}"
      case "$code" in
        R*|C*)
          printf '%s\0' "$path"
          skip_next=1
          ;;
        *)
          printf '%s\0' "$path"
          ;;
      esac
    fi
    i=$((i + 1))
  done
}

rpl_safe_stage() {
  local sensitive_re="${RPL_SENSITIVE_PATTERNS:-$RPL_SENSITIVE_PATTERNS_DEFAULT}"
  local safe_placeholder_re="${RPL_SAFE_PLACEHOLDER_PATTERNS:-$RPL_SAFE_PLACEHOLDER_PATTERNS_DEFAULT}"
  local allow_re="${RUN_PHASE_ALLOWLIST_REGEX:-}"
  local force_unsafe="${RUN_PHASE_FORCE_UNSAFE:-0}"

  local all_paths=() suspicious=() to_stage=() skipped_allow=()
  local p

  while IFS= read -r -d '' p; do
    [ -z "$p" ] && continue
    all_paths+=("$p")
  done < <(rpl_session_changed_paths)

  if [ ${#all_paths[@]} -eq 0 ]; then
    log "No session changes to stage."
    return 2
  fi

  for p in "${all_paths[@]}"; do
    if printf '%s' "$p" | grep -Eq "$sensitive_re"; then
      # A path that looks sensitive may still be a canonical safe
      # placeholder (.env.example, .env.sample, .env.template). Those are
      # by-convention safe to commit.
      if printf '%s' "$p" | grep -Eq "$safe_placeholder_re"; then
        to_stage+=("$p")
        continue
      fi
      suspicious+=("$p")
      continue
    fi
    if [ -n "$allow_re" ] && ! printf '%s' "$p" | grep -Eq "$allow_re"; then
      skipped_allow+=("$p")
      continue
    fi
    to_stage+=("$p")
  done

  if [ ${#suspicious[@]} -gt 0 ]; then
    err "Refusing to stage suspicious / sensitive paths:"
    for p in "${suspicious[@]}"; do err "     - $p"; done
    if [ "$force_unsafe" = "1" ]; then
      err "RUN_PHASE_FORCE_UNSAFE=1 set — staging anyway (NOT recommended)."
      to_stage+=("${suspicious[@]}")
    else
      err "    These look like secrets, credentials, keys, local DBs, or"
      err "    backups. Resolve the file (delete, .gitignore, or move to a"
      err "    secret store), then re-run. To override (NOT recommended),"
      err "    set RUN_PHASE_FORCE_UNSAFE=1."
      return 1
    fi
  fi

  if [ ${#skipped_allow[@]} -gt 0 ]; then
    log "RUN_PHASE_ALLOWLIST_REGEX skipped ${#skipped_allow[@]} path(s):"
    for p in "${skipped_allow[@]}"; do log "     - $p"; done
  fi

  if [ ${#to_stage[@]} -eq 0 ]; then
    log "Nothing left to stage after filtering."
    return 2
  fi

  log "Staging ${#to_stage[@]} session-changed path(s):"
  for p in "${to_stage[@]}"; do log "     + $p"; done

  git add -- "${to_stage[@]}"

  log "git status --short (staged + remaining):"
  git status --short | sed 's/^/     /'
  return 0
}

# ---------------------------------------------------------------------------
# rpl_commit_and_push — stage + commit + push with stop-on-push-failure.
# Args:
#   $1 subject       — commit subject (one line)
#   $2 log_path      — path to the handoff log (for commit body + on-fail msg)
# Exit codes:
#   0   committed (and pushed if push not disabled)
#   2   no changes to commit
#   1   push failed
# ---------------------------------------------------------------------------
rpl_commit_and_push() {
  local subject="$1"
  local log_path="$2"
  local script="${TOOL_SCRIPT:?TOOL_SCRIPT must be set}"

  rpl_safe_stage
  local stage_rc=$?
  if [ "$stage_rc" -eq 2 ]; then
    return 2
  fi
  if [ "$stage_rc" -ne 0 ]; then
    return "$stage_rc"
  fi

  if git diff --cached --quiet; then
    log "Nothing staged after safety filters; skipping commit."
    return 2
  fi

  git commit -m "$subject" \
             -m "Automated commit by $script. Log: $log_path"
  log "Committed: $subject"

  if [ "${RUN_PHASE_NO_PUSH:-0}" = "1" ] || [ "${SYNC_MODE:-immediate}" = "batch" ]; then
    log "RUN_PHASE_NO_PUSH=1 or SYNC_MODE=batch set — skipping push."
    return 0
  fi

  log "Pushing to origin..."
  if ! git push; then
    err ""
    err "Push failed (commit: $subject)."
    err "Stopping orchestrator run so the local branch does not drift from origin."
    err "Resolve the push (auth / network / non-fast-forward) and re-run."
    err "Log: $log_path"
    return 1
  fi
  log "Pushed to origin."
  return 0
}

# ---------------------------------------------------------------------------
# rpl_require_tool — fail fast if a CLI isn't on PATH.
# Usage: rpl_require_tool claude "npm install -g @anthropic-ai/claude-code" \
#                         "https://docs.anthropic.com/en/docs/claude-code"
# ---------------------------------------------------------------------------
rpl_require_tool() {
  local name="$1" install="$2" docs="$3"
  if ! command -v "$name" >/dev/null 2>&1; then
    err "error: '$name' not found."
    err "  Install: $install"
    err "  Docs:    $docs"
    exit 127
  fi
}

# ===========================================================================
# Factory-specific helpers below. These read or write TASKS.md / ESCALATIONS.md.
# ===========================================================================

# ---------------------------------------------------------------------------
# factory_extract_status_line — pull the last FACTORY_STATUS= JSON line from
# an adapter's stdout log.
# Usage: STATUS_JSON=$(factory_extract_status_line "$LOG_DIR/handoff.log")
# Returns empty string if no status line found.
# ---------------------------------------------------------------------------
factory_extract_status_line() {
  local log_file="$1"
  grep -E '^FACTORY_STATUS=' "$log_file" | tail -n 1 | sed 's/^FACTORY_STATUS=//' || true
}

# ---------------------------------------------------------------------------
# factory_next_action — read TASKS.md and report the next actionable item.
# Output format (one line, space-separated):
#   <role> <kind> <id>
# where:
#   role  = cursor | codex | claude | none
#   kind  = slice | phase-review
#   id    = slice number (e.g. 1.2) or phase number (e.g. 1)
# If no actionable item, prints "none none none".
#
# Priority (matches templates/project-skeleton/.claude/commands/next-slice.md):
#   1. Phase review with status awaiting-review → claude phase-review <N>
#   2. Slice with status awaiting-review        → codex slice <N.M>
#   3. Slice with status in-progress + sub-tasks → cursor slice <N.M>
#   4. Lowest-numbered pending slice            → cursor slice <N.M>
# ---------------------------------------------------------------------------
factory_next_action() {
  local tasks_file="${1:-TASKS.md}"
  if [ ! -f "$tasks_file" ]; then
    printf 'none none none\n'
    return
  fi
  python3 - "$tasks_file" <<'PYEOF'
import re
import sys

TASKS_FILE = sys.argv[1]
with open(TASKS_FILE, "r", encoding="utf-8") as f:
    raw = f.read()

# Strip fenced code blocks so example headings inside ```...``` are ignored.
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

text = strip_code_blocks(raw)

# Slice headings: ### N.M <name>
# Phase review headings: ### Phase N review
# Status line under a heading: `- Status: <value>` (possibly backticked)
slice_pat = re.compile(r"^###\s+(\d+\.\d+)\b", re.MULTILINE)
phase_review_pat = re.compile(r"^###\s+Phase\s+(\d+)\s+review\b", re.MULTILINE | re.IGNORECASE)
status_pat = re.compile(r"^-\s+Status:\s+`?([a-z\-]+)`?", re.MULTILINE | re.IGNORECASE)

# Find every heading position
items = []  # list of (line_start, kind, id)
for m in slice_pat.finditer(text):
    items.append((m.start(), "slice", m.group(1)))
for m in phase_review_pat.finditer(text):
    items.append((m.start(), "phase-review", m.group(1)))
items.sort(key=lambda t: t[0])

# For each heading, read the first status line in its body (before the next heading)
parsed = []
for i, (pos, kind, ident) in enumerate(items):
    body_end = items[i+1][0] if i + 1 < len(items) else len(text)
    body = text[pos:body_end]
    sm = status_pat.search(body)
    status = sm.group(1).lower() if sm else "pending"
    parsed.append((kind, ident, status))

# Priority 1: phase-review awaiting-review
for kind, ident, status in parsed:
    if kind == "phase-review" and status == "awaiting-review":
        print(f"claude phase-review {ident}")
        sys.exit(0)
# Priority 2: slice awaiting-review
for kind, ident, status in parsed:
    if kind == "slice" and status == "awaiting-review":
        print(f"codex slice {ident}")
        sys.exit(0)
# Priority 3: slice in-progress (Cursor either started it or is fixing sub-tasks)
for kind, ident, status in parsed:
    if kind == "slice" and status == "in-progress":
        print(f"cursor slice {ident}")
        sys.exit(0)
# Priority 4: lowest-numbered pending slice
for kind, ident, status in parsed:
    if kind == "slice" and status == "pending":
        print(f"cursor slice {ident}")
        sys.exit(0)
print("none none none")
PYEOF
}

# ---------------------------------------------------------------------------
# factory_update_status — set the Status line for a slice or phase-review.
# Args:
#   $1 tasks_file     — path to TASKS.md
#   $2 kind           — slice | phase-review
#   $3 id             — e.g. 1.2 or 1
#   $4 new_status     — e.g. in-progress, awaiting-review, approved, blocked
# ---------------------------------------------------------------------------
factory_update_status() {
  local tasks_file="$1" kind="$2" id="$3" new_status="$4"
  python3 - "$tasks_file" "$kind" "$id" "$new_status" <<'PYEOF'
import re
import sys

TASKS_FILE, KIND, IDENT, NEW = sys.argv[1:5]
with open(TASKS_FILE, "r", encoding="utf-8") as f:
    lines = f.readlines()

if KIND == "slice":
    heading_re = re.compile(rf"^###\s+{re.escape(IDENT)}\b")
elif KIND == "phase-review":
    heading_re = re.compile(rf"^###\s+Phase\s+{re.escape(IDENT)}\s+review\b", re.IGNORECASE)
else:
    sys.exit("kind must be slice or phase-review")

status_re = re.compile(r"^-\s+Status:\s+`?([a-z\-]+)`?", re.IGNORECASE)
next_heading_re = re.compile(r"^###\s")

out = []
in_target = False
applied = False
for line in lines:
    if heading_re.match(line):
        in_target = True
        out.append(line)
        continue
    if in_target and next_heading_re.match(line):
        in_target = False
    if in_target and not applied and status_re.match(line):
        line = f"- Status: `{NEW}`\n"
        applied = True
    out.append(line)

if not applied:
    sys.exit(f"could not find Status line for {KIND} {IDENT}")

with open(TASKS_FILE, "w", encoding="utf-8") as f:
    f.writelines(out)
PYEOF
}

# ---------------------------------------------------------------------------
# factory_increment_iterations — bump the Iterations counter for a slice or
# phase-review heading. Stops at the cap and returns 2 if cap reached.
# Args:
#   $1 tasks_file
#   $2 kind          — slice | phase-review
#   $3 id
#   $4 cap           — integer cap (e.g. 3)
# ---------------------------------------------------------------------------
factory_increment_iterations() {
  local tasks_file="$1" kind="$2" id="$3" cap="$4"
  python3 - "$tasks_file" "$kind" "$id" "$cap" <<'PYEOF'
import re
import sys

TASKS_FILE, KIND, IDENT, CAP = sys.argv[1:5]
cap = int(CAP)
with open(TASKS_FILE, "r", encoding="utf-8") as f:
    lines = f.readlines()

if KIND == "slice":
    heading_re = re.compile(rf"^###\s+{re.escape(IDENT)}\b")
elif KIND == "phase-review":
    heading_re = re.compile(rf"^###\s+Phase\s+{re.escape(IDENT)}\s+review\b", re.IGNORECASE)
else:
    sys.exit("kind must be slice or phase-review")

iter_re = re.compile(r"^-\s+Iterations:\s+(\d+)\s*/\s*(\d+)")
next_heading_re = re.compile(r"^###\s")

out = []
in_target = False
applied = False
result_rc = 0
for line in lines:
    if heading_re.match(line):
        in_target = True
        out.append(line)
        continue
    if in_target and next_heading_re.match(line):
        in_target = False
    if in_target and not applied:
        m = iter_re.match(line)
        if m:
            current = int(m.group(1)) + 1
            line = f"- Iterations: {current}/{cap}\n"
            applied = True
            if current >= cap:
                result_rc = 2
    out.append(line)

if not applied:
    sys.exit(f"could not find Iterations line for {KIND} {IDENT}")

with open(TASKS_FILE, "w", encoding="utf-8") as f:
    f.writelines(out)
sys.exit(result_rc)
PYEOF
}

# ---------------------------------------------------------------------------
# factory_check_iteration_cap — return 0 if the slice/phase-review still has
# iterations available, 2 if at or above the cap. Reads the Iterations line.
# Args:
#   $1 tasks_file
#   $2 kind          — slice | phase-review
#   $3 id
# ---------------------------------------------------------------------------
factory_check_iteration_cap() {
  local tasks_file="$1" kind="$2" id="$3"
  python3 - "$tasks_file" "$kind" "$id" <<'PYEOF'
import re
import sys

TASKS_FILE, KIND, IDENT = sys.argv[1:4]
with open(TASKS_FILE, "r", encoding="utf-8") as f:
    raw = f.read()

# Strip fenced code blocks so example headings inside ```...``` are ignored.
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

lines = (strip_code_blocks(raw) + "\n").splitlines(keepends=True)

if KIND == "slice":
    heading_re = re.compile(rf"^###\s+{re.escape(IDENT)}\b")
elif KIND == "phase-review":
    heading_re = re.compile(rf"^###\s+Phase\s+{re.escape(IDENT)}\s+review\b", re.IGNORECASE)
else:
    sys.exit("kind must be slice or phase-review")

iter_re = re.compile(r"^-\s+Iterations:\s+(\d+)\s*/\s*(\d+)")
next_heading_re = re.compile(r"^###\s")

in_target = False
for line in lines:
    if heading_re.match(line):
        in_target = True
        continue
    if in_target and next_heading_re.match(line):
        break
    if in_target:
        m = iter_re.match(line)
        if m:
            current, cap = int(m.group(1)), int(m.group(2))
            sys.exit(2 if current >= cap else 0)

# No iteration line found — treat as no cap yet.
sys.exit(0)
PYEOF
}

# ---------------------------------------------------------------------------
# factory_log_escalation — append a new entry to ESCALATIONS.md.
# Args:
#   $1 escalations_file
#   $2 agent      — cursor | codex | claude
#   $3 target     — e.g. "slice 1.2" or "Phase 1 review"
#   $4 reason     — iteration-cap-hit | judgment-call | secret-needed | external-dependency | other
#   $5 context    — one paragraph
#   $6 tried      — bullet text (use \n for line breaks)
#   $7 action     — recommended action
# ---------------------------------------------------------------------------
factory_log_escalation() {
  local file="$1" agent="$2" target="$3" reason="$4" context="$5" tried="$6" action="$7"
  python3 - "$file" "$agent" "$target" "$reason" "$context" "$tried" "$action" <<'PYEOF'
import re
import sys
from datetime import datetime

FILE, AGENT, TARGET, REASON, CONTEXT, TRIED, ACTION = sys.argv[1:8]

with open(FILE, "r", encoding="utf-8") as f:
    text = f.read()

# Next ID
ids = [int(m.group(1)) for m in re.finditer(r"^### ESC-(\d{3}):", text, re.MULTILINE)]
next_id = max(ids) + 1 if ids else 1
esc_id = f"ESC-{next_id:03d}"

today = datetime.utcnow().strftime("%Y-%m-%d")
entry = (
    f"\n### {esc_id}: {TARGET} — {REASON}\n\n"
    f"- Created: {today}\n"
    f"- From: {AGENT}\n"
    f"- Phase/Slice: {TARGET}\n"
    f"- Reason: {REASON}\n"
    f"- Context: {CONTEXT}\n"
    f"- What was tried: {TRIED}\n"
    f"- Recommended action: {ACTION}\n"
    f"- Status: open\n"
)

# Insert under the "## Open" section, before the next "## " heading.
open_re = re.compile(r"(^## Open\s*$)", re.MULTILINE)
m = open_re.search(text)
if m:
    after_open = m.end()
    # Find the next "## " heading after this point.
    next_h2 = re.search(r"^## ", text[after_open:], re.MULTILINE)
    insert_at = after_open + (next_h2.start() if next_h2 else len(text) - after_open)
    new_text = text[:insert_at].rstrip() + "\n" + entry + "\n" + text[insert_at:]
else:
    # No "## Open" section found; append to end.
    new_text = text.rstrip() + "\n" + entry

with open(FILE, "w", encoding="utf-8") as f:
    f.write(new_text)

print(esc_id)
PYEOF
}
