#!/usr/bin/env bash
# scripts/test/menu.test.sh — tests for the launcher's _select helper and the
# inline UI helpers (ADR-0012 amendment: Claude Code look and feel).
#
# _select has two paths:
#   - interactive (stdin + stderr are TTYs): the inline arrow-key picker —
#     exercised here under a pty via `script` when available, otherwise
#     manually on the host.
#   - non-interactive (pipes, CI): the dependency-free numbered fallback —
#     chosen key to stdout, menu UI to stderr. Always testable; tested here.
#
# Sources factory.sh, which is safe because of the launcher's BASH_SOURCE guard.
set -uo pipefail

TEST_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
FACTORY_ROOT=$(cd -- "$TEST_DIR/../.." && pwd)
CURRENT_SUITE="factory.sh menu"

# shellcheck source=lib-assert.sh
. "$TEST_DIR/lib-assert.sh"
# shellcheck source=../factory.sh
. "$FACTORY_ROOT/scripts/factory.sh"

# --- the launcher no longer shells out to external pickers ------------------
# The whiptail fullscreen dialog hid action output (the first interactive run's
# finding); fzf went with it. The inline picker is built in. Guard against the
# dependency creeping back (invocation patterns only — prose mentions are fine).
ext=$(grep -cE 'command -v (whiptail|fzf)|whiptail --|\| *fzf ' "$FACTORY_ROOT/scripts/factory.sh" || true)
assert_eq "0" "$ext" "factory.sh does not invoke whiptail or fzf"

# --- numbered fallback (non-interactive callers always take this path) ------

# Chosen key is emitted on stdout (UI suppressed via 2>/dev/null).
out=$(printf '2\n' | _select "Pick one" "> " 1 "Alpha" 2 "Beta" 3 "Gamma" 2>/dev/null)
assert_eq "2" "$out" "_select emits the chosen key on stdout"

# The menu (title + labels) renders on stderr, keeping stdout clean for capture.
err=$(printf '1\n' | _select "MyMenu" "> " 1 "Alpha" 2 "Beta" 2>&1 1>/dev/null)
assert_contains "$err" "MyMenu" "_select renders the title on stderr"
assert_contains "$err" "Alpha" "_select renders labels on stderr"

# Empty input yields an empty key (the caller's case treats it as invalid).
out=$(printf '\n' | _select "T" "> " 1 "One" 2>/dev/null)
assert_eq "" "$out" "_select empty input -> empty key"

# --- inline interactive picker (under a pty, when `script` is available) ----

if command -v script >/dev/null 2>&1; then
  PTY_HELPER="$TEST_DIR/.pty-select-helper.sh"
  # NOTE: sourcing factory.sh turns on `set -e`, so a cancelled picker (rc=1)
  # must be caught with `|| rc=$?` or the helper dies before printing.
  cat > "$PTY_HELPER" <<EOF
. "$FACTORY_ROOT/scripts/factory.sh"
rc=0
choice=\$(_select "Pty menu" "> " 1 "Alpha" 2 "Beta" 3 "Gamma") || rc=\$?
printf 'PICKED=[%s] RC=[%s]\n' "\$choice" "\$rc"
EOF
  trap 'rm -f "$PTY_HELPER"' EXIT

  # Pressing a digit jumps straight to that option and selects it.
  out=$(printf '2' | script -qec "bash $PTY_HELPER" /dev/null 2>/dev/null || true)
  assert_contains "$out" "PICKED=[2] RC=[0]" "pty: digit press jump-selects that option"

  # Arrow-down then Enter selects the second option.
  out=$(printf '\033[B\n' | script -qec "bash $PTY_HELPER" /dev/null 2>/dev/null || true)
  assert_contains "$out" "PICKED=[2] RC=[0]" "pty: arrow-down + Enter selects option 2"

  # 'q' cancels: empty key, nonzero rc.
  out=$(printf 'q' | script -qec "bash $PTY_HELPER" /dev/null 2>/dev/null || true)
  assert_contains "$out" "PICKED=[] RC=[1]" "pty: q cancels the picker"

  # The picker collapses to a single accent ❯ line naming the choice.
  out=$(printf '2' | script -qec "bash $PTY_HELPER" /dev/null 2>/dev/null || true)
  assert_contains "$out" "❯" "pty: collapsed choice line uses the ❯ pointer"
  assert_contains "$out" "Beta" "pty: collapsed choice line names the chosen label"
else
  _pass "skipped pty picker assertions ('script' not on this host)"
fi

# --- ui helpers --------------------------------------------------------------

# ui_pause is a no-op for non-interactive callers (it must never hang CI).
out=$(printf '' | ui_pause 2>&1)
assert_eq "" "$out" "ui_pause is a no-op when stdin is not a TTY"

# ui_banner renders the rounded box with the title.
err=$(ui_banner "Test Banner" "subtitle line" 2>&1 1>/dev/null)
assert_contains "$err" "Test Banner" "ui_banner renders the title"
assert_contains "$err" "╭" "ui_banner renders the rounded box"
assert_contains "$err" "✻" "ui_banner renders the Claude marker"

assert_summary
