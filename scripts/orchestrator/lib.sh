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
  # Take the LAST "Work completed:" line in the log, not the first. The
  # adapter prompts contain example "Work completed:" lines for the AI to
  # follow; those appear early in the log (as the prompt is tee'd in)
  # while the AI's actual completion line is at the end. Last-match-wins
  # picks the AI's real answer.
  subject=$(awk '
    /Work completed/ {
      line = $0
      gsub(/`/, "", line)
      gsub(/\*/, "", line)
      sub(/^[[:space:]]*[-][[:space:]]*/, "", line)
      sub(/^Work completed[[:space:]]*/, "", line)
      sub(/^[^[:alnum:]]+[[:space:]]*/, "", line)
      if (length(line) > 0) { subject = line; inheader = 0; next }
      inheader = 1
      next
    }
    inheader && /^[[:space:]]*$/ { next }
    inheader {
      sub(/^[*-][[:space:]]*/, "")
      subject = $0
      inheader = 0
    }
    END { if (length(subject) > 0) print subject }
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
# rpl_git_push_retry — git push with a bounded retry on transient failures
# (network blips, brief auth refresh). Retries RUN_PHASE_PUSH_RETRIES times
# (default 2) with linear backoff. A genuine non-fast-forward exhausts the
# retries and still fails, which is intended (the caller halts). Args: extra
# `git push` args (e.g. origin main). Returns the final push exit status.
# ---------------------------------------------------------------------------
rpl_git_push_retry() {
  local tries="${RUN_PHASE_PUSH_RETRIES:-2}" i=0 backoff
  while :; do
    if git push "$@"; then
      return 0
    fi
    i=$((i + 1))
    if [ "$i" -gt "$tries" ]; then
      return 1
    fi
    backoff=$((i * 5))
    err "git push failed (attempt $i of $tries); retrying in ${backoff}s..."
    sleep "$backoff"
  done
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
  if ! rpl_git_push_retry; then
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
#
# Uses `grep -a` because adapter logs occasionally contain non-text bytes
# (ANSI escape codes, crash-reporter output, headless-browser stderr).
# Without -a, grep reports "Binary file matches" instead of the matched
# line and the extraction silently returns empty — see test-marketing-site
# slice 2.1 review for the bug that motivated this fix.
# ---------------------------------------------------------------------------
factory_extract_status_line() {
  local log_file="$1"
  grep -aE '^FACTORY_STATUS=' "$log_file" | tail -n 1 | sed 's/^FACTORY_STATUS=//' || true
}

# ---------------------------------------------------------------------------
# factory_adapter_for — map an orchestrator (role, kind) pair to its adapter
# script basename. Echoes the empty string for an unknown combination so the
# caller decides how to handle it (orchestrate.sh halts; factory.sh reports).
#
# This is the single source of truth for the dispatch map. Both
# scripts/orchestrator/orchestrate.sh and scripts/factory.sh call it, so the
# two cannot drift — the failure ADR-0012's follow-up called out (a launcher
# that confidently points at the wrong adapter after a refactor).
#
# Usage: factory_adapter_for <role> <kind>   # echoes "<adapter>.sh" or ""
# ---------------------------------------------------------------------------
factory_adapter_for() {
  case "$1-$2" in
    cursor-slice)                 echo "cursor-slice.sh" ;;
    codex-slice)                  echo "codex-slice-review.sh" ;;
    codex-slice-verify)           echo "codex-slice-verify.sh" ;;
    claude-phase-review)          echo "claude-phase-review.sh" ;;
    security-phase-security)      echo "security-phase-review.sh" ;;
    codereview-phase-code-review) echo "codereview-phase-review.sh" ;;
    orchestrator-gate-d-signoff)  echo "gate-d-signoff.sh" ;;
    *)                            echo "" ;;
  esac
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
# Priority order (Owner-aware for in-progress/pending slices):
#   1. Phase review with status awaiting-review → claude phase-review <N>
#   2. Slice with status awaiting-review        → codex slice <N.M>  (review)
#   3. Slice in-progress → its Owner (codex → verify; cursor/unset → cursor)
#   4. Lowest-numbered pending slice → its Owner (codex → verify; cursor/unset → cursor)
#   5. Every phase review approved + SIGNOFF.md pristine → orchestrator gate-d-signoff -
#
# Owner routing for kinds 3-4: codex → "codex slice-verify"; cursor/unset →
# "cursor slice". Only cursor and codex are valid slice owners — any other
# value (e.g. claude) is treated as an architect error: warn loudly and fall
# back to cursor. awaiting-review (kind 2) always goes to Codex review.
# ---------------------------------------------------------------------------
factory_next_action() {
  local tasks_file="${1:-TASKS.md}"
  local signoff_file="${2:-}"
  if [ -z "$signoff_file" ]; then
    signoff_file="$(dirname -- "$tasks_file")/SIGNOFF.md"
  fi
  if [ ! -f "$tasks_file" ]; then
    printf 'none none none\n'
    return
  fi
  local signoff_state="missing"
  if [ -f "$signoff_file" ]; then
    signoff_state=$(factory_signoff_state "$signoff_file")
  fi
  python3 - "$tasks_file" "$signoff_state" <<'PYEOF'
import re
import sys

TASKS_FILE = sys.argv[1]
SIGNOFF_STATE = sys.argv[2] if len(sys.argv) > 2 else "missing"
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
phase_security_pat = re.compile(r"^###\s+Phase\s+(\d+)\s+security\b", re.MULTILINE | re.IGNORECASE)
phase_code_review_pat = re.compile(r"^###\s+Phase\s+(\d+)\s+code-review\b", re.MULTILINE | re.IGNORECASE)
status_pat = re.compile(r"^-\s+Status:\s+`?([a-z\-]+)`?", re.MULTILINE | re.IGNORECASE)
owner_pat = re.compile(r"^-\s+Owner:\s*`?([a-zA-Z\-]+)`?", re.MULTILINE | re.IGNORECASE)

# Find every heading position
items = []  # list of (line_start, kind, id)
for m in slice_pat.finditer(text):
    items.append((m.start(), "slice", m.group(1)))
for m in phase_review_pat.finditer(text):
    items.append((m.start(), "phase-review", m.group(1)))
for m in phase_security_pat.finditer(text):
    items.append((m.start(), "phase-security", m.group(1)))
for m in phase_code_review_pat.finditer(text):
    items.append((m.start(), "phase-code-review", m.group(1)))
items.sort(key=lambda t: t[0])

# For each heading, read the first Status (and, for slices, Owner) line in its
# body (before the next heading).
parsed = []
for i, (pos, kind, ident) in enumerate(items):
    body_end = items[i+1][0] if i + 1 < len(items) else len(text)
    body = text[pos:body_end]
    sm = status_pat.search(body)
    status = sm.group(1).lower() if sm else "pending"
    om = owner_pat.search(body)
    owner = om.group(1).lower() if om else ""
    parsed.append((kind, ident, status, owner))


def route_owner(owner):
    # Owner-aware routing for slices that are pending or in-progress. Only
    # cursor and codex are valid slice owners; anything else (e.g. claude) is
    # an architect mistake, not a workflow — warn loudly and fall back to cursor.
    if owner == "codex":
        return "codex slice-verify"
    if owner not in ("cursor", ""):
        sys.stderr.write(
            f"factory_next_action: WARNING: Owner '{owner}' is not routable "
            f"(only cursor and codex are valid slice owners). This usually means "
            f"the architect set the Owner in error; falling back to cursor. Fix "
            f"the Owner for this slice in TASKS.md.\n"
        )
    return "cursor slice"


# Priority 1: phase-review awaiting-review -> architect reviews the phase.
for kind, ident, status, owner in parsed:
    if kind == "phase-review" and status == "awaiting-review":
        print(f"claude phase-review {ident}")
        sys.exit(0)
# Priority 1b: phase-security awaiting-review -> security reviews the phase
# (ADR-0013). Runs after the architect's phase review is approved; blocks.
for kind, ident, status, owner in parsed:
    if kind == "phase-security" and status == "awaiting-review":
        print(f"security phase-security {ident}")
        sys.exit(0)
# Priority 1c: phase-code-review awaiting-review -> code-review reviews the
# phase (ADR-0013). Runs after the security gate is approved; blocks.
for kind, ident, status, owner in parsed:
    if kind == "phase-code-review" and status == "awaiting-review":
        print(f"codereview phase-code-review {ident}")
        sys.exit(0)
# Priority 2: slice awaiting-review -> Codex reviews it (always, ignoring Owner).
for kind, ident, status, owner in parsed:
    if kind == "slice" and status == "awaiting-review":
        print(f"codex slice {ident}")
        sys.exit(0)
# Priority 3: slice in-progress -> its Owner (default cursor).
for kind, ident, status, owner in parsed:
    if kind == "slice" and status == "in-progress":
        print(f"{route_owner(owner)} {ident}")
        sys.exit(0)
# Priority 4: lowest-numbered pending slice -> its Owner (default cursor).
for kind, ident, status, owner in parsed:
    if kind == "slice" and status == "pending":
        print(f"{route_owner(owner)} {ident}")
        sys.exit(0)
# Priority 5: Gate D. Every phase's gates (review, plus security and
# code-review when present) must be approved, and SIGNOFF.md must still be in
# its pristine template state (no agent has signed) -> run the Gate D sign-off
# adapter. A gate that is absent on an older project counts as satisfied, so
# projects scaffolded before ADR-0013 still reach Gate D. Once an agent has
# signed, SIGNOFF_STATE is no longer "pristine" and this does not fire again.
gate_kinds = ("phase-review", "phase-security", "phase-code-review")
gate_status = {}  # (ident, kind) -> status
for kind, ident, status, owner in parsed:
    if kind in gate_kinds:
        gate_status[(ident, kind)] = status
phase_ids = sorted({i for (i, _k) in gate_status}, key=int)


def gate_ok(ident, kind):
    # Absent gate (older project) counts as satisfied; present gate must be approved.
    return gate_status.get((ident, kind), "approved") == "approved"


all_phases_approved = bool(phase_ids) and all(
    gate_status.get((p, "phase-review"), "missing") == "approved"
    and gate_ok(p, "phase-security")
    and gate_ok(p, "phase-code-review")
    for p in phase_ids
)
if all_phases_approved and SIGNOFF_STATE == "pristine":
    print("orchestrator gate-d-signoff -")
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
elif KIND == "phase-security":
    heading_re = re.compile(rf"^###\s+Phase\s+{re.escape(IDENT)}\s+security\b", re.IGNORECASE)
elif KIND == "phase-code-review":
    heading_re = re.compile(rf"^###\s+Phase\s+{re.escape(IDENT)}\s+code-review\b", re.IGNORECASE)
else:
    sys.exit("kind must be slice, phase-review, phase-security, or phase-code-review")

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
elif KIND == "phase-security":
    heading_re = re.compile(rf"^###\s+Phase\s+{re.escape(IDENT)}\s+security\b", re.IGNORECASE)
elif KIND == "phase-code-review":
    heading_re = re.compile(rf"^###\s+Phase\s+{re.escape(IDENT)}\s+code-review\b", re.IGNORECASE)
else:
    sys.exit("kind must be slice, phase-review, phase-security, or phase-code-review")

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
elif KIND == "phase-security":
    heading_re = re.compile(rf"^###\s+Phase\s+{re.escape(IDENT)}\s+security\b", re.IGNORECASE)
elif KIND == "phase-code-review":
    heading_re = re.compile(rf"^###\s+Phase\s+{re.escape(IDENT)}\s+code-review\b", re.IGNORECASE)
else:
    sys.exit("kind must be slice, phase-review, phase-security, or phase-code-review")

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

# ---------------------------------------------------------------------------
# factory_all_phases_approved — exit 0 if TASKS.md has at least one
# "### Phase N review" entry AND every one of them has Status: approved.
# Exit 1 otherwise (including when there are no phase-review entries at all).
# Fenced code blocks are stripped so example headings do not count.
# Args: $1 tasks_file (default TASKS.md)
# ---------------------------------------------------------------------------
factory_all_phases_approved() {
  local tasks_file="${1:-TASKS.md}"
  [ -f "$tasks_file" ] || return 1
  python3 - "$tasks_file" <<'PYEOF'
import re
import sys

with open(sys.argv[1], "r", encoding="utf-8") as f:
    raw = f.read()

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
heading_re = re.compile(r"^###\s", re.MULTILINE)
phase_review_re = re.compile(r"^###\s+Phase\s+(\d+)\s+review\b", re.MULTILINE | re.IGNORECASE)
phase_security_re = re.compile(r"^###\s+Phase\s+(\d+)\s+security\b", re.MULTILINE | re.IGNORECASE)
phase_code_review_re = re.compile(r"^###\s+Phase\s+(\d+)\s+code-review\b", re.MULTILINE | re.IGNORECASE)
status_re = re.compile(r"^-\s+Status:\s+`?([a-z\-]+)`?", re.MULTILINE | re.IGNORECASE)

heads = [m.start() for m in heading_re.finditer(text)]

def body_after(pos):
    nxt = min([h for h in heads if h > pos], default=len(text))
    return text[pos:nxt]

def status_at(m):
    sm = status_re.search(body_after(m.start()))
    return sm.group(1).lower() if sm else "pending"

# The architect phase reviews are mandatory: at least one must exist and all
# must be approved. The security and code-review gates (ADR-0013) are also
# required when present; absent on an older project means "not gated here".
reviews = list(phase_review_re.finditer(text))
if not reviews:
    sys.exit(1)
for m in reviews:
    if status_at(m) != "approved":
        sys.exit(1)
for rx in (phase_security_re, phase_code_review_re):
    for m in rx.finditer(text):
        if status_at(m) != "approved":
            sys.exit(1)
sys.exit(0)
PYEOF
}

# ---------------------------------------------------------------------------
# factory_signoff_state — classify a project's SIGNOFF.md by how many of the
# four Gate D sign-off sections are filled. Prints one of:
#   missing       — no SIGNOFF.md file
#   pristine      — unchanged template; no party has signed
#   agents-signed — architect + developer + QE filled, product owner not
#   complete      — all four sections filled
#   partial       — some other combination (e.g. a sub-session failed midway)
# A section counts as "filled" only when its date placeholder (YYYY-MM-DD) is
# gone AND its Decision line no longer shows the pipe-delimited option list.
# Args: $1 signoff_file (default SIGNOFF.md). Always exits 0.
# ---------------------------------------------------------------------------
factory_signoff_state() {
  local signoff_file="${1:-SIGNOFF.md}"
  if [ ! -f "$signoff_file" ]; then
    printf 'missing\n'
    return 0
  fi
  python3 - "$signoff_file" <<'PYEOF'
import re
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    text = fh.read().replace("\r\n", "\n")

lines = text.split("\n")
# Headings are role-anchored and tool-agnostic (ADR-0013): the optional
# "(Tool)" suffix is accepted so SIGNOFF.md files written before the rename
# ("## Architect (Claude) sign-off") still classify.
sections = [
    ("architect",   r"^##\s+Architect(\s+\([^)]*\))?\s+sign-off\s*$"),
    ("developer",   r"^##\s+Developer(\s+\([^)]*\))?\s+sign-off\s*$"),
    ("qe",          r"^##\s+Quality Engineer(\s+\([^)]*\))?\s+sign-off\s*$"),
    ("security",    r"^##\s+Security(\s+\([^)]*\))?\s+sign-off\s*$"),
    ("code_review", r"^##\s+Code Review(\s+\([^)]*\))?\s+sign-off\s*$"),
    ("po",          r"^##\s+Product owner / technical owner sign-off\s*$"),
]

def section_body(start):
    end = len(lines)
    for j in range(start + 1, len(lines)):
        if re.match(r"^##\s", lines[j]):
            end = j
            break
    return "\n".join(lines[start:end])

present = {}
filled = {}
for name, pat in sections:
    rx = re.compile(pat, re.IGNORECASE)
    start = next((i for i, ln in enumerate(lines) if rx.match(ln)), None)
    if start is None:
        present[name] = False
        filled[name] = False
        continue
    present[name] = True
    body = section_body(start)
    unfilled = ("YYYY-MM-DD" in body) or bool(
        re.search(r"^\*\*Decision:\*\*.*\|", body, re.MULTILINE)
    )
    if name == "po" and "name (product owner)" in body:
        unfilled = True
    filled[name] = not unfilled

# The agent sign-offs are the five non-PO sections. A section that is absent
# (a project scaffolded before ADR-0013 added the Security and Code Review
# sign-offs) is simply not part of this project's required set.
agent_keys = ["architect", "developer", "qe", "security", "code_review"]
agents = [filled[k] for k in agent_keys if present[k]]
po = filled["po"]
if not any(agents) and not po:
    print("pristine")
elif agents and all(agents) and po:
    print("complete")
elif agents and all(agents) and not po:
    print("agents-signed")
else:
    print("partial")
PYEOF
}

# ---------------------------------------------------------------------------
# factory_item_status — print the Status value of one slice or phase-review
# from TASKS.md (lowercased, no backticks). Prints empty string if not found.
# Fenced code blocks are stripped so example headings do not match.
# Args: $1 tasks_file, $2 kind (slice|phase-review), $3 id
# ---------------------------------------------------------------------------
factory_item_status() {
  local tasks_file="$1" kind="$2" id="$3"
  python3 - "$tasks_file" "$kind" "$id" <<'PYEOF'
import re
import sys

TASKS_FILE, KIND, IDENT = sys.argv[1:4]
with open(TASKS_FILE, "r", encoding="utf-8") as f:
    raw = f.read()

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
if KIND == "slice":
    heading_re = re.compile(rf"^###\s+{re.escape(IDENT)}\b")
elif KIND == "phase-review":
    heading_re = re.compile(rf"^###\s+Phase\s+{re.escape(IDENT)}\s+review\b", re.IGNORECASE)
elif KIND == "phase-security":
    heading_re = re.compile(rf"^###\s+Phase\s+{re.escape(IDENT)}\s+security\b", re.IGNORECASE)
elif KIND == "phase-code-review":
    heading_re = re.compile(rf"^###\s+Phase\s+{re.escape(IDENT)}\s+code-review\b", re.IGNORECASE)
else:
    print("")
    sys.exit(0)

status_re = re.compile(r"^-\s+Status:\s+`?([a-z\-]+)`?", re.IGNORECASE)
next_heading_re = re.compile(r"^###\s")

in_target = False
for line in (text + "\n").splitlines():
    if heading_re.match(line):
        in_target = True
        continue
    if in_target and next_heading_re.match(line):
        break
    if in_target:
        m = status_re.match(line)
        if m:
            print(m.group(1).lower())
            sys.exit(0)
print("")
PYEOF
}

# ---------------------------------------------------------------------------
# _factory_push_main — best-effort push of the main branch after a fast-forward.
# Respects RUN_PHASE_NO_PUSH and SYNC_MODE=batch; skips silently if there is no
# 'origin' remote. A push failure is non-fatal: local main already points at
# the final state, so warn and continue. Always returns 0.
# ---------------------------------------------------------------------------
_factory_push_main() {
  if [ "${RUN_PHASE_NO_PUSH:-0}" = "1" ] || [ "${SYNC_MODE:-immediate}" = "batch" ]; then
    log "factory_advance_main: RUN_PHASE_NO_PUSH/SYNC_MODE set — not pushing main."
    return 0
  fi
  if ! git remote get-url origin >/dev/null 2>&1; then
    log "factory_advance_main: no 'origin' remote — main advanced locally only."
    return 0
  fi
  if rpl_git_push_retry origin main; then
    log "factory_advance_main: pushed main to origin."
  else
    err "factory_advance_main: 'git push origin main' failed (non-fatal). origin/main is behind; push it manually when able."
  fi
  return 0
}

# ---------------------------------------------------------------------------
# factory_advance_main — fast-forward the project's main branch to the current
# branch's HEAD at a clean phase/Gate boundary, then return to the current
# branch. Never force-pushes: if the fast-forward fails (main has diverged) it
# writes a factory_advance_main_failed escalation and returns 1 so the caller
# can halt.
# Args: $1 log_dir (for the escalation log; default ".")
# Returns: 0 advanced or already current (or safely skipped); 1 FF failed.
# ---------------------------------------------------------------------------
factory_advance_main() {
  local log_dir="${1:-.}"
  local current
  current=$(git symbolic-ref --quiet --short HEAD || true)

  if [ -z "$current" ]; then
    err "factory_advance_main: detached HEAD; cannot advance main. Skipping."
    return 0
  fi
  if [ "$current" = "main" ]; then
    return 0
  fi
  # Refuse to switch branches with a dirty tree — switching could carry or lose
  # uncommitted work. Adapters commit before returning, so this should be clean.
  if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
    err "factory_advance_main: working tree has uncommitted tracked changes; skipping main fast-forward. Commit them and re-run to advance main."
    return 0
  fi

  if ! git rev-parse --verify --quiet main >/dev/null 2>&1; then
    err "factory_advance_main: no 'main' branch; creating it at the current HEAD ($current)."
    git branch main
    _factory_push_main
    return 0
  fi

  log "factory_advance_main: fast-forwarding main to $current."
  git checkout main
  if git merge --ff-only "$current"; then
    _factory_push_main
    git checkout "$current"
    log "factory_advance_main: main is now at the $current HEAD."
    return 0
  fi

  # Fast-forward rejected — main has diverged. Do NOT force. Restore and escalate.
  git merge --abort >/dev/null 2>&1 || true
  git checkout "$current"
  err "factory_advance_main: fast-forward of main from $current failed (main has diverged)."
  factory_log_escalation ESCALATIONS.md "orchestrator" "factory_advance_main_failed" "judgment-call" \
    "Could not fast-forward main to ${current}. main has commits that are not on ${current}, so a --ff-only merge is impossible, and the orchestrator never force-pushes." \
    "Tried: git checkout main && git merge --ff-only ${current}; it was rejected as a non-fast-forward." \
    "Someone pushed to main directly, or two runs diverged. Reconcile main and ${current} by hand (inspect 'git log main ^${current}'), then re-run." \
    >>"$log_dir/advance_main.log" 2>/dev/null || true
  return 1
}

# ---------------------------------------------------------------------------
# factory_is_last_slice_in_phase — exit 0 if EVERY slice in the same phase as
# the given slice id is approved (i.e. this approval completes the phase),
# exit 1 otherwise. The phase is the part of the id before the dot (3.4 -> 3).
# Fenced code blocks are stripped so example slices do not count.
# Args: $1 tasks_file, $2 slice_id (e.g. 3.4)
# ---------------------------------------------------------------------------
factory_is_last_slice_in_phase() {
  local tasks_file="$1" slice_id="$2"
  python3 - "$tasks_file" "$slice_id" <<'PYEOF'
import re
import sys

TASKS_FILE, SLICE = sys.argv[1:3]
phase = SLICE.split(".")[0]
with open(TASKS_FILE, "r", encoding="utf-8") as f:
    raw = f.read()

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
slice_re = re.compile(r"^###\s+(\d+)\.(\d+)\b", re.MULTILINE)
status_re = re.compile(r"^-\s+Status:\s+`?([a-z\-]+)`?", re.MULTILINE | re.IGNORECASE)
heading_re = re.compile(r"^###\s", re.MULTILINE)
heads = [m.start() for m in heading_re.finditer(text)]

def body_after(pos):
    nxt = min([h for h in heads if h > pos], default=len(text))
    return text[pos:nxt]

slices = [m for m in slice_re.finditer(text) if m.group(1) == phase]
if not slices:
    sys.exit(1)
for m in slices:
    sm = status_re.search(body_after(m.start()))
    status = sm.group(1).lower() if sm else "pending"
    if status != "approved":
        sys.exit(1)
sys.exit(0)
PYEOF
}

# ---------------------------------------------------------------------------
# factory_set_phase_review_awaiting — set the "### Phase N review" Status to
# awaiting-review, but ONLY when it is currently pending (so an already
# approved / in-progress / human-needed review is never downgraded). No-op and
# success if the review is in any other state or absent. Idempotent.
# Args: $1 tasks_file, $2 phase number
# ---------------------------------------------------------------------------
factory_set_phase_review_awaiting() {
  local tasks_file="$1" phase="$2"
  factory_set_phase_item_awaiting "$tasks_file" phase-review "$phase"
}

# ---------------------------------------------------------------------------
# factory_set_phase_item_awaiting — set a phase gate (phase-review,
# phase-security, or phase-code-review) to awaiting-review, but ONLY when it is
# currently pending, so an approved / in-progress / human-needed gate is never
# downgraded. No-op and success if the gate is in any other state or absent
# (an older project may not have the security/code-review gates). Idempotent.
# This is what chains the gates: review approved -> set security awaiting;
# security approved -> set code-review awaiting (ADR-0013).
# Args: $1 tasks_file, $2 kind (phase-review|phase-security|phase-code-review),
#       $3 phase number
# ---------------------------------------------------------------------------
factory_set_phase_item_awaiting() {
  local tasks_file="$1" kind="$2" phase="$3"
  local cur
  cur=$(factory_item_status "$tasks_file" "$kind" "$phase")
  if [ "$cur" = "pending" ]; then
    factory_update_status "$tasks_file" "$kind" "$phase" "awaiting-review"
  fi
  return 0
}

# ---------------------------------------------------------------------------
# factory_phase_fully_approved — exit 0 if a phase is complete across ALL of its
# gates: the architect review (mandatory) plus the security and code-review
# gates (ADR-0013) when those headings exist. A gate that is absent counts as
# satisfied, so a phase on an older single-gate project is "fully approved" once
# its review is approved. Exit 1 if the phase has no review gate or any present
# gate is not approved. Fenced code blocks are stripped.
# Args: $1 tasks_file, $2 phase number
# ---------------------------------------------------------------------------
factory_phase_fully_approved() {
  local tasks_file="$1" phase="$2"
  [ -f "$tasks_file" ] || return 1
  python3 - "$tasks_file" "$phase" <<'PYEOF'
import re
import sys

TASKS_FILE, PHASE = sys.argv[1:3]
with open(TASKS_FILE, "r", encoding="utf-8") as f:
    raw = f.read()


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
heads = [m.start() for m in re.finditer(r"^###\s", text, re.MULTILINE)]
status_re = re.compile(r"^-\s+Status:\s+`?([a-z\-]+)`?", re.MULTILINE | re.IGNORECASE)


def body_after(pos):
    nxt = min([h for h in heads if h > pos], default=len(text))
    return text[pos:nxt]


def gate_status(word):
    rx = re.compile(rf"^###\s+Phase\s+{re.escape(PHASE)}\s+{word}\b", re.MULTILINE | re.IGNORECASE)
    m = rx.search(text)
    if not m:
        return None
    sm = status_re.search(body_after(m.start()))
    return sm.group(1).lower() if sm else "pending"


if gate_status("review") is None:
    sys.exit(1)  # not a recognized phase (no architect review gate)
for word in ("review", "security", "code-review"):
    st = gate_status(word)
    if st is not None and st != "approved":
        sys.exit(1)
sys.exit(0)
PYEOF
}

# ---------------------------------------------------------------------------
# factory_resolve_escalations_for_slice — move any OPEN escalations in a
# project's ESCALATIONS.md whose Phase/Slice matches the given id from the
# "## Open" section to the "## Resolved" section, flipping Status to resolved
# and appending a "- Resolved: <date> — ..." line. Idempotent: only OPEN
# entries are scanned, so a second call is a no-op (the file is left untouched
# when nothing matches). A slice id (contains a dot, e.g. 3.4) matches the
# slice token; a bare phase number (e.g. 3) matches "phase" entries only.
# Args: $1 project_path (dir containing ESCALATIONS.md), $2 id
# Always returns 0 (resolution is best-effort).
# ---------------------------------------------------------------------------
factory_resolve_escalations_for_slice() {
  local project_path="$1" id="$2"
  local esc_file="$project_path/ESCALATIONS.md"
  [ -f "$esc_file" ] || return 0
  python3 - "$esc_file" "$id" <<'PYEOF'
import re
import sys
from datetime import datetime


def main():
    esc_file, ident = sys.argv[1], sys.argv[2]
    today = datetime.now().strftime("%Y-%m-%d")
    is_slice = "." in ident

    with open(esc_file, "r", encoding="utf-8") as f:
        text = f.read()
    nl = "\r\n" if "\r\n" in text else "\n"
    lines = text.replace("\r\n", "\n").split("\n")

    def find_h2(rx_str, start=0):
        rx = re.compile(rx_str)
        for i in range(start, len(lines)):
            if rx.match(lines[i]):
                return i
        return -1

    open_idx = find_h2(r"^##\s+Open\b")
    resolved_idx = find_h2(r"^##\s+Resolved\b")
    if open_idx == -1 or resolved_idx == -1 or resolved_idx <= open_idx:
        return  # structure not as expected; leave the file untouched

    after_resolved_idx = len(lines)
    for i in range(resolved_idx + 1, len(lines)):
        if re.match(r"^##\s", lines[i]):
            after_resolved_idx = i
            break

    head = lines[:open_idx + 1]
    open_body = lines[open_idx + 1:resolved_idx]
    resolved_heading = lines[resolved_idx]
    resolved_body = lines[resolved_idx + 1:after_resolved_idx]
    tail = lines[after_resolved_idx:]

    def parse_blocks(body):
        blocks, i, n = [], 0, len(body)
        while i < n:
            if re.match(r"^###\s+ESC-", body[i]):
                blk = [body[i]]
                j = i + 1
                while (j < n and not re.match(r"^###\s", body[j])
                       and not re.match(r"^##\s", body[j])
                       and body[j].strip() != "---"):
                    blk.append(body[j])
                    j += 1
                while blk and blk[-1].strip() == "":
                    blk.pop()
                blocks.append(blk)
                i = j
            else:
                i += 1
        return blocks

    def field(blk, label):
        rx = re.compile(r"^-\s+" + re.escape(label) + r":\s*(.*)$")
        for line in blk:
            m = rx.match(line)
            if m:
                return m.group(1).strip()
        return None

    def matches(value):
        if not value:
            return False
        token = re.search(r"(?<!\d)" + re.escape(ident) + r"(?!\d)", value)
        if is_slice:
            return token is not None
        return ("phase" in value.lower()) and token is not None

    open_blocks = parse_blocks(open_body)
    resolved_blocks = parse_blocks(resolved_body)

    kept, newly_resolved = [], []
    kind = "slice" if is_slice else "phase"
    for blk in open_blocks:
        status = field(blk, "Status")
        if matches(field(blk, "Phase/Slice")) and status and status.lower() == "open":
            nb = []
            for line in blk:
                if re.match(r"^-\s+Status:\s*open\s*$", line, re.IGNORECASE):
                    line = "- Status: resolved"
                nb.append(line)
            nb.append(f"- Resolved: {today} — {kind} {ident} now approved")
            newly_resolved.append(nb)
        else:
            kept.append(blk)

    if not newly_resolved:
        return  # nothing matched; leave the file untouched (idempotent)

    all_resolved = resolved_blocks + newly_resolved

    out = list(head) + [""]
    for k, blk in enumerate(kept):
        if k:
            out.append("")
        out.extend(blk)
    out += ["", resolved_heading, ""]
    if all_resolved:
        for k, blk in enumerate(all_resolved):
            if k:
                out.append("")
            out.extend(blk)
    else:
        out.append("(No resolved escalations yet.)")
    out.append("")
    out.extend(tail)

    # Collapse runs of blank lines and trim to a single trailing newline.
    final, prev_blank = [], False
    for line in out:
        blank = (line.strip() == "")
        if blank and prev_blank:
            continue
        final.append(line)
        prev_blank = blank
    while final and final[-1].strip() == "":
        final.pop()

    with open(esc_file, "w", encoding="utf-8", newline="") as f:
        f.write(nl.join(final) + nl)


try:
    main()
except Exception as exc:  # never let escalation cleanup break the run
    sys.stderr.write(f"factory_resolve_escalations_for_slice: skipped ({exc})\n")
sys.exit(0)
PYEOF
}

# ---------------------------------------------------------------------------
# factory_phase_numbers — print the distinct phase numbers that have a
# "### Phase N review" entry in TASKS.md, one per line in document order.
# Fenced code blocks are stripped. Args: $1 tasks_file (default TASKS.md)
# ---------------------------------------------------------------------------
factory_phase_numbers() {
  local tasks_file="${1:-TASKS.md}"
  [ -f "$tasks_file" ] || return 0
  python3 - "$tasks_file" <<'PYEOF'
import re
import sys

seen = []
in_fence = False
for line in open(sys.argv[1], encoding="utf-8"):
    if line.startswith("```"):
        in_fence = not in_fence
        continue
    if in_fence:
        continue
    m = re.match(r"^###\s+Phase\s+(\d+)\s+review\b", line, re.IGNORECASE)
    if m and m.group(1) not in seen:
        seen.append(m.group(1))
print("\n".join(seen))
PYEOF
}

# ---------------------------------------------------------------------------
# factory_strip_log_noise — drop lines that reference node_modules/ from an
# on-disk adapter log. A deep grep through node_modules/ (e.g. iconv-lite CJK
# encoding tables) can bloat a work.log to multiple MB of useless noise. Call
# this only AFTER the FACTORY_STATUS line and the commit subject have been
# parsed from the log, never on the live stream. Best-effort; uses grep -a so
# binary-tagged logs are handled. Args: $1 log_file. Always returns 0.
# ---------------------------------------------------------------------------
factory_strip_log_noise() {
  local log_file="$1"
  [ -f "$log_file" ] || return 0
  local tmp="${log_file}.stripped"
  grep -av 'node_modules/' "$log_file" >"$tmp" 2>/dev/null || true
  if [ -s "$tmp" ]; then
    mv -f "$tmp" "$log_file"
  else
    rm -f "$tmp"
  fi
  return 0
}

# ===========================================================================
# Tool registry + per-project role configuration (ADR-0013).
#
# The factory builds apps; each app's delivery team is FIVE roles, and any of
# the four supported tools can fill any role, per project. The role->tool->name
# mapping lives in the project's .factory-roles.json (written at scaffold,
# customized by scripts/factory.sh). These helpers read that file, falling back
# to built-in defaults so a project without the file still runs.
#
# Role keys (structural, never renamed): architect developer tester security
# code_review. Tool ids (the four supported CLIs): claude cursor codex gemini.
# The custom "name" is a DISPLAY/PROMPT label only — parsers never key on it.
# ===========================================================================

# factory_tool_binary <tool-id> — the PATH binary that provides a tool.
factory_tool_binary() {
  case "$1" in
    claude) printf 'claude\n' ;;
    cursor) printf 'agent\n' ;;
    codex)  printf 'codex\n' ;;
    gemini) printf 'gemini\n' ;;
    *)      printf '\n' ;;
  esac
}

