#!/usr/bin/env bash
# scripts/test/run.sh — run every *.test.sh in this directory and report totals.
#
# Dependency-free; used locally (`bash scripts/test/run.sh`) and by CI
# (.github/workflows/ci.yml). Each suite runs in its own process so one suite's
# state or a crash cannot affect another. Exit 0 only if every suite passes.
set -uo pipefail

TEST_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

suites=0
failed=0
for t in "$TEST_DIR"/*.test.sh; do
  [ -f "$t" ] || continue
  suites=$((suites + 1))
  printf '\n=== %s ===\n' "$(basename "$t")"
  if ! bash "$t"; then
    failed=$((failed + 1))
  fi
done

printf '\n========================================\n'
if [ "$suites" -eq 0 ]; then
  printf 'no test suites found in %s\n' "$TEST_DIR"
  exit 1
fi
if [ "$failed" -eq 0 ]; then
  printf 'ALL SUITES PASSED (%d/%d)\n' "$suites" "$suites"
  exit 0
fi
printf '%d/%d SUITE(S) FAILED\n' "$failed" "$suites"
exit 1
