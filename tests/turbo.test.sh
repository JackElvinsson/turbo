#!/usr/bin/env bash
set -uo pipefail
# Deliberately no -e: we want every assertion to run and report a summary,
# not stop at the first failure.

TURBO_BIN="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/turbo"
failures=0

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "PASS: $desc"
    else
        echo "FAIL: $desc (expected '$expected', got '$actual')"
        failures=$((failures + 1))
    fi
}

assert_status() {
    local desc="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "PASS: $desc"
    else
        echo "FAIL: $desc (expected exit $expected, got $actual)"
        failures=$((failures + 1))
    fi
}

# --- Task 1: dispatch/usage ---

out="$("$TURBO_BIN" help)"
assert_eq "help prints Usage line" "Usage: turbo <command>" "$(printf '%s\n' "$out" | head -n1)"

out="$("$TURBO_BIN")"
assert_eq "no-args prints Usage line" "Usage: turbo <command>" "$(printf '%s\n' "$out" | head -n1)"

set +e
"$TURBO_BIN" bogus >/dev/null 2>&1
status=$?
set -e
assert_status "unknown command exits 1" "1" "$status"

echo ""
echo "$failures failure(s)"
exit "$failures"
