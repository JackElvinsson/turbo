#!/usr/bin/env bash
set -euo pipefail

TURBO_REPO_URL="${TURBO_REPO_URL:-https://github.com/jackelvinsson/turbo}"
TURBO_REPO_BRANCH="${TURBO_REPO_BRANCH:-master}"
TURBO_INSTALL_SOURCE="${TURBO_INSTALL_SOURCE:-https://raw.githubusercontent.com/jackelvinsson/turbo/${TURBO_REPO_BRANCH}/turbo}"
INSTALL_BIN_DIR="${INSTALL_BIN_DIR:-$HOME/.local/bin}"
TURBO_CONFIG_FILE="${TURBO_CONFIG_FILE:-$HOME/.config/turbo/config}"
TURBO_VERSION_FILE="${TURBO_VERSION_FILE:-$HOME/.local/share/turbo/version}"
DEFAULT_PROJECTS_DIR="${DEFAULT_PROJECTS_DIR:-/home/jack/PhpstormProjects}"

echo "==> Checking requirements"
for tool in git curl; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "Error: $tool is required but not installed." >&2
        exit 1
    fi
done

echo "==> Installing turbo to $INSTALL_BIN_DIR/turbo"
mkdir -p "$INSTALL_BIN_DIR"
tmp="$(mktemp)"
curl -fsSL "$TURBO_INSTALL_SOURCE" -o "$tmp"
chmod +x "$tmp"
mv "$tmp" "$INSTALL_BIN_DIR/turbo"

case ":$PATH:" in
    *":$INSTALL_BIN_DIR:"*) ;;
    *)
        echo "Warning: $INSTALL_BIN_DIR is not on your PATH. Add it to your shell profile."
        ;;
esac

if [ ! -f "$TURBO_CONFIG_FILE" ]; then
    echo "==> First-time setup"
    projects_dir="$DEFAULT_PROJECTS_DIR"
    read -r -p "Projects directory [$DEFAULT_PROJECTS_DIR]: " projects_dir < /dev/tty || projects_dir="$DEFAULT_PROJECTS_DIR"
    projects_dir="${projects_dir:-$DEFAULT_PROJECTS_DIR}"
    mkdir -p "$(dirname "$TURBO_CONFIG_FILE")"
    echo "PROJECTS_DIR=$projects_dir" > "$TURBO_CONFIG_FILE"
fi

echo "==> Recording installed version"
mkdir -p "$(dirname "$TURBO_VERSION_FILE")"
version="$(git ls-remote "$TURBO_REPO_URL" "$TURBO_REPO_BRANCH" | cut -f1)" && [ -n "$version" ] && printf '%s\n' "$version" > "$TURBO_VERSION_FILE" || echo "Warning: could not record installed version (network?)." >&2

echo ""
echo "turbo installed. Run 'turbo create' to scaffold a new project."
