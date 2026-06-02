#!/usr/bin/env bash
# scripts/test/menu.test.sh — tests for the launcher's _select helper.
#
# Verifies the dependency-free fallback path (numbered `read` menu): the chosen
# key goes to stdout while the menu UI goes to stderr, so callers can capture the
# key with $(...) without swallowing the display. The fzf/whiptail branches are
# exercised on hosts where those tools are installed; when present here, the
# fallback assertions are skipped (the helper would take a different path).
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

if command -v fzf >/dev/null 2>&1 || command -v whiptail >/dev/null 2>&1; then
  _pass "skipped _select fallback assertions (fzf/whiptail present on this host)"
else
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
fi

assert_summary
