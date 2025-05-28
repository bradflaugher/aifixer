#!/bin/sh
# AIFixer installer - Simple, robust installation for all platforms
# 
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/bradflaugher/aifixer/main/install.sh | sh
#   wget -qO- https://raw.githubusercontent.com/bradflaugher/aifixer/main/install.sh | sh
#
# Or download and run:
#   ./install.sh [options]

set -e

# ─── Configuration ────────────────────────────────────────────────────────────

AIFIXER_VERSION="3.0.0"
GITHUB_REPO="bradflaugher/aifixer"
SCRIPT_NAME="aifixer.sh"
COMMAND_NAME="aifixer"

# ─── Colors & Output ──────────────────────────────────────────────────────────

# Detect color support
if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
    RED=$(tput setaf 1 2>/dev/null || echo '')
    GREEN=$(tput setaf 2 2>/dev/null || echo '')
    YELLOW=$(tput setaf 3 2>/dev/null || echo '')
    BLUE=$(tput setaf 4 2>/dev/null || echo '')
    MAGENTA=$(tput setaf 5 2>/dev/null || echo '')
    CYAN=$(tput setaf 6 2>/dev/null || echo '')
    BOLD=$(tput bold 2>/dev/null || echo '')
    DIM=$(tput dim 2>/dev/null || echo '')
    RESET=$(tput sgr0 2>/dev/null || echo '')
else
    RED='' GREEN='' YELLOW='' BLUE='' MAGENTA='' CYAN='' BOLD='' DIM='' RESET=''
fi

# Output helpers
info() { printf "${BLUE}==>${RESET} %s\n" "$*"; }
success() { printf "${GREEN}✓${RESET} %s\n" "$*"; }
warn() { printf "${YELLOW}⚠${RESET}  %s\n" "$*" >&2; }
error() { printf "${RED}✗${RESET} %s\n" "$*" >&2; }
die() { error "$*"; exit 1; }
step() { printf "${CYAN}◆${RESET} %s\n" "$*"; }

# ─── System Detection ─────────────────────────────────────────────────────────

detect_os() {
    case "$(uname -s)" in
        Darwin*) echo "macos" ;;
        Linux*) echo "linux" ;;
        MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
        *) echo "unknown" ;;
    esac
}

detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    elif [ -f /etc/debian_version ]; then
        echo "debian"
    elif [ -f /etc/redhat-release ]; then
        echo "rhel"
    elif [ -f /etc/alpine-release ]; then
        echo "alpine"
    else
        echo "unknown"
    fi
}

detect_package_manager() {
    if command -v brew >/dev/null 2>&1; then
        echo "brew"
    elif command -v apt-get >/dev/null 2>&1; then
        echo "apt"
    elif command -v dnf >/dev/null 2>&1; then
        echo "dnf"
    elif command -v yum >/dev/null 2>&1; then
        echo "yum"
    elif command -v apk >/dev/null 2>&1; then
        echo "apk"
    elif command -v pacman >/dev/null 2>&1; then
        echo "pacman"
    elif command -v zypper >/dev/null 2>&1; then
        echo "zypper"
    else
        echo "none"
    fi
}

detect_shell() {
    # First check SHELL env var
    if [ -n "${SHELL-}" ]; then
        case "$SHELL" in
            */bash) echo "bash" ;;
            */zsh) echo "zsh" ;;
            */fish) echo "fish" ;;
            */sh) echo "sh" ;;
            *) echo "sh" ;;
        esac
        return
    fi
    
    # Fallback to checking what's available
    if command -v bash >/dev/null 2>&1; then echo "bash"
    elif command -v zsh >/dev/null 2>&1; then echo "zsh"
    else echo "sh"
    fi
}

get_shell_config_file() {
    shell="$1"
    
    case "$shell" in
        bash)
            # macOS uses .bash_profile, Linux uses .bashrc
            if [ "$(detect_os)" = "macos" ]; then
                echo "$HOME/.bash_profile"
            else
                echo "$HOME/.bashrc"
            fi
            ;;
        zsh) echo "$HOME/.zshrc" ;;
        fish) echo "$HOME/.config/fish/config.fish" ;;
        *) echo "$HOME/.profile" ;;  # Universal fallback
    esac
}

# ─── Dependency Installation ──────────────────────────────────────────────────

check_sudo() {
    if [ "$(id -u)" -eq 0 ]; then
        echo ""  # Already root
    elif command -v sudo >/dev/null 2>&1; then
        echo "sudo"
    elif command -v doas >/dev/null 2>&1; then
        echo "doas"
    else
        return 1
    fi
}

