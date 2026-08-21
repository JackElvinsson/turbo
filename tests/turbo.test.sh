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
assert_eq "help prints Usage line" "Usage: turbo <command>" "$(printf '%s\n' "$out" | grep -m1 "^Usage:")"

out="$("$TURBO_BIN")"
assert_eq "no-args prints Usage line" "Usage: turbo <command>" "$(printf '%s\n' "$out" | grep -m1 "^Usage:")"

set +e
"$TURBO_BIN" bogus >/dev/null 2>&1
status=$?
set -e
assert_status "unknown command exits 1" "1" "$status"

# --- Task 2: slugify / validate_project_name ---
source "$TURBO_BIN"
# Sourcing turbo enables `set -euo pipefail` in this shell too; turn -e back
# off permanently so every assertion below runs and gets reported instead of
# aborting the suite on the first non-zero command.
set +e

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
out="$(TURBO_REPO_URL="$fake_remote" TURBO_VERSION_FILE="$version_file" bash -c 'source "'"$TURBO_BIN"'"; check_for_update <<< "n"')"
assert_eq "check_for_update notice when outdated" "A new version of turbo is available." "$(printf '%s\n' "$out" | head -n1)"

out="$(TURBO_REPO_URL="$fake_remote" TURBO_VERSION_FILE="$version_file" bash -c 'source "'"$TURBO_BIN"'"; cmd_update() { echo "UPDATE_CALLED"; }; check_for_update <<< "y"' 2>/dev/null)"
assert_eq "check_for_update runs update when accepted" "UPDATE_CALLED" "$(printf '%s\n' "$out" | sed -n '2p')"

set +e
out="$(TURBO_REPO_URL="/no/such/remote-$$" TURBO_VERSION_FILE="$version_file" bash -c 'source "'"$TURBO_BIN"'"; check_for_update' 2>/dev/null)"
status=$?
assert_eq "check_for_update silent when remote unreachable" "" "$out"
assert_status "check_for_update exits 0 when remote unreachable (not a crash)" "0" "$status"

rm -rf "$fake_remote"
rm -f "$version_file"

# --- Task 5: cmd_create intro steps ---
tmp_projects_dir="$(mktemp -d)"
tmp_config="$(mktemp)"
echo "PROJECTS_DIR=$tmp_projects_dir" > "$tmp_config"

set +e
TURBO_CONFIG_FILE="$tmp_config" TURBO_REPO_URL="/no/such/remote-$$" "$TURBO_BIN" create <<< $'My Cool App\n\nn\nn' >/dev/null 2>&1
status=$?
assert_status "cmd_create exits 0 for a valid, non-conflicting name" "0" "$status"

set +e
TURBO_CONFIG_FILE="$tmp_config" TURBO_REPO_URL="/no/such/remote-$$" "$TURBO_BIN" create <<< $'Bad/Name\nGood Name\n\nn\nn' >/dev/null 2>&1
status=$?
assert_status "cmd_create re-prompts on invalid name then succeeds" "0" "$status"

mkdir -p "$tmp_projects_dir/taken-name"
set +e
out="$(TURBO_CONFIG_FILE="$tmp_config" TURBO_REPO_URL="/no/such/remote-$$" "$TURBO_BIN" create <<< "Taken Name" 2>&1)"
status=$?
assert_status "cmd_create exits 1 when target dir exists" "1" "$status"
assert_eq "cmd_create prints clear error when target dir exists" "Error: $tmp_projects_dir/taken-name already exists." "$(printf '%s\n' "$out" | tail -n1)"

rm -rf "$tmp_projects_dir"
rm -f "$tmp_config"

# --- Task 6: cmd_create GitHub branch ---
tmp_projects_dir="$(mktemp -d)"
tmp_config="$(mktemp)"
echo "PROJECTS_DIR=$tmp_projects_dir" > "$tmp_config"

no_gh_path_dir="$(mktemp -d)"
for tool in git curl bash tr sed cut mkdir cat; do
    real_path="$(command -v "$tool")"
    ln -s "$real_path" "$no_gh_path_dir/$tool"
