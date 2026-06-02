#!/usr/bin/env bash
# scripts/test/lib-assert.sh — tiny, dependency-free assertion helpers for the
# factory's bash test suites. Source this from a *.test.sh file:
#
#   . "$TEST_DIR/lib-assert.sh"
#   assert_eq "expected" "$actual" "what this checks"
#   assert_summary   # at the end; returns nonzero if any assertion failed
#
# No framework and no runtime beyond bash — matching the factory's
# dependency-free baseline (ADR-0012). Intentionally does NOT set shell options;
# it must not change the sourcing suite's `set` flags.

TESTS_RUN=0
TESTS_FAILED=0
CURRENT_SUITE="${CURRENT_SUITE:-suite}"

_pass() { TESTS_RUN=$((TESTS_RUN + 1)); printf '  ok   %s\n' "$1"; }
_fail() {
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_FAILED=$((TESTS_FAILED + 1))
  printf '  FAIL %s\n' "$1"
  [ -n "${2:-}" ] && printf '       %s\n' "$2"
  return 0
}

# assert_eq <expected> <actual> <msg>
assert_eq() {
  if [ "$1" = "$2" ]; then _pass "$3"; else _fail "$3" "expected [$1], got [$2]"; fi
}

# assert_contains <haystack> <needle> <msg>
assert_contains() {
  case "$1" in
    *"$2"*) _pass "$3" ;;
    *)      _fail "$3" "expected to contain [$2], got [$1]" ;;
  esac
}

# assert_code <expected-code> <actual-code> <msg>
assert_code() {
  if [ "$1" = "$2" ]; then _pass "$3"; else _fail "$3" "expected exit [$1], got [$2]"; fi
}

# assert_nonempty <value> <msg>
assert_nonempty() {
  if [ -n "$1" ]; then _pass "$2"; else _fail "$2" "expected a non-empty value"; fi
}

# assert_summary — print totals; return nonzero if any assertion failed.
assert_summary() {
  printf -- '----\n%s: %d assertion(s), %d failed\n' "$CURRENT_SUITE" "$TESTS_RUN" "$TESTS_FAILED"
  [ "$TESTS_FAILED" -eq 0 ]
}
