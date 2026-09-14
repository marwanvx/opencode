#!/usr/bin/env bash
set -euo pipefail

REPO="marwanvx/opencode"
DEFAULT_VERSION="v2.0.3-patch.1"
APP="opencode"

# TTY color configuration
if [ -t 1 ]; then
    MUTED='\033[0;2m'
    RED='\033[0;31m'
    ORANGE='\033[38;5;214m'
    GREEN='\033[0;32m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    MUTED=''
    RED=''
    ORANGE=''
    GREEN=''
    CYAN=''
    BOLD=''
    NC=''
fi

usage() {
    cat <<EOF
OpenCode Installer (Patched Edition)

Usage: install.sh [options]

Options:
    -h, --help              Display this help message
    -v, --version <version> Install a specific release version (default: ${DEFAULT_VERSION})
        --no-modify-path    Don't modify shell config files (.zshrc, .bashrc, etc.)

Examples:
    curl -fsSL https://raw.githubusercontent.com/${REPO}/v2-patched/install.sh | bash
    curl -fsSL https://raw.githubusercontent.com/${REPO}/v2-patched/install.sh | bash -s -- --no-modify-path
EOF
}

requested_version="${VERSION:-$DEFAULT_VERSION}"
no_modify_path=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        -v|--version)
            if [[ -n "${2:-}" ]]; then
                requested_version="$2"
                shift 2
            else
                echo -e "${RED}Error: --version requires a version argument${NC}"
                exit 1
            fi
            ;;
        --no-modify-path)
            no_modify_path=true
            shift
            ;;
        *)
            echo -e "${ORANGE}Warning: Unknown option '$1'${NC}" >&2
            shift
            ;;
    esac
done

# If executed in Windows environments (Git Bash, MSYS, Cygwin), delegate to PowerShell installer
if [ "${OS:-}" = "Windows_NT" ]; then
    if command -v powershell.exe >/dev/null 2>&1; then
        powershell.exe -c "irm https://raw.githubusercontent.com/$REPO/v2-patched/install.ps1 | iex"
        exit $?
    elif command -v pwsh >/dev/null 2>&1; then
        pwsh -c "irm https://raw.githubusercontent.com/$REPO/v2-patched/install.ps1 | iex"
        exit $?
    fi
fi

# Ensure version format has leading 'v'
if [[ "$requested_version" != v* ]]; then
    requested_version="v$requested_version"
fi

# Print stylish header
echo -e ""
echo -e "${CYAN}  █▀▀█ █▀▀█ █▀▀█ █▀▀▄ ${ORANGE}█▀▀▀ █▀▀█ █▀▀█ █▀▀█${NC}"
echo -e "${CYAN}  █░░█ █░░█ █▀▀▀ █░░█ ${ORANGE}█░░░ █░░█ █░░█ █▀▀▀${NC}"
echo -e "${CYAN}  ▀▀▀▀ █▀▀▀ ▀▀▀▀ ▀  ▀ ${ORANGE}▀▀▀▀ ▀▀▀▀ ▀▀▀▀ ▀▀▀▀${NC}"
echo -e "  ${BOLD}OpenCode Installer${NC} ${MUTED}(Patched Edition ${requested_version})${NC}"
echo -e ""

INSTALL_DIR="${OPENCODE_INSTALL_DIR:-$HOME/.opencode/bin}"
mkdir -p "$INSTALL_DIR"

# 1. Detect OS
raw_os=$(uname -s)
case "$raw_os" in
    Darwin*) os="darwin" ;;
    Linux*)  os="linux" ;;
    *)
        echo -e "${RED}Error: Unsupported OS '$raw_os'. For Windows PowerShell, run:${NC}"
        echo "  irm https://raw.githubusercontent.com/$REPO/v2-patched/install.ps1 | iex"
        exit 1
        ;;
esac

# 2. Detect Arch
raw_arch=$(uname -m)
case "$raw_arch" in
    x86_64|amd64) arch="x64" ;;
    arm64|aarch64) arch="arm64" ;;
    *)
        echo -e "${RED}Error: Unsupported architecture '$raw_arch'${NC}"
        exit 1
        ;;
esac

# Handle Rosetta translation on macOS
if [ "$os" = "darwin" ] && [ "$arch" = "x64" ]; then
    if [ "$(sysctl -n sysctl.proc_translated 2>/dev/null || echo 0)" = "1" ]; then
        arch="arm64"
    fi
fi

echo -e "${GREEN}✔${NC} System detected: ${BOLD}${os}-${arch}${NC}"

tarball="opencode-${os}-${arch}.tar.gz"
download_url="https://github.com/${REPO}/releases/download/${requested_version}/${tarball}"

