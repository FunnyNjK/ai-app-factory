#!/usr/bin/env bash
# scripts/test/settings.test.sh — tests for the launcher's per-project settings
# persistence (load_settings / save_settings in scripts/factory.sh).
#
# This suite sources factory.sh directly, which is safe because of the
# launcher's BASH_SOURCE guard (the interactive menu / CLI does not run on
# source). Sourcing also turns on `set -e` (factory.sh declares set -euo
# pipefail); the assert helpers and the settings functions all return 0, so the
# suite runs cleanly under it.
set -uo pipefail

TEST_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
FACTORY_ROOT=$(cd -- "$TEST_DIR/../.." && pwd)
CURRENT_SUITE="factory.sh settings"

# shellcheck source=lib-assert.sh
. "$TEST_DIR/lib-assert.sh"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# shellcheck source=../factory.sh
. "$FACTORY_ROOT/scripts/factory.sh"

cd "$WORK"

# Round-trip: the Codex sandbox flag contains a space and must survive write+read.
SETTING_NO_PUSH=1
SETTING_CODEX_SANDBOX="--sandbox danger-full-access"
save_settings
assert_eq "1" "$(grep -c '^RUN_PHASE_NO_PUSH=1$' .factory-settings)" "save: NO_PUSH line written"

# Wipe the in-memory values, then reload from disk.
SETTING_NO_PUSH=0
SETTING_CODEX_SANDBOX=""
load_settings
assert_eq "1" "$SETTING_NO_PUSH" "load: NO_PUSH restored"
assert_eq "--sandbox danger-full-access" "$SETTING_CODEX_SANDBOX" "load: sandbox flag (with space) restored"

# With no file present, load_settings is a no-op and leaves the values alone.
rm -f .factory-settings
SETTING_NO_PUSH=7
load_settings
assert_eq "7" "$SETTING_NO_PUSH" "load: no file -> values unchanged"

assert_summary