# factory_tool_label <tool-id> — pretty display name for menus/logs.
factory_tool_label() {
  case "$1" in
    claude) printf 'Claude\n' ;;
    cursor) printf 'Cursor\n' ;;
    codex)  printf 'Codex\n' ;;
    gemini) printf 'Gemini\n' ;;
    *)      printf '%s\n' "$1" ;;
  esac
}

# factory_tool_is_supported <tool-id> — exit 0 if the tool is in the registry.
factory_tool_is_supported() {
  case "$1" in claude|cursor|codex|gemini) return 0 ;; *) return 1 ;; esac
}

# factory_tool_detect <tool-id> — exit 0 if the tool's binary is on PATH.
factory_tool_detect() {
  local bin
  bin=$(factory_tool_binary "$1")
  [ -n "$bin" ] && command -v "$bin" >/dev/null 2>&1
}

# factory_tool_require <tool-id> — fail fast (exit 127) if the tool is absent.
factory_tool_require() {
  case "$1" in
    claude) rpl_require_tool claude "npm install -g @anthropic-ai/claude-code" "https://docs.anthropic.com/en/docs/claude-code" ;;
    cursor) rpl_require_tool agent  "curl https://cursor.com/install -fsS | bash" "https://cursor.com/docs/cli" ;;
    codex)  rpl_require_tool codex  "npm install -g @openai/codex" "https://github.com/openai/codex" ;;
    gemini) rpl_require_tool gemini "npm install -g @google/gemini-cli" "https://geminicli.com/docs/" ;;
    *) err "factory_tool_require: unknown tool '$1' (supported: claude cursor codex gemini)"; exit 1 ;;
  esac
}

