#!/bin/sh
# ------------------------------------------------------------------
#  AIFixer install script (POSIX sh version)
#  Installs the `aifixer` command and (optionally) sets OPENROUTER_API_KEY
# ------------------------------------------------------------------
set -e

# ------------------------------ constants -------------------------
REPO_RAW_URL="https://raw.githubusercontent.com/bradflaugher/aifixer/main"
AIFIXER_SCRIPT="aifixer.sh"
INSTALL_NAME="aifixer"

# ------------------------------ logging helpers ------------------
log() { printf '%s\n' "👉  $*"; }
die() { printf '%s\n' "❌  $*" >&2; exit 1; }

# ------------------------------ cli flags -------------------------
PREFIX="${PREFIX:-}"
ASK_API_KEY=1
API_KEY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --prefix|-p) PREFIX="$2"; shift 2 ;;
    --api-key|-k) API_KEY="$2"; ASK_API_KEY=0; shift 2 ;;
    --skip-api-key) ASK_API_KEY=0; shift ;;
    -h|--help)
cat <<EOF
Usage: ./install.sh [options]

  --prefix, -p DIR       Install aifixer into DIR/bin (default: autodetect).
                         On iOS/a-shell, defaults to ~/Documents/bin
  --api-key, -k KEY      Persist KEY as OPENROUTER_API_KEY non-interactively.
  --skip-api-key         Do not prompt to set an API key.
  --help                 Show this help and exit.
  
Examples:
  # Install to default location
  ./install.sh
  
  # Install to custom location (useful on iOS)
  ./install.sh --prefix ~/Documents
EOF
      exit 0 ;;
    *) die "Unknown flag: $1" ;;
  esac
done

# ------------------------------ utils -----------------------------
command_exists() { command -v "$1" >/dev/null 2>&1; }

check_deps() {
  # Check for curl if we need to download
  script_dir=$(dirname "$0")
  if [ ! -f "$script_dir/$AIFIXER_SCRIPT" ]; then
    if ! command_exists curl; then
      die "curl is required to download aifixer but not found. Please install curl first."
    fi
  fi
  
  # Just warn about other tools that aifixer might need
  log "Checking for tools that aifixer may require..."
  missing=""
  for bin in awk grep sed; do
    if ! command_exists "$bin"; then
      missing="$missing $bin"
    fi
  done
  
  if [ -n "$missing" ]; then
    log "⚠️  Warning: The following tools may be needed by aifixer but are not installed:$missing"
    log "   You may need to install them manually if aifixer doesn't work properly."
  else
    log "All recommended tools are present. ✅"
  fi
}

pick_install_dir() {
  if [ -n "$PREFIX" ]; then
    echo "$PREFIX/bin"
    return
  fi
  
  # Check if we're in a-shell on iOS
  if [ -n "$ASHELL" ] || [ -f "$HOME/.shortcuts/README" ]; then
    # a-shell detected - use ~/Documents/bin which is writable
    echo "$HOME/Documents/bin"
    return
  fi
  
  # Try standard locations on other systems
  system_dir="/usr/local/bin"
  if [ -w "$system_dir" ]; then
    echo "$system_dir"
  else
    # First try to create ~/.local/bin to test if it's allowed
    if mkdir -p "$HOME/.local/bin" 2>/dev/null; then
      echo "$HOME/.local/bin"
    else
      # Fallback to ~/bin if ~/.local/bin fails
      echo "$HOME/bin"
    fi
  fi
}

install_aifixer() {
  target_dir=$1
  if ! mkdir -p "$target_dir" 2>/dev/null; then
    die "Cannot create directory $target_dir - permission denied. Try using --prefix to specify a writable location."
  fi

  source_path=""
  script_dir=$(dirname "$0")
  if [ -f "$script_dir/$AIFIXER_SCRIPT" ]; then
    source_path="$script_dir/$AIFIXER_SCRIPT"
    log "Installing local $AIFIXER_SCRIPT..."
  else
    # If not local, download to a temp location first, then install
    temp_script=$(mktemp 2>/dev/null || mktemp -t 'aifixer_download')
    source_path="$temp_script"
    log "Fetching latest $AIFIXER_SCRIPT from GitHub…"
    curl -fsSL "$REPO_RAW_URL/$AIFIXER_SCRIPT" -o "$source_path" \
      || die "Download failed."
  fi

  # Use cp and chmod for maximum portability (install command may not exist)
  if ! cp "$source_path" "$target_dir/$INSTALL_NAME" 2>/dev/null; then
    die "Cannot copy to $target_dir/$INSTALL_NAME - permission denied"
  fi
  chmod 755 "$target_dir/$INSTALL_NAME" 2>/dev/null || true
  log "Installed $INSTALL_NAME → $target_dir/$INSTALL_NAME"

  # Clean up temp file if we downloaded
  if [ -n "$temp_script" ] && [ -f "$temp_script" ]; then
      rm "$temp_script"
  fi
}

