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

# --- Task 4: check_for_update ---
fake_remote="$(mktemp -d)"
(cd "$fake_remote" && git init --bare -b master --quiet)

work="$(mktemp -d)"
(
    cd "$work"
    git init --quiet -b master
    git config user.email test@example.com
    git config user.name test
    echo hello > file.txt
    git add file.txt
    git commit --quiet -m "first"
    git remote add origin "$fake_remote"
    git push --quiet origin master
)
rm -rf "$work"

remote_hash="$(git ls-remote "$fake_remote" master | cut -f1)"

version_file="$(mktemp)"
echo "$remote_hash" > "$version_file"
out="$(TURBO_REPO_URL="$fake_remote" TURBO_VERSION_FILE="$version_file" bash -c 'source "'"$TURBO_BIN"'"; check_for_update')"
assert_eq "check_for_update silent when up to date" "" "$out"

echo "0000000000000000000000000000000000000000" > "$version_file"
out="$(TURBO_REPO_URL="$fake_remote" TURBO_VERSION_FILE="$version_file" bash -c 'source "'"$TURBO_BIN"'"; check_for_update <<< "y"')"
assert_eq "check_for_update notice when outdated" "A new version of turbo is available. Run 'turbo update' to update." "$(printf '%s\n' "$out" | head -n1)"

set +e
out="$(TURBO_REPO_URL="/no/such/remote-$$" TURBO_VERSION_FILE="$version_file" bash -c 'source "'"$TURBO_BIN"'"; check_for_update' 2>/dev/null)"
status=$?
set -e
assert_eq "check_for_update silent when remote unreachable" "" "$out"
assert_status "check_for_update exits 0 when remote unreachable (not a crash)" "0" "$status"

rm -rf "$fake_remote"
rm -f "$version_file"

# --- Task 5: cmd_create intro steps ---
tmp_projects_dir="$(mktemp -d)"
tmp_config="$(mktemp)"
echo "PROJECTS_DIR=$tmp_projects_dir" > "$tmp_config"

set +e
TURBO_CONFIG_FILE="$tmp_config" TURBO_REPO_URL="/no/such/remote-$$" "$TURBO_BIN" create <<< "My Cool App" >/dev/null 2>&1
status=$?
set -e
assert_status "cmd_create exits 0 for a valid, non-conflicting name" "0" "$status"

set +e
TURBO_CONFIG_FILE="$tmp_config" TURBO_REPO_URL="/no/such/remote-$$" "$TURBO_BIN" create <<< $'Bad/Name\nGood Name' >/dev/null 2>&1
status=$?
set -e
assert_status "cmd_create re-prompts on invalid name then succeeds" "0" "$status"

mkdir -p "$tmp_projects_dir/taken-name"
set +e
out="$(TURBO_CONFIG_FILE="$tmp_config" TURBO_REPO_URL="/no/such/remote-$$" "$TURBO_BIN" create <<< "Taken Name" 2>&1)"
status=$?
set -e
assert_status "cmd_create exits 1 when target dir exists" "1" "$status"
assert_eq "cmd_create prints clear error when target dir exists" "Error: $tmp_projects_dir/taken-name already exists." "$(printf '%s\n' "$out" | tail -n1)"

rm -rf "$tmp_projects_dir"
rm -f "$tmp_config"

echo ""
echo "$failures failure(s)"
exit "$failures"