# Spinner helper
spin() {
    local pid=$1
    local msg="$2"
    if [ -t 1 ]; then
        local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
        while kill -0 "$pid" 2>/dev/null; do
            local temp=${spinstr#?}
            printf "\r${ORANGE}%c${NC} %s" "$spinstr" "$msg"
            spinstr=$temp${spinstr%"$temp"}
            sleep 0.08
        done
        printf "\r\033[K"
    else
        wait "$pid"
    fi
}

# 3. Download
tmp_dir="$(mktemp -d)"
cleanup() { rm -rf "$tmp_dir"; }
trap cleanup EXIT

echo -e "${ORANGE}⠋${NC} Downloading ${BOLD}${tarball}${NC} from GitHub releases..."
if [ -t 1 ]; then
    curl --fail --location --retry 5 --retry-delay 2 --retry-connrefused -# -o "$tmp_dir/$tarball" "$download_url"
else
    curl --fail --location --retry 5 --retry-delay 2 --retry-connrefused -sSL -o "$tmp_dir/$tarball" "$download_url"
fi
echo -e "${GREEN}✔${NC} Download complete"

# 4. Extract & Install with spinner
(tar -xzf "$tmp_dir/$tarball" -C "$tmp_dir") &
spin $! "Unpacking release archive..."
wait $!

mv "$tmp_dir/opencode" "$INSTALL_DIR/opencode.new"
chmod 755 "$INSTALL_DIR/opencode.new"
mv -f "$INSTALL_DIR/opencode.new" "$INSTALL_DIR/opencode"
echo -e "${GREEN}✔${NC} Installed binary to ${MUTED}$INSTALL_DIR/opencode${NC}"

# 5. Legacy shim for opencode2
install_legacy_shim() {
    rm -f "$INSTALL_DIR/opencode2"
    cat > "$INSTALL_DIR/opencode2" <<'EOF'
#!/bin/sh
exec "$(dirname "$0")/opencode" "$@"
EOF
    chmod 755 "$INSTALL_DIR/opencode2"
}
install_legacy_shim
echo -e "${GREEN}✔${NC} Configured legacy shim ${MUTED}(opencode2 -> opencode)${NC}"

# 6. Shell PATH Configuration
add_to_path() {
    local config_file="$1"
    local command="$2"

    if grep -qs "$command" "$config_file" 2>/dev/null; then
        return 0
    elif [ -w "$config_file" ]; then
        echo -e "\n# opencode" >> "$config_file"
        echo "$command" >> "$config_file"
    fi
}

if [ "$no_modify_path" != "true" ]; then
    current_shell=$(basename "${SHELL:-bash}")
    case "$current_shell" in
        fish)
            config_files="$HOME/.config/fish/config.fish"
            ;;
        zsh)
            config_files="${ZDOTDIR:-$HOME}/.zshrc $HOME/.zshenv"
            ;;
        bash)
            config_files="$HOME/.bashrc $HOME/.bash_profile $HOME/.profile"
            ;;
        ash|sh)
            config_files="$HOME/.profile /etc/profile"
            ;;
        *)
            config_files="$HOME/.bashrc $HOME/.profile"
            ;;
    esac

    target_config=""
    for file in $config_files; do
        if [ -f "$file" ]; then
            target_config="$file"
            break
        fi
    done

    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        if [ -n "$target_config" ]; then
            case "$current_shell" in
                fish)
                    add_to_path "$target_config" "fish_add_path $INSTALL_DIR"
                    ;;
                *)
                    add_to_path "$target_config" "export PATH=\"$INSTALL_DIR:\$PATH\""
                    ;;
            esac
            echo -e "${GREEN}✔${NC} Added ${MUTED}$INSTALL_DIR${NC} to PATH in ${MUTED}$target_config${NC}"
        fi
    else
        echo -e "${GREEN}✔${NC} PATH already configured"
    fi
fi

if [ -n "${GITHUB_ACTIONS-}" ] && [ "${GITHUB_ACTIONS}" == "true" ]; then
    echo "$INSTALL_DIR" >> "$GITHUB_PATH"
fi

# Print final celebratory summary
echo -e ""
echo -e "${GREEN}${BOLD}✨ OpenCode ${requested_version} (Patched Edition) installed successfully!${NC}"
echo -e ""
echo -e "${BOLD}Active Patches Included:${NC}"
echo -e "   • ${CYAN}TUI Startup Crash:${NC} Fixes startup exception & model #variant parsing (#48978)"
echo -e "   • ${CYAN}Stale Reasoning:${NC} Auto-recovers on IP/gateway routing changes (#48908)"
echo -e "   • ${CYAN}Merman State:${NC} Fixes infinite loop in state transitions (#48898)"
echo -e "   • ${CYAN}npm Launcher:${NC} Direct runtime binary launcher for npm v12 (#48885)"
echo -e ""
echo -e "Run: ${BOLD}${CYAN}opencode${NC}"
echo -e ""