# factory_timeout_bin — echo the available wall-time-cap binary: GNU `timeout`,
# or `gtimeout` (Homebrew coreutils on macOS, which ships neither by default),
# or empty if neither is present.
factory_timeout_bin() {
  if command -v timeout >/dev/null 2>&1; then
    printf 'timeout\n'
  elif command -v gtimeout >/dev/null 2>&1; then
    printf 'gtimeout\n'
  else
    printf '\n'
  fi
}

# factory_run_capped <seconds> <cmd> [args...] — run a command under a wall-time
# cap when a timeout binary exists; otherwise run it uncapped (warning once per
# process). The cap binary returns 124 on timeout, which adapters detect.
factory_run_capped() {
  local secs="$1"
  shift
  local tb
  tb=$(factory_timeout_bin)
  if [ -n "$tb" ]; then
    "$tb" "$secs" "$@"
  else
    if [ -z "${_FACTORY_TIMEOUT_WARNED:-}" ]; then
      err "warning: no 'timeout' or 'gtimeout' on PATH — running agent sessions WITHOUT the ${secs}s wall-time cap."
      err "         On macOS install it with:  brew install coreutils   (provides gtimeout)"
      _FACTORY_TIMEOUT_WARNED=1
    fi
    "$@"
  fi
}

# factory_tool_invoke <tool-id> <prompt> <logfile> [walltime] — run a tool's
# headless invocation, tee'ing combined output to <logfile>. Returns the tool's
# exit code (124 = timeout when a cap binary is present). One invocation contract
# for every adapter and the Gate D ceremony; each tool keeps its own flags and
# RUN_PHASE_* overrides.
factory_tool_invoke() {
  local tool="$1" prompt="$2" logfile="$3"
  local walltime="${4:-${FACTORY_WALL_TIME_SEC:-1800}}"
  local rc=0
  case "$tool" in
    claude)
      local flags
      read -r -a flags <<<"${RUN_PHASE_CLAUDE_FLAGS:---dangerously-skip-permissions}"
      [ -n "${RUN_PHASE_CLAUDE_MODEL:-}" ] && flags+=(--model "$RUN_PHASE_CLAUDE_MODEL")
      [ -n "${RUN_PHASE_CLAUDE_MAX_TURNS:-}" ] && flags+=(--max-turns "$RUN_PHASE_CLAUDE_MAX_TURNS")
      set +e
      factory_run_capped "$walltime" claude -p "$prompt" "${flags[@]}" 2>&1 | tee "$logfile"
      rc=${PIPESTATUS[0]}
      set -e
      ;;
    cursor)
      local flags
      read -r -a flags <<<"${RUN_PHASE_CURSOR_FLAGS:---trust --force --sandbox disabled --output-format text}"
      [ -n "${RUN_PHASE_CURSOR_MODEL:-}" ] && flags+=(--model "$RUN_PHASE_CURSOR_MODEL")
      set +e
      factory_run_capped "$walltime" agent -p "${flags[@]}" -- "$prompt" 2>&1 | tee "$logfile"
      rc=${PIPESTATUS[0]}
      set -e
      ;;
    codex)
      # Default sandbox is workspace-write; if the operator's approval flag
      # overrides the sandbox (e.g. "--sandbox danger-full-access"), drop the
      # default so codex does not get a repeated '--sandbox'.
      local flags=()
      if [[ "${RUN_PHASE_CODEX_APPROVAL_FLAG:-}" != *--sandbox* ]]; then
        flags+=(--sandbox workspace-write)
      fi
      [ -n "${RUN_PHASE_CODEX_MODEL:-}" ] && flags+=(--model "$RUN_PHASE_CODEX_MODEL")
      if [ -n "${RUN_PHASE_CODEX_APPROVAL_FLAG:-}" ]; then
        local _approval
        read -r -a _approval <<<"$RUN_PHASE_CODEX_APPROVAL_FLAG"
        flags+=("${_approval[@]}")
      fi
      set +e
      factory_run_capped "$walltime" codex exec "${flags[@]}" "$prompt" 2>&1 | tee "$logfile"
      rc=${PIPESTATUS[0]}
      set -e
      ;;
    gemini)
      # Gemini CLI headless mode: -p runs non-interactive; --yolo auto-approves
      # tool calls (the factory's unattended-autonomy model). See ADR-0013.
      local flags
      read -r -a flags <<<"${RUN_PHASE_GEMINI_FLAGS:---yolo}"
      [ -n "${RUN_PHASE_GEMINI_MODEL:-}" ] && flags+=(-m "$RUN_PHASE_GEMINI_MODEL")
      set +e
      factory_run_capped "$walltime" gemini -p "$prompt" "${flags[@]}" 2>&1 | tee "$logfile"
      rc=${PIPESTATUS[0]}
      set -e
      ;;
    *)
      err "factory_tool_invoke: unknown tool '$tool' (supported: claude cursor codex gemini)"
      return 2
      ;;
  esac
  return "$rc"
}