install_jq() {
    info "Installing jq..."
    
    pkg_mgr=$(detect_package_manager)
    os=$(detect_os)
    
    case "$pkg_mgr" in
        brew)
            step "Using Homebrew"
            brew install jq || die "Failed to install jq with Homebrew"
            ;;
        apt)
            step "Using apt"
            sudo_cmd=$(check_sudo) || die "Need sudo/root to install jq"
            $sudo_cmd apt-get update -qq
            $sudo_cmd apt-get install -y jq || die "Failed to install jq with apt"
            ;;
        dnf)
            step "Using dnf"
            sudo_cmd=$(check_sudo) || die "Need sudo/root to install jq"
            $sudo_cmd dnf install -y jq || die "Failed to install jq with dnf"
            ;;
        yum)
            step "Using yum"
            sudo_cmd=$(check_sudo) || die "Need sudo/root to install jq"
            $sudo_cmd yum install -y jq || die "Failed to install jq with yum"
            ;;
        apk)
            step "Using apk"
            sudo_cmd=$(check_sudo) || die "Need sudo/root to install jq"
            $sudo_cmd apk add --no-cache jq || die "Failed to install jq with apk"
            ;;
        pacman)
            step "Using pacman"
            sudo_cmd=$(check_sudo) || die "Need sudo/root to install jq"
            $sudo_cmd pacman -S --noconfirm jq || die "Failed to install jq with pacman"
            ;;
        zypper)
            step "Using zypper"
            sudo_cmd=$(check_sudo) || die "Need sudo/root to install jq"
            $sudo_cmd zypper install -y jq || die "Failed to install jq with zypper"
            ;;
        none)
            # Try to install package manager first
            if [ "$os" = "macos" ]; then
                warn "No package manager found. Install Homebrew first:"
                echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
                die "Cannot proceed without a package manager"
            else
                die "No supported package manager found. Please install jq manually."
            fi
            ;;
    esac
    
    success "jq installed successfully"
}

check_dependencies() {
    echo
    info "Checking dependencies..."
    
    missing=0
    
    # Check curl
    if command -v curl >/dev/null 2>&1; then
        success "curl is installed"
    else
        error "curl is required but not installed"
        missing=1
    fi
    
    # Check jq
    if command -v jq >/dev/null 2>&1; then
        version=$(jq --version 2>/dev/null | sed 's/jq-//')
        success "jq is installed (version: $version)"
    else
        warn "jq is required but not installed"
        
        # Ask to install
        if [ -t 0 ] && [ -e /dev/tty ]; then
            printf "Install jq now? [Y/n] "
            read -r response < /dev/tty || true
            case "$response" in
                [Nn]*) 
                    error "jq is required for AIFixer to work"
                    die "Please install jq manually and run this installer again"
                    ;;
                *)
                    install_jq
                    ;;
            esac
        else
            error "jq is required but not installed"
            error "Please install jq manually:"
            error "  macOS: brew install jq"
            error "  Ubuntu/Debian: sudo apt-get install jq"
            error "  RHEL/CentOS: sudo yum install jq"
            error "  Alpine: sudo apk add jq"
            die "Cannot proceed without jq"
        fi
    fi
    
    if [ $missing -eq 1 ]; then
        die "Missing required dependencies"
    fi
}

# ─── Installation Directory Selection ─────────────────────────────────────────

get_install_dir() {
    # Check if user specified a directory
    if [ -n "${PREFIX-}" ]; then
        echo "${PREFIX%/}/bin"
        return
    fi
    
    # Check for existing aifixer installation
    if command -v "$COMMAND_NAME" >/dev/null 2>&1; then
        existing_path=$(command -v "$COMMAND_NAME")
        existing_dir=$(dirname "$existing_path")
        
        # If it's in a standard location and writable, use it
        case "$existing_dir" in
            /usr/local/bin|"$HOME/.local/bin"|"$HOME/bin")
                if [ -w "$existing_dir" ]; then
                    echo "$existing_dir"
                    return
                fi
                ;;
        esac
    fi
    
    # Try standard locations in order
    for dir in "$HOME/.local/bin" "$HOME/bin" "/usr/local/bin"; do
        if [ -d "$dir" ] && [ -w "$dir" ]; then
            echo "$dir"
            return
        elif [ "$dir" != "/usr/local/bin" ] && mkdir -p "$dir" 2>/dev/null; then
            echo "$dir"
            return
        fi
    done
    
    # Last resort
    last_resort="$HOME/.aifixer/bin"
    mkdir -p "$last_resort" 2>/dev/null || die "Cannot create installation directory"
    echo "$last_resort"
}