done
set +e
out="$(TURBO_CONFIG_FILE="$tmp_config" TURBO_REPO_URL="/no/such/remote-$$" PATH="$no_gh_path_dir" "$TURBO_BIN" create <<< $'Needs Github\n\ny' 2>&1)"
status=$?
assert_status "cmd_create exits 1 when gh missing" "1" "$status"
assert_eq "cmd_create prints gh missing error" "Error: gh is not installed. Install it, then run 'gh auth login'." "$(printf '%s\n' "$out" | tail -n1)"
rm -rf "$no_gh_path_dir"

rm -rf "$tmp_projects_dir"
rm -f "$tmp_config"

# --- Task 7: cmd_create local clone branch ---
fake_template="$(mktemp -d)"
(
    cd "$fake_template"
    git init --quiet -b master
    git config user.email test@example.com
    git config user.name test
    echo readme > README.md
    git add README.md
    git commit --quiet -m "first"
)

tmp_projects_dir="$(mktemp -d)"
tmp_config="$(mktemp)"
echo "PROJECTS_DIR=$tmp_projects_dir" > "$tmp_config"

set +e
TURBO_CONFIG_FILE="$tmp_config" TURBO_REPO_URL="/no/such/remote-$$" TURBO_TEMPLATE_CLONE_URL_VUE="$fake_template" "$TURBO_BIN" create <<< $'Local Clone Project\n\nn' >/dev/null 2>&1

if [ -f "$tmp_projects_dir/local-clone-project/README.md" ]; then
    echo "PASS: cmd_create local clone produced project files"
else
    echo "FAIL: cmd_create local clone produced project files"
    failures=$((failures + 1))
fi

rm -rf "$fake_template" "$tmp_projects_dir"
rm -f "$tmp_config"

# --- Task 8: cmd_create post-clone setup.sh prompt ---
fake_template="$(mktemp -d)"
(
    cd "$fake_template"
    git init --quiet -b master
    git config user.email test@example.com
    git config user.name test
    cat > setup.sh <<'SETUP_EOF'
#!/usr/bin/env bash
echo "setup.sh ran with: $1" > setup-ran.txt
SETUP_EOF
    chmod +x setup.sh
    git add setup.sh
    git commit --quiet -m "first"
)

tmp_projects_dir="$(mktemp -d)"
tmp_config="$(mktemp)"
echo "PROJECTS_DIR=$tmp_projects_dir" > "$tmp_config"

TURBO_CONFIG_FILE="$tmp_config" TURBO_REPO_URL="/no/such/remote-$$" TURBO_TEMPLATE_CLONE_URL_VUE="$fake_template" "$TURBO_BIN" create <<< $'Setup Runs\n\nn\ny' >/dev/null 2>&1

assert_eq "cmd_create runs setup.sh with project name" "setup.sh ran with: Setup Runs" "$(cat "$tmp_projects_dir/setup-runs/setup-ran.txt" 2>/dev/null)"

TURBO_CONFIG_FILE="$tmp_config" TURBO_REPO_URL="/no/such/remote-$$" TURBO_TEMPLATE_CLONE_URL_VUE="$fake_template" "$TURBO_BIN" create <<< $'Setup Skipped\n\nn\nn' >/dev/null 2>&1

if [ -f "$tmp_projects_dir/setup-skipped/setup-ran.txt" ]; then
    echo "FAIL: cmd_create should not run setup.sh when declined"
    failures=$((failures + 1))
else
    echo "PASS: cmd_create should not run setup.sh when declined"
fi

rm -rf "$fake_template" "$tmp_projects_dir"
rm -f "$tmp_config"

# --- Task 10: cmd_update ---
fake_install_script="$(mktemp)"
cat > "$fake_install_script" <<'EOF'
#!/usr/bin/env bash
echo "install.sh ran" > "$UPDATE_MARKER"
EOF

marker="$(mktemp -d)/marker.txt"
TURBO_INSTALL_URL="file://$fake_install_script" UPDATE_MARKER="$marker" "$TURBO_BIN" update >/dev/null 2>&1

assert_eq "cmd_update delegates to install.sh" "install.sh ran" "$(cat "$marker" 2>/dev/null)"

