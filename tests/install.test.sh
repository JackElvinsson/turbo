#!/usr/bin/env bash
set -uo pipefail

INSTALL_BIN="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/install.sh"
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

# --- Task 9: install.sh ---
fake_source="$(mktemp)"
printf '#!/usr/bin/env bash\necho fake-turbo\n' > "$fake_source"

fake_remote="$(mktemp -d)"
(cd "$fake_remote" && git init --bare -b master --quiet)
work="$(mktemp -d)"
(
    cd "$work"
    git init --quiet -b master
    git config user.email test@example.com
    git config user.name test
    echo x > f.txt
    git add f.txt
    git commit --quiet -m "first"
    git remote add origin "$fake_remote"
    git push --quiet origin master
)
rm -rf "$work"

bin_dir="$(mktemp -d)"
config_file="$(mktemp -d)/config"
version_file="$(mktemp -d)/version"
default_projects_dir="$(mktemp -d)/projects"

PATH="$bin_dir:$PATH" \
TURBO_INSTALL_SOURCE="file://$fake_source" \
TURBO_REPO_URL="$fake_remote" \
INSTALL_BIN_DIR="$bin_dir" \
TURBO_CONFIG_FILE="$config_file" \
TURBO_VERSION_FILE="$version_file" \
DEFAULT_PROJECTS_DIR="$default_projects_dir" \
bash "$INSTALL_BIN" >/dev/null 2>&1

assert_eq "install.sh writes turbo binary" "fake-turbo" "$("$bin_dir/turbo")"

if [ -x "$bin_dir/turbo" ]; then
    echo "PASS: install.sh makes turbo executable"
else
    echo "FAIL: install.sh makes turbo executable"
    failures=$((failures + 1))
fi

assert_eq "install.sh writes default projects dir when no tty is available" "PROJECTS_DIR=$default_projects_dir" "$(cat "$config_file")"

expected_hash="$(git ls-remote "$fake_remote" master | cut -f1)"
assert_eq "install.sh writes version file" "$expected_hash" "$(cat "$version_file")"

# Second run must not re-prompt / overwrite the existing config.
PATH="$bin_dir:$PATH" \
TURBO_INSTALL_SOURCE="file://$fake_source" \
TURBO_REPO_URL="$fake_remote" \
INSTALL_BIN_DIR="$bin_dir" \
TURBO_CONFIG_FILE="$config_file" \
TURBO_VERSION_FILE="$version_file" \
DEFAULT_PROJECTS_DIR="$default_projects_dir" \
bash "$INSTALL_BIN" < /dev/null >/dev/null 2>&1

assert_eq "install.sh does not overwrite existing config on update" "PROJECTS_DIR=$default_projects_dir" "$(cat "$config_file")"

rm -rf "$fake_remote" "$bin_dir" "$(dirname "$config_file")" "$(dirname "$version_file")" "$(dirname "$default_projects_dir")"
rm -f "$fake_source"

echo ""
echo "$failures failure(s)"
exit "$failures"
