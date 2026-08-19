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

# --- Task 2: slugify / validate_project_name ---
source "$TURBO_BIN"

assert_eq "slugify basic" "my-cool-app" "$(slugify "My Cool App")"
assert_eq "slugify collapses punctuation" "my-cool-app" "$(slugify "  My__Cool--App!!  ")"
assert_eq "slugify all lowercase already" "already-lower" "$(slugify "already-lower")"

if validate_project_name "My Cool App"; then
    echo "PASS: validate_project_name accepts letters numbers spaces"
else
    echo "FAIL: validate_project_name accepts letters numbers spaces"
    failures=$((failures + 1))
fi

if validate_project_name "Client/Project"; then
    echo "FAIL: validate_project_name rejects slash"
    failures=$((failures + 1))
else
    echo "PASS: validate_project_name rejects slash"
fi

if validate_project_name ""; then
    echo "FAIL: validate_project_name rejects empty string"
    failures=$((failures + 1))
else
    echo "PASS: validate_project_name rejects empty string"
fi

# --- Task 3: read_projects_dir ---
tmp_config="$(mktemp)"
echo 'PROJECTS_DIR=/tmp/somewhere' > "$tmp_config"
assert_eq "read_projects_dir uses config value" "/tmp/somewhere" "$(TURBO_CONFIG_FILE="$tmp_config" bash -c 'source "'"$TURBO_BIN"'"; read_projects_dir')"
rm -f "$tmp_config"

missing_config="/tmp/turbo-test-no-such-file-$$"
assert_eq "read_projects_dir falls back to default" "/home/jack/PhpstormProjects" "$(TURBO_CONFIG_FILE="$missing_config" bash -c 'source "'"$TURBO_BIN"'"; read_projects_dir')"

echo ""
echo "$failures failure(s)"
exit "$failures"