rm -f "$fake_install_script"
rm -rf "$(dirname "$marker")"

# --- Task 11: cmd_destroy ---
tmp_projects_dir="$(mktemp -d)"
tmp_config="$(mktemp)"
echo "PROJECTS_DIR=$tmp_projects_dir" > "$tmp_config"

set +e
out="$(TURBO_CONFIG_FILE="$tmp_config" "$TURBO_BIN" destroy 2>&1)"
status=$?
assert_status "cmd_destroy exits 1 with no project name" "1" "$status"
assert_eq "cmd_destroy prints usage error" "Usage: turbo destroy <project>" "$(printf '%s\n' "$out" | tail -n1)"

out="$(TURBO_CONFIG_FILE="$tmp_config" "$TURBO_BIN" destroy "Nope" 2>&1)"
status=$?
assert_status "cmd_destroy exits 1 for nonexistent project" "1" "$status"
assert_eq "cmd_destroy prints not found error" "Error: $tmp_projects_dir/nope does not exist." "$(printf '%s\n' "$out" | tail -n1)"

mkdir -p "$tmp_projects_dir/test-project"
touch "$tmp_projects_dir/test-project/dummy.txt"

out="$(TURBO_CONFIG_FILE="$tmp_config" "$TURBO_BIN" destroy "Test Project" <<< "wrong" 2>&1)"
status=$?
assert_status "cmd_destroy exits 1 on mismatched confirmation" "1" "$status"

if [ -d "$tmp_projects_dir/test-project" ]; then
    echo "PASS: cmd_destroy leaves directory intact on mismatched confirmation"
else
    echo "FAIL: cmd_destroy leaves directory intact on mismatched confirmation"
    failures=$((failures + 1))
fi

set +e
TURBO_CONFIG_FILE="$tmp_config" "$TURBO_BIN" destroy "Test Project" <<< "Test Project" >/dev/null 2>&1
status=$?
set -e
assert_status "cmd_destroy exits 0 on matching confirmation" "0" "$status"

if [ ! -d "$tmp_projects_dir/test-project" ]; then
    echo "PASS: cmd_destroy deletes directory on matching confirmation"
else
    echo "FAIL: cmd_destroy deletes directory on matching confirmation"
    failures=$((failures + 1))
fi

