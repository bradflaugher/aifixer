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

AIFIXER_VERSION="2.1.0"
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
    BOLD=$(tput bold 2>/dev/null || echo '')
    RESET=$(tput sgr0 2>/dev/null || echo '')
else
    RED='' GREEN='' YELLOW='' BLUE='' BOLD='' RESET=''
fi

# Output helpers
info() { printf "${BLUE}==>${RESET} %s\n" "$*"; }
success() { printf "${GREEN}✓${RESET} %s\n" "$*"; }
warn() { printf "${YELLOW}⚠${RESET}  %s\n" "$*" >&2; }
error() { printf "${RED}✗${RESET} %s\n" "$*" >&2; }
die() { error "$*"; exit 1; }

# ─── System Detection ─────────────────────────────────────────────────────────

detect_os() {
    case "$(uname -s)" in
        Darwin*) echo "macos" ;;
        Linux*) echo "linux" ;;
        MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
        *) echo "unknown" ;;
    esac
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
        info "Downloading latest version..."
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
                echo "To set it later, run:"
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
        echo "  source $(get_shell_config_file "$(detect_shell)")"
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
    echo "${BOLD}AIFixer Installer${RESET}"
    echo "────────────────────────────"
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
Usage: $0 [options]

Options:
  --prefix DIR       Install to DIR/bin instead of auto-detecting
  --skip-api-key     Don't prompt for OpenRouter API key
  --help             Show this help message

Environment:
  PREFIX             Installation directory (same as --prefix)

Examples:
  # Standard installation
  curl -fsSL https://install.aifixer.com | sh
  
  # Install to custom location
  curl -fsSL https://install.aifixer.com | PREFIX=~/.local sh
  
  # Install without API key prompt
  curl -fsSL https://install.aifixer.com | sh -s -- --skip-api-key
EOF
                exit 0
                ;;
            *) die "Unknown option: $1" ;;
        esac
    done
    
    # Run installation steps
    install_dir=$(get_install_dir)
    install_aifixer "$install_dir"
    configure_path "$install_dir"
    configure_api_key
    verify_installation
    
    # Success message
    echo
    echo "${GREEN}${BOLD}✨ Installation complete!${RESET}"
    echo
    echo "Get started with:"
    echo "  ${BOLD}$COMMAND_NAME --help${RESET}"
    echo
    
    # Remind about shell restart if needed
    if ! command -v "$COMMAND_NAME" >/dev/null 2>&1; then
        echo "${YELLOW}Note:${RESET} You may need to restart your shell or run:"
        echo "  source $(get_shell_config_file "$(detect_shell)")"
        echo
    fi
}

# Run installer
main "$@"