ensure_path() {
  dir=$1
  case ":$PATH:" in
    *":$dir:"*) return ;;
  esac

  log "ℹ️  '$dir' not on PATH – adding for this session."
  PATH="$dir:$PATH"
  export PATH
  
  # Special handling for a-shell
  if [ -n "$ASHELL" ] || [ -f "$HOME/.shortcuts/README" ]; then
    printf '\n# For a-shell, add this to your .profile or .bashrc:\nexport PATH="%s:$PATH"\n' "$dir"
    printf '# Or create a shortcut in a-shell with: jump aifixer\n'
  else
    printf '\n# Add to your shell profile for permanence:\nexport PATH="%s:$PATH"\n' "$dir"
  fi
}

persist_api_key() {
  key=$1
  shell_name=$(basename "${SHELL:-sh}")
  
  # Check for a-shell first
  if [ -n "$ASHELL" ] || [ -f "$HOME/.shortcuts/README" ]; then
    # a-shell uses .profile
    conf_file="$HOME/.profile"
  else
    case "$shell_name" in
      zsh)  conf_file="$HOME/.zshrc" ;;
      fish) conf_file="$HOME/.config/fish/config.fish" ;;
      *)    # bash/sh (Linux: .bashrc/.profile, macOS: prefer .bash_profile if present)
            if [ "$(uname)" = "Darwin" ] && [ -f "$HOME/.bash_profile" ]; then
              conf_file="$HOME/.bash_profile"
            elif [ -f "$HOME/.bashrc" ]; then
              conf_file="$HOME/.bashrc"
            else
              conf_file="$HOME/.profile"
            fi ;;
    esac
  fi
  
  mkdir -p "$(dirname "$conf_file")" 2>/dev/null || true

  if [ "$shell_name" = "fish" ]; then
    line="set -Ux OPENROUTER_API_KEY \"$key\""
  else
    line="export OPENROUTER_API_KEY=\"$key\""
  fi

  # Append only if not already present
  if ! grep -qxF "$line" "$conf_file" 2>/dev/null; then
    printf '\n%s\n' "$line" >> "$conf_file"
  fi
  log "API key persisted to $conf_file"
}

configure_api_key() {
  # If explicitly skipping and no key provided, exit early
  [ $ASK_API_KEY -eq 0 ] && [ -z "$API_KEY" ] && return

  # Check if we can interact with the user
  # If not in a terminal and /dev/tty is not available, skip interactive prompts
  if ! [ -t 0 ] && ! [ -r /dev/tty ]; then
    log "Non-interactive environment detected. Skipping API key configuration."
    log "To set API key, use: export OPENROUTER_API_KEY=\"your-key-here\""
    return
  fi

  # Check if API key is already set in environment
  if [ -n "$OPENROUTER_API_KEY" ] && [ -z "$API_KEY" ]; then
    log "OPENROUTER_API_KEY is already set in your environment."
    printf "Would you like to overwrite it? (y/N): "
    # Use /dev/tty for input when stdin is not a terminal (e.g., curl | sh)
    if [ -t 0 ]; then
      read resp
    else
      read resp </dev/tty
    fi
    case "$resp" in
      [Yy]*) ;;
      *) 
        log "Keeping existing API key."
        return 
        ;;
    esac
  fi

  if [ -z "$API_KEY" ]; then
    # If we reach here from the overwrite path, skip the initial prompt
    if [ -z "$OPENROUTER_API_KEY" ]; then
      printf "Would you like to set your OpenRouter API key now? (y/N): "
      # Use /dev/tty for input when stdin is not a terminal
      if [ -t 0 ]; then
        read resp
      else
        read resp </dev/tty
      fi
      case "$resp" in
        [Yy]*) ;;
        *) return ;;
      esac
    fi
    
    # POSIX sh doesn't support read -s, so we use stty
    printf "Enter API key (input hidden): "
    # Save current terminal settings
    old_tty_settings=$(stty -g 2>/dev/null || true)
    stty -echo 2>/dev/null || true
    # Use /dev/tty for input when stdin is not a terminal
    if [ -t 0 ]; then
      read API_KEY
    else
      read API_KEY </dev/tty
    fi
    # Restore terminal settings
    [ -n "$old_tty_settings" ] && stty "$old_tty_settings" 2>/dev/null || stty echo 2>/dev/null || true
    echo
    
    [ -z "$API_KEY" ] && { log "No key entered – skipping."; return; }
  fi

  OPENROUTER_API_KEY="$API_KEY"
  export OPENROUTER_API_KEY
  log "API key set for this session."
  persist_api_key "$API_KEY"
}

main() {
  # Check if running in a-shell
  if [ -n "$ASHELL" ] || [ -f "$HOME/.shortcuts/README" ]; then
    log "a-shell detected - using iOS-compatible paths"
  fi
  
  check_deps
  dir=$(pick_install_dir)
  install_aifixer "$dir"
  ensure_path "$dir"
  configure_api_key
  log "🎉  Installation complete.  Run:  aifixer --help"
}

main "$@"