mkdir -p "$tmp_projects_dir/gh-project"
(cd "$tmp_projects_dir/gh-project" && git init --quiet -b master && git remote add origin https://github.com/jackelvinsson/gh-project.git)

set +e
out="$(TURBO_CONFIG_FILE="$tmp_config" "$TURBO_BIN" destroy "gh-project" <<< $'gh-project\nn' 2>&1)"
set -e
if printf '%s\n' "$out" | grep -q "github.com/jackelvinsson/gh-project"; then
    echo "PASS: cmd_destroy detects github remote"
else
    echo "FAIL: cmd_destroy detects github remote"
    failures=$((failures + 1))
fi

if [ ! -d "$tmp_projects_dir/gh-project" ]; then
    echo "PASS: cmd_destroy deletes local dir when github deletion declined"
else
    echo "FAIL: cmd_destroy deletes local dir when github deletion declined"
    failures=$((failures + 1))
fi

mkdir -p "$tmp_projects_dir/local-clone-project"
(cd "$tmp_projects_dir/local-clone-project" && git init --quiet -b master && git remote add origin "https://github.com/jackelvinsson/laravel-template-vue.git")

set +e
out="$(TURBO_CONFIG_FILE="$tmp_config" "$TURBO_BIN" destroy "local-clone-project" <<< "wrong" 2>&1)"
set -e
if printf '%s\n' "$out" | grep -q "github.com"; then
    echo "FAIL: cmd_destroy does not offer to delete template repo for local clones"
    failures=$((failures + 1))
else
    echo "PASS: cmd_destroy does not offer to delete template repo for local clones"
fi

no_gh_path_dir="$(mktemp -d)"
for tool in git curl bash tr sed cut mkdir cat rm; do
    real_path="$(command -v "$tool")"
    ln -s "$real_path" "$no_gh_path_dir/$tool"
done

mkdir -p "$tmp_projects_dir/gh-project2"
(cd "$tmp_projects_dir/gh-project2" && git init --quiet -b master && git remote add origin https://github.com/jackelvinsson/gh-project2.git)

set +e
out="$(TURBO_CONFIG_FILE="$tmp_config" PATH="$no_gh_path_dir" "$TURBO_BIN" destroy "gh-project2" <<< $'gh-project2\ny\ny' 2>&1)"
set -e

if printf '%s\n' "$out" | grep -q "gh is not installed. Cannot delete the GitHub repo."; then
    echo "PASS: cmd_destroy warns when gh unavailable"
else
    echo "FAIL: cmd_destroy warns when gh unavailable"
    failures=$((failures + 1))
fi

if [ ! -d "$tmp_projects_dir/gh-project2" ]; then
    echo "PASS: cmd_destroy still deletes local dir when confirmed despite gh unavailable"
else
    echo "FAIL: cmd_destroy still deletes local dir when confirmed despite gh unavailable"
    failures=$((failures + 1))
fi

mkdir -p "$tmp_projects_dir/gh-project3"
(cd "$tmp_projects_dir/gh-project3" && git init --quiet -b master && git remote add origin https://github.com/jackelvinsson/gh-project3.git)

set +e
out="$(TURBO_CONFIG_FILE="$tmp_config" PATH="$no_gh_path_dir" "$TURBO_BIN" destroy "gh-project3" <<< $'gh-project3\ny\nn' 2>&1)"
status=$?
set -e
assert_status "cmd_destroy exits 0 when local deletion declined after gh unavailable" "0" "$status"

if [ -d "$tmp_projects_dir/gh-project3" ]; then
    echo "PASS: cmd_destroy leaves local dir intact when declined after gh unavailable"
else
    echo "FAIL: cmd_destroy leaves local dir intact when declined after gh unavailable"
    failures=$((failures + 1))
fi

rm -rf "$no_gh_path_dir"

fake_gh_dir="$(mktemp -d)"
cat > "$fake_gh_dir/gh" <<'GHEOF'
#!/usr/bin/env bash
if [ "$1" = "auth" ]; then exit 0; fi
if [ "$1" = "repo" ] && [ "$2" = "delete" ]; then
    echo "HTTP 403: Must have admin rights to Repository." >&2
    exit 1
fi
GHEOF
chmod +x "$fake_gh_dir/gh"

mkdir -p "$tmp_projects_dir/gh-project4"
(cd "$tmp_projects_dir/gh-project4" && git init --quiet -b master && git remote add origin https://github.com/jackelvinsson/gh-project4.git)

set +e
out="$(TURBO_CONFIG_FILE="$tmp_config" PATH="$fake_gh_dir:$PATH" "$TURBO_BIN" destroy "gh-project4" <<< $'gh-project4\ny\nn' 2>&1)"
status=$?
set -e
assert_status "cmd_destroy exits 0 when local deletion declined after gh delete fails" "0" "$status"

if [ -d "$tmp_projects_dir/gh-project4" ]; then
    echo "PASS: cmd_destroy leaves local dir intact when declined after gh delete fails"
else
    echo "FAIL: cmd_destroy leaves local dir intact when declined after gh delete fails"
    failures=$((failures + 1))
fi

set +e
TURBO_CONFIG_FILE="$tmp_config" PATH="$fake_gh_dir:$PATH" "$TURBO_BIN" destroy "gh-project4" <<< $'gh-project4\ny\ny' >/dev/null 2>&1
status=$?
set -e
assert_status "cmd_destroy exits 0 when local deletion confirmed after gh delete fails" "0" "$status"

if [ ! -d "$tmp_projects_dir/gh-project4" ]; then
    echo "PASS: cmd_destroy still deletes local dir when confirmed after gh delete fails"
else
    echo "FAIL: cmd_destroy still deletes local dir when confirmed after gh delete fails"
    failures=$((failures + 1))
fi

rm -rf "$fake_gh_dir"
rm -rf "$tmp_projects_dir"
rm -f "$tmp_config"

echo ""
echo "$failures failure(s)"
exit "$failures"
