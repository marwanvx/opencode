#!/usr/bin/env bash
set -euo pipefail

REPO="marwanvx/opencode"
VERSION="v2.0.3-patch.1"
INSTALL_DIR="${OPENCODE_INSTALL_DIR:-$HOME/.opencode/bin}"

# If executed on Windows (Git Bash, MSYS, Cygwin), delegate to PowerShell installer
if [ "${OS:-}" = "Windows_NT" ]; then
  powershell -c "irm https://raw.githubusercontent.com/$REPO/v2-patched/install.ps1 | iex"
  exit $?
fi

# 1. Detect OS
RAW_OS="$(uname -s)"
case "$RAW_OS" in
  Darwin*) OS="darwin" ;;
  Linux*)  OS="linux" ;;
  *)
    echo "Error: Unsupported OS '$RAW_OS'. For Windows, run:"
    echo "  irm https://raw.githubusercontent.com/$REPO/v2-patched/install.ps1 | iex"
    exit 1
    ;;
esac

# 2. Detect Arch
RAW_ARCH="$(uname -m)"
case "$RAW_ARCH" in
  x86_64|amd64) ARCH="x64" ;;
  arm64|aarch64) ARCH="arm64" ;;
  *)
    echo "Error: Unsupported architecture '$RAW_ARCH'"
    exit 1
    ;;
esac

# Handle Rosetta translation on macOS
if [ "$OS" = "darwin" ] && [ "$ARCH" = "x64" ]; then
  if [ "$(sysctl -n sysctl.proc_translated 2>/dev/null || echo 0)" = "1" ]; then
    ARCH="arm64"
  fi
fi

TARBALL="opencode-${OS}-${ARCH}.tar.gz"
DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${VERSION}/${TARBALL}"

echo "==> Installing OpenCode (${VERSION}) for ${OS}-${ARCH}..."
mkdir -p "$INSTALL_DIR"

# 3. Download & Extract safely
TMP_DIR="$(mktemp -d)"
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

curl -fsSL "$DOWNLOAD_URL" | tar -xz -C "$TMP_DIR"

# Atomic binary replacement on same filesystem avoids ETXTBSY if opencode is running
mv "$TMP_DIR/opencode" "$INSTALL_DIR/opencode.new"
chmod +x "$INSTALL_DIR/opencode.new"
mv -f "$INSTALL_DIR/opencode.new" "$INSTALL_DIR/opencode"

# 4. Configure PATH if needed
add_to_path() {
  local rc_file="$1"
  if [ -f "$rc_file" ]; then
    if ! grep -qs '/.opencode/bin' "$rc_file"; then
      printf "\n" >> "$rc_file"
      case "$rc_file" in
        *fish*)
          echo 'fish_add_path $HOME/.opencode/bin' >> "$rc_file"
          ;;
        *)
          echo 'export PATH="$HOME/.opencode/bin:$PATH"' >> "$rc_file"
          ;;
      esac
      echo "==> Added ~/.opencode/bin to PATH in $rc_file"
    fi
  fi
}

case ":$PATH:" in
  *":$HOME/.opencode/bin:"*) ;;
  *)
    add_to_path "$HOME/.bashrc"
    add_to_path "$HOME/.zshrc"
    add_to_path "$HOME/.config/fish/config.fish" 2>/dev/null || true
    ;;
esac

echo ""
echo "✅ OpenCode ${VERSION} installed successfully to ${INSTALL_DIR}/opencode"
echo "✅ Active Fixes:"
echo "   • TUI startup crash & model #variant parsing (#48978)"
echo "   • Stale encrypted reasoning recovery & replay durability (#48908)"
echo "   • Merman state transition infinite loop fix (#48898)"
echo "   • Standalone runtime launcher for npm v12 (#48885)"
echo ""
echo "Run: opencode"