# ─── Download Functions ───────────────────────────────────────────────────────

download_file() {
    url="$1"
    output="$2"
    
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url" -o "$output" || return 1
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$output" "$url" || return 1
    else
        die "Neither curl nor wget found. Please install one of them."
    fi
}

get_script_source() {
    # Check if we're running from a local checkout
    script_dir=$(dirname "$0")
    local_script="$script_dir/$SCRIPT_NAME"
    
    if [ -f "$local_script" ] && [ -r "$local_script" ]; then
        echo "local"
        echo "$local_script"
    else
        echo "remote"
        echo "https://raw.githubusercontent.com/$GITHUB_REPO/main/$SCRIPT_NAME"
    fi
}

# ─── Installation ─────────────────────────────────────────────────────────────

install_aifixer() {
    install_dir="$1"
    target_path="$install_dir/$COMMAND_NAME"
    
    # Get source
    source_info=$(get_script_source)
    source_type=$(echo "$source_info" | head -1)
    source_path=$(echo "$source_info" | tail -1)
    
    # Check if updating
    is_update=0
    if [ -f "$target_path" ]; then
        is_update=1
        info "Updating existing installation"
    else
        info "Installing $COMMAND_NAME to $install_dir"
    fi
    
    # Download or copy
    if [ "$source_type" = "local" ]; then
        cp "$source_path" "$target_path" || die "Failed to copy script"
    else
        step "Downloading latest version..."
        temp_file=$(mktemp 2>/dev/null || mktemp -t 'aifixer')
        if ! download_file "$source_path" "$temp_file"; then
            rm -f "$temp_file"
            die "Download failed"
        fi
        mv "$temp_file" "$target_path" || die "Failed to install script"
    fi
    
    # Make executable
    chmod +x "$target_path" || warn "Could not make script executable"
    
    if [ $is_update -eq 1 ]; then
        success "Updated $COMMAND_NAME successfully"
    else
        success "Installed $COMMAND_NAME successfully"
    fi
}

# ─── PATH Configuration ───────────────────────────────────────────────────────

configure_path() {
    install_dir="$1"
    
    # Check if already in PATH
    case ":$PATH:" in
        *":$install_dir:"*) 
            success "Installation directory already in PATH"
            return 0
            ;;
    esac
    
    info "Adding $install_dir to PATH"
    
    # Add to current session
    export PATH="$install_dir:$PATH"
    
    # Add to shell config
    shell=$(detect_shell)
    config_file=$(get_shell_config_file "$shell")
    
    # Create config directory if needed
    config_dir=$(dirname "$config_file")
    [ -d "$config_dir" ] || mkdir -p "$config_dir" 2>/dev/null || true
    
    # Prepare the line to add
    if [ "$shell" = "fish" ]; then
        path_line="set -gx PATH $install_dir \$PATH"
    else
        path_line="export PATH=\"$install_dir:\$PATH\""
    fi
    
    # Add to config if not already present
    if [ -w "$config_file" ] || [ ! -e "$config_file" ]; then
        if ! grep -qF "$install_dir" "$config_file" 2>/dev/null; then
            {
                echo ""
                echo "# Added by AIFixer installer"
                echo "$path_line"
            } >> "$config_file"
            success "Added to $config_file"
        fi
    else
        warn "Could not update $config_file (not writable)"
        echo
        echo "Add this line to your shell configuration:"
        echo "  $path_line"
    fi
}

# ─── API Key Configuration ────────────────────────────────────────────────────