# factory_role_default_tool <role-key> — built-in fallback tool for a role.
# Keep in sync with templates/factory-roles.default.json.
factory_role_default_tool() {
  case "$1" in
    architect)   printf 'claude\n' ;;
    developer)   printf 'cursor\n' ;;
    tester)      printf 'codex\n' ;;
    security)    printf 'codex\n' ;;
    code_review) printf 'claude\n' ;;
    *)           printf '\n' ;;
  esac
}

# factory_role_default_name <role-key> — built-in fallback display name.
factory_role_default_name() {
  case "$1" in
    architect)   printf 'Claude\n' ;;
    developer)   printf 'Cursor\n' ;;
    tester)      printf 'Codex\n' ;;
    security)    printf 'Security\n' ;;
    code_review) printf 'Code Review\n' ;;
    *)           printf '%s\n' "$1" ;;
  esac
}

# _factory_role_field <role-key> <tool|name> [config-file] — read one field from
# .factory-roles.json. Prints empty on any miss (absent file, bad JSON, no key).
_factory_role_field() {
  local role="$1" field="$2" cfg="${3:-.factory-roles.json}"
  [ -f "$cfg" ] || { printf '\n'; return 0; }
  python3 - "$cfg" "$role" "$field" <<'PYEOF' 2>/dev/null || true
import json
import sys
cfg, role, field = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    with open(cfg, encoding="utf-8") as f:
        data = json.load(f)
    val = data.get("roles", {}).get(role, {}).get(field, "")
    if isinstance(val, str):
        print(val)
except Exception:
    pass
PYEOF
}

# factory_role_tool <role-key> [config-file] — the tool id assigned to a role,
# from .factory-roles.json, or the built-in default.
factory_role_tool() {
  local role="$1" cfg="${2:-.factory-roles.json}" val
  val=$(_factory_role_field "$role" tool "$cfg")
  [ -n "$val" ] || val=$(factory_role_default_tool "$role")
  printf '%s\n' "$val"
}

# factory_role_name <role-key> [config-file] — the custom display name for a
# role, from .factory-roles.json, or the built-in default. Display/prompt only.
factory_role_name() {
  local role="$1" cfg="${2:-.factory-roles.json}" val
  val=$(_factory_role_field "$role" name "$cfg")
  [ -n "$val" ] || val=$(factory_role_default_name "$role")
  printf '%s\n' "$val"
}
