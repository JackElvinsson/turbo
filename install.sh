#!/usr/bin/env bash
set -euo pipefail

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    C_STEP=$'\033[1;36m'
    C_ERR=$'\033[0;31m'
    C_WARN=$'\033[0;33m'
    C_OK=$'\033[0;32m'
    C_RESET=$'\033[0m'
else
    C_STEP='' C_ERR='' C_WARN='' C_OK='' C_RESET=''
fi

TURBO_REPO_URL="${TURBO_REPO_URL:-https://github.com/jackelvinsson/turbo}"
TURBO_REPO_BRANCH="${TURBO_REPO_BRANCH:-master}"
TURBO_INSTALL_SOURCE="${TURBO_INSTALL_SOURCE:-https://raw.githubusercontent.com/jackelvinsson/turbo/${TURBO_REPO_BRANCH}/turbo}"
INSTALL_BIN_DIR="${INSTALL_BIN_DIR:-$HOME/.local/bin}"
TURBO_CONFIG_FILE="${TURBO_CONFIG_FILE:-$HOME/.config/turbo/config}"
TURBO_VERSION_FILE="${TURBO_VERSION_FILE:-$HOME/.local/share/turbo/version}"
DEFAULT_PROJECTS_DIR="${DEFAULT_PROJECTS_DIR:-/home/jack/PhpstormProjects}"

echo "${C_STEP}==> Checking requirements${C_RESET}"
for tool in git curl; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "${C_ERR}Error: $tool is required but not installed.${C_RESET}" >&2
        exit 1
    fi
done

echo "${C_STEP}==> Installing turbo to $INSTALL_BIN_DIR/turbo${C_RESET}"
mkdir -p "$INSTALL_BIN_DIR"
tmp="$(mktemp)"
curl -fsSL "$TURBO_INSTALL_SOURCE" -o "$tmp"
chmod +x "$tmp"
mv "$tmp" "$INSTALL_BIN_DIR/turbo"

case ":$PATH:" in
    *":$INSTALL_BIN_DIR:"*) ;;
    *)
        echo "${C_WARN}Warning: $INSTALL_BIN_DIR is not on your PATH. Add it to your shell profile.${C_RESET}"
        ;;
esac

if [ ! -f "$TURBO_CONFIG_FILE" ]; then
    echo "${C_STEP}==> First-time setup${C_RESET}"
    projects_dir="$DEFAULT_PROJECTS_DIR"
    read -r -p "Projects directory [$DEFAULT_PROJECTS_DIR]: " projects_dir < /dev/tty || projects_dir="$DEFAULT_PROJECTS_DIR"
    projects_dir="${projects_dir:-$DEFAULT_PROJECTS_DIR}"
    mkdir -p "$(dirname "$TURBO_CONFIG_FILE")"
    echo "PROJECTS_DIR=$projects_dir" > "$TURBO_CONFIG_FILE"
fi

echo "${C_STEP}==> Recording installed version${C_RESET}"
mkdir -p "$(dirname "$TURBO_VERSION_FILE")"
version="$(git ls-remote "$TURBO_REPO_URL" "$TURBO_REPO_BRANCH" | cut -f1)" && [ -n "$version" ] && printf '%s\n' "$version" > "$TURBO_VERSION_FILE" || echo "${C_WARN}Warning: could not record installed version (network?).${C_RESET}" >&2

echo ""
echo "${C_OK}turbo installed. Run 'turbo create' to scaffold a new project.${C_RESET}"
