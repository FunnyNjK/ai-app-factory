#!/usr/bin/env bash
# run-phase-lib.sh — shared safety/session mechanics for the run-phase-*.sh harnesses.
#
# WHY THIS FILE EXISTS
# --------------------
# The repo intentionally ships FIVE separate phase harnesses, one per
# supported AI agent CLI:
#
#   - run-phase.sh         → Anthropic Claude Code (`claude`)
#   - run-phase-codex.sh   → OpenAI Codex CLI (`codex`)
#   - run-phase-cursor.sh  → Cursor CLI (`agent`)
#   - run-phase-copilot.sh → GitHub Copilot CLI (`copilot`)
#   - run-phase-gemini.sh  → Google Gemini CLI (`gemini`)
#
# Users pick whichever AI developer they actually have access to. The five
# scripts MUST stay as separate adapters because each CLI has its own:
#
#   - install command, auth flow, version-specific flags
#   - sub-command names (`-p`, `--continue`, `exec`, `exec resume --last`,
#     `--resume`, `agent -p`, etc.)
#   - approval / sandbox / model flag spellings
#
# This file extracts ONLY the parts that are identical across all four:
# log-dir layout, prompt strings, commit-message subject extraction,
# safe-staging guardrails, commit-and-push semantics with the AI_RULES.md
# Git-Rule push-on-failure stop. Tool-specific code stays in each adapter.
#
# DO NOT collapse the four adapters into one. The variation in CLI flags
# is real and version-dependent; merging would create a fragile single
# point of failure across four moving upstreams.
#
# This library is sourced, not executed. It expects callers to set:
#
#   TOOL_NAME       — short pretty name for log lines (e.g. "Claude")
#   TOOL_LOG_PREFIX — directory prefix for log dir (e.g. "run_claude")
#   TOOL_SCRIPT     — script filename for commit-message footer
#
# Callers must run `set -euo pipefail` themselves.

# ---------------------------------------------------------------------------
# Logging helpers
# ---------------------------------------------------------------------------
log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
err() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*" >&2; }

# ---------------------------------------------------------------------------
# rpl_init_log_dir — create and echo the per-run log directory.
# Usage: LOG_DIR=$(rpl_init_log_dir)
# ---------------------------------------------------------------------------
rpl_init_log_dir() {
  local prefix="${TOOL_LOG_PREFIX:?TOOL_LOG_PREFIX must be set}"
  local stamp
  stamp=$(date +%Y%m%d_%H%M%S)
  local dir="ai/logs/${prefix}_${stamp}"
  mkdir -p "$dir"
  printf '%s\n' "$dir"
}

# ---------------------------------------------------------------------------
# rpl_start_prompt / rpl_end_prompt — the two prompts every adapter sends.
# Kept here so wording stays consistent across tools.
# ---------------------------------------------------------------------------
rpl_start_prompt() {
  printf '%s' "Please read /ai/START_HERE.md and follow it. Then pick up the next task per HANDOFF.md."
}
rpl_end_prompt() {
  printf '%s' "Please read /ai/templates/CHAT_END_PROMPT.md and follow it."
}

