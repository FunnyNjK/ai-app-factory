#!/usr/bin/env bash
# scripts/orchestrator/require-bash4.sh — re-exec the calling script under
# bash >= 4 when the current interpreter is too old to parse the factory's
# prompt heredocs.
#
# Why this exists: macOS ships bash 3.2.57 (2007, kept for GPLv2 licensing).
# bash 3.2 mis-parses `$(cat <<HEREDOC ... )` command substitutions that contain
# backticks — the exact pattern every role adapter uses to build its prompt —
# and dies with a cryptic "syntax error near unexpected token `;;'" reported far
# below the real cause. bash >= 4 parses it correctly, which is why the Ubuntu
# host (bash 5) never hit this. See docs/adr/0015-require-bash-4-plus.md.
#
# Contract:
#   - Source this (do not execute it) as early as possible in every executable
#     entry point: AFTER SCRIPT_DIR is known, but BEFORE any bash-4-only syntax
#     (heredocs inside command substitution, ${x^^}, declare -A, etc.).
#   - This file itself MUST stay strictly bash-3.2-compatible — it is the one
#     thing that runs under the old interpreter before the re-exec.
#
# It re-execs "$0" (the calling script) with the original arguments, so the
# replacement process re-reads the whole script under the modern bash. The
# FACTORY_BASH_REEXEC guard makes the re-exec idempotent (no loop).

if [ -z "${FACTORY_BASH_REEXEC:-}" ] && [ "${BASH_VERSINFO:-0}" -lt 4 ]; then
  for _factory_bash in \
    /opt/homebrew/bin/bash \
    /usr/local/bin/bash \
    /opt/local/bin/bash \
    "$(command -v bash 2>/dev/null || true)"; do
    if [ -n "$_factory_bash" ] && [ -x "$_factory_bash" ] \
      && "$_factory_bash" -c '[ "${BASH_VERSINFO:-0}" -ge 4 ]' 2>/dev/null; then
      FACTORY_BASH_REEXEC=1
      export FACTORY_BASH_REEXEC
      exec "$_factory_bash" "$0" "$@"
    fi
  done
  printf 'error: the AI App Factory orchestrator requires bash >= 4, but this is bash %s.\n' "${BASH_VERSION:-(unknown)}" >&2
  printf '       No bash >= 4 was found on this machine. Install one and retry:\n' >&2
  printf '         macOS:          brew install bash\n' >&2
  printf '         Debian/Ubuntu:  apt-get install bash\n' >&2
  exit 1
fi