configure_api_key() {
    # Skip if --skip-api-key was used
    [ "${SKIP_API_KEY:-0}" = "1" ] && return 0
    
    # Skip in non-interactive environments
    if ! [ -t 0 ] && ! [ -e /dev/tty ]; then
        return 0
    fi
    
    echo
    info "OpenRouter API Key Configuration"
    
    # Check existing key
    if [ -n "${OPENROUTER_API_KEY-}" ]; then
        success "API key already set in environment"
        printf "Update it? [y/N] "
        read -r response < /dev/tty || return 0
        case "$response" in
            [Yy]*) ;;
            *) return 0 ;;
        esac
    else
        printf "Configure OpenRouter API key now? [Y/n] "
        read -r response < /dev/tty || return 0
        case "$response" in
            [Nn]*) 
                echo
                echo "${DIM}To set it later, run:${RESET}"
                echo "  export OPENROUTER_API_KEY=\"your-key-here\""
                return 0
                ;;
        esac
    fi
    
    # Read API key
    printf "Enter your API key: "
    stty -echo 2>/dev/null || true
    read -r api_key < /dev/tty || true
    stty echo 2>/dev/null || true
    echo
    
    [ -z "$api_key" ] && return 0
    
    # Set for current session
    export OPENROUTER_API_KEY="$api_key"
    
    # Add to shell config
    shell=$(detect_shell)
    config_file=$(get_shell_config_file "$shell")
    
    if [ "$shell" = "fish" ]; then
        key_line="set -gx OPENROUTER_API_KEY \"$api_key\""
    else
        key_line="export OPENROUTER_API_KEY=\"$api_key\""
    fi
    
    if [ -w "$config_file" ] || [ ! -e "$config_file" ]; then
        # Remove any existing key first
        if [ -f "$config_file" ]; then
            temp_file=$(mktemp)
            grep -v "OPENROUTER_API_KEY" "$config_file" > "$temp_file" 2>/dev/null || true
            mv "$temp_file" "$config_file"
        fi
        
        # Add new key
        {
            echo ""
            echo "# AIFixer API key"
            echo "$key_line"
        } >> "$config_file"
        success "API key saved to $config_file"
    else
        warn "Could not save to $config_file"
        echo "Add this line manually:"
        echo "  $key_line"
    fi
}

# ─── Verification ─────────────────────────────────────────────────────────────

verify_installation() {
    echo
    info "Verifying installation..."
    
    # Check if command is available
    if command -v "$COMMAND_NAME" >/dev/null 2>&1; then
        version=$("$COMMAND_NAME" --version 2>/dev/null || echo "unknown")
        success "$COMMAND_NAME is available (version: $version)"
    else
        warn "$COMMAND_NAME not found in PATH"
        warn "You may need to restart your shell or run:"
        echo "  ${CYAN}source $(get_shell_config_file "$(detect_shell)")${RESET}"
    fi
    
    # Check API key
    if [ -n "${OPENROUTER_API_KEY-}" ]; then
        success "API key is configured"
    else
        info "No API key set. AIFixer will work with Ollama, but OpenRouter requires a key."
    fi
}

# ─── Main ─────────────────────────────────────────────────────────────────────

print_banner() {
    echo
    echo "${BOLD}${MAGENTA}╔═══════════════════════════════╗${RESET}"
    echo "${BOLD}${MAGENTA}║${RESET}     ${BOLD}AIFixer Installer${RESET}        ${BOLD}${MAGENTA}║${RESET}"
    echo "${BOLD}${MAGENTA}║${RESET}  ${DIM}Terminal AI Assistant${RESET}       ${BOLD}${MAGENTA}║${RESET}"
    echo "${BOLD}${MAGENTA}╚═══════════════════════════════╝${RESET}"
    echo
}

main() {
    print_banner
    
    # Parse arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --prefix) PREFIX="$2"; shift 2 ;;
            --skip-api-key) SKIP_API_KEY=1; shift ;;
            --help|-h)
                cat <<EOF
${BOLD}Usage:${RESET} $0 [options]

${BOLD}Options:${RESET}
  --prefix DIR       Install to DIR/bin instead of auto-detecting
  --skip-api-key     Don't prompt for OpenRouter API key
  --help             Show this help message

${BOLD}Environment:${RESET}
  PREFIX             Installation directory (same as --prefix)

${BOLD}Examples:${RESET}
  # Standard installation
  ${DIM}curl -fsSL https://install.aifixer.com | sh${RESET}
  
  # Install to custom location
  ${DIM}curl -fsSL https://install.aifixer.com | PREFIX=~/.local sh${RESET}
  
  # Install without API key prompt
  ${DIM}curl -fsSL https://install.aifixer.com | sh -s -- --skip-api-key${RESET}
EOF
                exit 0
                ;;
            *) die "Unknown option: $1" ;;
        esac
    done
    
    # Run installation steps
    check_dependencies
    install_dir=$(get_install_dir)
    
    echo
    install_aifixer "$install_dir"
    configure_path "$install_dir"
    configure_api_key
    verify_installation
    
    # Success message
    echo
    echo "${GREEN}${BOLD}✨ Installation complete!${RESET}"
    echo
    echo "Get started with:"
    echo "  ${BOLD}${CYAN}$COMMAND_NAME --help${RESET}"
    echo
    
    # Remind about shell restart if needed
    if ! command -v "$COMMAND_NAME" >/dev/null 2>&1; then
        echo "${YELLOW}Note:${RESET} You may need to restart your shell or run:"
        echo "  ${CYAN}source $(get_shell_config_file "$(detect_shell)")${RESET}"
        echo
    fi
}

# Run installer
main "$@"