# ---------------------------------------------------------------------------
# rpl_preflight — keep unattended phase runs on their own branch and make
# sure pre-existing local edits are not swept into automated commits.
# ---------------------------------------------------------------------------
rpl_preflight() {
  local expected branch target_branch status_output
  expected=$(printf '%s' "${TOOL_NAME:?TOOL_NAME must be set}" | tr '[:upper:]' '[:lower:]')

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    err "error: run the phase harness from inside a git worktree."
    exit 1
  fi

  status_output=$(git status --porcelain --untracked-files=normal)
  if [ -n "$status_output" ] && [ "${RUN_PHASE_ALLOW_DIRTY:-0}" != "1" ]; then
    err "error: working tree is dirty before the phase run starts."
    err "The harness only commits changes made during the run. Commit,"
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
    err "error: detached HEAD. Check out a branch before running the phase harness."
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
# Looks for the "Work completed:" header per /ai/templates/CHAT_END_PROMPT.md.
# Usage: SUBJECT=$(rpl_extract_subject "$LOG_DIR/task_${i}_handoff.log" "<fallback>")
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
# Safe-staging guardrails
# ---------------------------------------------------------------------------
#
# WHY: `git add -A` blindly stages anything in the working tree, including
# files an unrelated process dropped, accidentally-created `.env` files,
# downloaded credentials, local DBs, build artifacts, etc. That's unsafe
# for an unattended harness. We instead enumerate exactly the paths git
# considers changed in this session, then refuse to commit anything that
# matches a sensitive-path pattern.
#
# Patterns are intentionally broad and fail-closed: if a path matches,
# the script aborts rather than staging it.
#
# RUN_PHASE_ALLOWLIST_REGEX (optional) — extra ERE that, if set, restricts
#   staging to paths matching this pattern in addition to the safety
#   filters. Use this to tighten staging to a known sub-tree (e.g. "^src/").
#
# RUN_PHASE_FORCE_UNSAFE=1 (escape hatch) — bypass sensitive-path refusal.
#   Intended for emergency manual recovery; never use in unattended mode.
#

# Patterns that must NEVER be auto-committed by the harness.
# ERE syntax for `grep -E`. Two alternations:
#   - File-name patterns are anchored to end-of-path with $.
#   - Directory-prefix patterns (e.g. ".aws/") match anywhere in the path.
# Update with care; this list is fail-closed.
RPL_SENSITIVE_PATTERNS_DEFAULT='((^|/)(\.env(\..+)?|\.envrc|\.netrc|\.npmrc|\.pypirc|\.pgpass|\.my\.cnf|\.kube/config|kubeconfig|credentials(\.json)?|secrets?(\.ya?ml|\.json|\.env)?|.*\.pem|.*\.key|.*\.p12|.*\.pfx|.*\.jks|.*\.keystore|.*\.crt|.*\.cer|id_rsa|id_dsa|id_ecdsa|id_ed25519|.*\.sqlite3?|.*\.db|.*\.mdb|.*\.dump|.*\.bak)$)|((^|/)(\.aws|\.azure|\.gcp|\.config/gcloud|\.ssh|\.gnupg)/)'

# ---------------------------------------------------------------------------
# rpl_session_changed_paths — print null-separated paths git sees as changed.
# Includes modified, added, deleted, renamed (new name), and untracked
# (excluding gitignored). Output is NUL-delimited so paths with spaces /
# newlines round-trip safely.
#
# Implementation note: uses bash's `read -r -d ''` for NUL-record splitting
# rather than `awk -v RS='\0'` (a GNU AWK extension that breaks under BSD
# awk on macOS without a gawk install). Pure bash 3.2+ — runs on stock
# macOS, every Linux distro, and Windows Git Bash unchanged.
# ---------------------------------------------------------------------------
rpl_session_changed_paths() {
  # `git status --porcelain=v1 -z` emits NUL-terminated records.
  # Each non-rename record is "XY path".
  # Renames/copies emit TWO records: "RC path-A" then "path-B" (no
  # status-code prefix). We emit BOTH paths so safe-stage sees the full
  # before-and-after set; git handles rename detection at commit time.
  local rec records=() i=0 n code path skip_next=0
  while IFS= read -r -d '' rec; do
    records+=("$rec")
  done < <(git status --porcelain=v1 -z --untracked-files=normal)

  n=${#records[@]}
  while [ "$i" -lt "$n" ]; do
    rec="${records[i]}"
    if [ "$skip_next" = "1" ]; then
      # Companion record of a rename/copy — no status-code prefix.
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

# ---------------------------------------------------------------------------
# rpl_safe_stage — stage only session-changed files, refusing sensitive ones.
#
# Exit codes:
#   0   staged (and at least one file actually staged)
#   1   would-stage list contained sensitive paths; aborted (fail-closed)
#   2   nothing to stage (no session changes after filtering)
#
# Side effects: runs `git add --` on the surviving paths.
# Writes a human-readable summary to stdout before staging.
# ---------------------------------------------------------------------------
rpl_safe_stage() {
  local sensitive_re="${RPL_SENSITIVE_PATTERNS:-$RPL_SENSITIVE_PATTERNS_DEFAULT}"
  local allow_re="${RUN_PHASE_ALLOWLIST_REGEX:-}"
  local force_unsafe="${RUN_PHASE_FORCE_UNSAFE:-0}"

  local all_paths=() suspicious=() to_stage=() skipped_allow=()
  local p

  # Read NUL-delimited paths into array.
  while IFS= read -r -d '' p; do
    [ -z "$p" ] && continue
    all_paths+=("$p")
  done < <(rpl_session_changed_paths)

  if [ ${#all_paths[@]} -eq 0 ]; then
    log "ℹ️  No session changes to stage."
    return 2
  fi

  for p in "${all_paths[@]}"; do
    if printf '%s' "$p" | grep -Eq "$sensitive_re"; then
      suspicious+=("$p")
      continue
    fi
    if [ -n "$allow_re" ] && ! printf '%s' "$p" | grep -Eq "$allow_re"; then
      skipped_allow+=("$p")
      continue
    fi
    to_stage+=("$p")
  done

  # Sensitive-path refusal: fail-closed unless explicit override.
  if [ ${#suspicious[@]} -gt 0 ]; then
    err "❌ Refusing to stage suspicious / sensitive paths:"
    for p in "${suspicious[@]}"; do err "     - $p"; done
    if [ "$force_unsafe" = "1" ]; then
      err "⚠️  RUN_PHASE_FORCE_UNSAFE=1 set — staging anyway (NOT recommended)."
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
    log "ℹ️  RUN_PHASE_ALLOWLIST_REGEX skipped ${#skipped_allow[@]} path(s):"
    for p in "${skipped_allow[@]}"; do log "     - $p"; done
  fi

  if [ ${#to_stage[@]} -eq 0 ]; then
    log "ℹ️  Nothing left to stage after filtering."
    return 2
  fi

  log "📦 Staging ${#to_stage[@]} session-changed path(s):"
  for p in "${to_stage[@]}"; do log "     + $p"; done

  git add -- "${to_stage[@]}"

  # Status summary right before commit so the run log shows exactly what
  # will land in the commit.
  log "📋 git status --short (staged + remaining):"
  git status --short | sed 's/^/     /'
  return 0
}

# ---------------------------------------------------------------------------
# rpl_commit_and_push — wrap stage + commit + push with the standard
# "stop on push failure" semantics from /ai/AI_RULES.md Git Rules.
#
# Args:
#   $1 subject       — commit subject (one line)
#   $2 log_path      — path to the handoff log (for commit body + on-fail msg)
#
# Reads:
#   TOOL_SCRIPT          — script basename for commit footer.
#   RUN_PHASE_NO_PUSH=1  — commit but skip push (legacy).
#   SYNC_MODE=batch      — commit but skip push.
#
# Exit codes:
#   0   committed (and pushed if push not disabled)
#   2   no changes to commit
#   1   push failed (caller should `exit 1`)
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
    # Hard refusal (suspicious paths, fail-closed). Bubble up.
    return "$stage_rc"
  fi

  # Anything actually staged? If allowlist or the safe-stage filters
  # removed everything, `git diff --cached --quiet` exits 0 and we skip.
  if git diff --cached --quiet; then
    log "ℹ️  Nothing staged after safety filters; skipping commit."
    return 2
  fi

  git commit -m "$subject" \
             -m "Automated commit by $script. Log: $log_path"
  log "📝 Committed: $subject"

  if [ "${RUN_PHASE_NO_PUSH:-0}" = "1" ] || [ "${SYNC_MODE:-immediate}" = "batch" ]; then
    log "⏭  RUN_PHASE_NO_PUSH=1 or SYNC_MODE=batch set — skipping push."
    return 0
  fi

  log "⬆  Pushing to origin..."
  if ! git push; then
    err ""
    err "❌ Push failed (commit: $subject)."
    err "Stopping phase run so the local branch does not drift from origin."
    err "Resolve the push (auth / network / non-fast-forward) and re-run."
    err "Log: $log_path"
    return 1
  fi
  log "✅ Pushed to origin."
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
