#!/usr/bin/env bash
# scripts/check-cli-tools.sh — preflight check for the headless AI CLIs the
# factory orchestrator depends on. Verifies each binary is on PATH, prints
# the version, and reports whether an auth env var is set.
#
# Usage:
#   scripts/check-cli-tools.sh                # check the four supported agent CLIs + supporting tools
#   scripts/check-cli-tools.sh --include-optional  # also check copilot (reference only; not a factory role tool)
#
# The four supported agent CLIs (claude, codex, cursor/agent, gemini — see
# docs/adr/0013-configurable-roles-and-tools.md) are all checked. You only need
# the ones your project assigns to roles in .factory-roles.json, so a missing
# agent CLI is reported with install help but is not a hard failure on its own.
#
# Exit codes:
#   0   all supporting tools present and at least one agent CLI present
#   1   a required supporting tool is missing, or no agent CLI is present at all

set -euo pipefail

INCLUDE_OPTIONAL=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --include-optional) INCLUDE_OPTIONAL=1; shift ;;
    -h|--help)
      sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) printf 'error: unknown argument: %s\n' "$1" >&2; exit 1 ;;
  esac
done

AGENT_PRESENT=0
AGENT_ABSENT=0
SUPPORT_MISSING=0

check_tool() {
  local label="$1" binary="$2" version_cmd="$3" install_cmd="$4" docs="$5" auth_env="$6"
  printf '\n[%s] (%s)\n' "$label" "$binary"

  if ! command -v "$binary" >/dev/null 2>&1; then
    printf '  status:   MISSING\n'
    printf '  install:  %s\n' "$install_cmd"
    printf '  docs:     %s\n' "$docs"
    AGENT_ABSENT=$((AGENT_ABSENT + 1))
    return 1
  fi

  printf '  status:   present at %s\n' "$(command -v "$binary")"

  local version_output
  # Split the version command into argv and run it directly (no eval — avoids executing
  # an arbitrary string if a caller ever passes tainted input).
  local -a version_argv
  read -r -a version_argv <<<"$version_cmd"
  if version_output=$("${version_argv[@]}" 2>&1); then
    # Only show the first line of version output — some CLIs print a banner.
    printf '  version:  %s\n' "$(printf '%s' "$version_output" | head -n 1)"
  else
    printf '  version:  (could not determine — %s failed)\n' "$version_cmd"
  fi

  if [ -n "$auth_env" ]; then
    if [ -n "${!auth_env:-}" ]; then
      printf '  auth:     %s is set (length %d)\n' "$auth_env" "${#auth_env}"
    else
      printf '  auth:     WARNING — %s not set. Interactive auth may be required.\n' "$auth_env"
    fi
  fi

  AGENT_PRESENT=$((AGENT_PRESENT + 1))
}

printf 'Factory CLI tool preflight\n'
printf '==========================\n'

check_tool \
  "Claude Code" \
  "claude" \
  "claude --version" \
  "npm install -g @anthropic-ai/claude-code" \
  "https://docs.anthropic.com/en/docs/claude-code" \
  "ANTHROPIC_API_KEY"

check_tool \
  "Codex CLI" \
  "codex" \
  "codex --version" \
  "npm install -g @openai/codex" \
  "https://github.com/openai/codex" \
  "OPENAI_API_KEY"

check_tool \
  "Cursor CLI" \
  "agent" \
  "agent --version" \
  "curl https://cursor.com/install -fsS | bash" \
  "https://cursor.com/docs/cli" \
  "CURSOR_API_KEY"

check_tool \
  "Gemini CLI" \
  "gemini" \
  "gemini --version" \
  "npm install -g @google/gemini-cli" \
  "https://github.com/google-gemini/gemini-cli" \
  "GEMINI_API_KEY"

if [ "$INCLUDE_OPTIONAL" = "1" ]; then
  check_tool \
    "Copilot CLI" \
    "copilot" \
    "copilot --version" \
    "npm install -g @github/copilot" \
    "https://docs.github.com/en/copilot/concepts/agents/about-copilot-cli" \
    "GITHUB_TOKEN"
fi

# Supporting tools the orchestrator and adapters use.
printf '\n[Supporting tools]\n'
for support in git python3 grep awk sed; do
  if command -v "$support" >/dev/null 2>&1; then
    printf '  %-8s present\n' "$support"
  else
    printf '  %-8s MISSING — orchestrator will not run without it.\n' "$support"
    SUPPORT_MISSING=$((SUPPORT_MISSING + 1))
  fi
done
# Wall-time cap binary: GNU `timeout`, or `gtimeout` from Homebrew coreutils on
# macOS (which ships neither by default). Optional — without it the orchestrator
# runs agent sessions without a per-session wall-time cap.
if command -v timeout >/dev/null 2>&1; then
  printf '  %-8s present (timeout)\n' "timeout"
elif command -v gtimeout >/dev/null 2>&1; then
  printf '  %-8s present (gtimeout)\n' "timeout"
else
  printf '  %-8s not found — wall-time cap disabled. Optional: brew install coreutils (gtimeout).\n' "timeout"
fi

printf '\n==========================\n'
printf 'Agent CLIs:       %d present, %d not installed (install the ones your roles use in .factory-roles.json).\n' "$AGENT_PRESENT" "$AGENT_ABSENT"
if [ "$SUPPORT_MISSING" -eq 0 ]; then
  printf 'Supporting tools: all present.\n'
else
  printf 'Supporting tools: %d missing.\n' "$SUPPORT_MISSING"
fi

if [ "$SUPPORT_MISSING" -gt 0 ]; then
  printf 'Result: a required supporting tool is missing — the orchestrator will not run.\n'
  exit 1
fi
if [ "$AGENT_PRESENT" -eq 0 ]; then
  printf 'Result: no agent CLI is installed — install at least the tools your roles use.\n'
  exit 1
fi
printf 'Result: ready (install any additional agent CLIs you plan to assign to roles).\n'
exit 0
