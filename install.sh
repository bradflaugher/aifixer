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
  --api-key, -k KEY      Persist KEY as OPENROUTER_API_KEY non-interactively.
  --skip-api-key         Do not prompt to set an API key.
  --help                 Show this help and exit.
  
The script will try these locations in order:
  /usr/local/bin      (if writable)
  ~/.local/bin        (XDG standard)
  ~/bin               (traditional)
  ~/Documents/bin     (fallback for restricted systems)
  
Examples:
  # Install to default location
  ./install.sh
  
  # Install to custom location
  ./install.sh --prefix ~/my-tools
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
  
  # Try directories in order of preference, testing if we can actually create them
  for dir in "/usr/local/bin" "$HOME/.local/bin" "$HOME/bin" "$HOME/Documents/bin"; do
    if [ -d "$dir" ] && [ -w "$dir" ]; then
      # Directory exists and is writable
      echo "$dir"
      return
    elif [ ! -e "$dir" ]; then
      # Directory doesn't exist, try to create it
      if mkdir -p "$dir" 2>/dev/null; then
        echo "$dir"
        return
      fi
    fi
  done
  
  # If nothing worked, suggest using --prefix
  die "Cannot find a writable directory for installation. Please use --prefix to specify one."
}

install_aifixer() {
  target_dir=$1
  
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
  cp "$source_path" "$target_dir/$INSTALL_NAME" 2>/dev/null || \
    die "Cannot copy to $target_dir/$INSTALL_NAME - check permissions or use --prefix"
  
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
  
  printf '\n# Add to your shell profile for permanence:\nexport PATH="%s:$PATH"\n' "$dir"
}

persist_api_key() {
  key=$1
  shell_name=$(basename "${SHELL:-sh}")
  
  # Determine the best config file based on what exists and what shell we're using
  conf_file=""
  
  case "$shell_name" in
    zsh)  
      # zsh always uses .zshrc
      conf_file="$HOME/.zshrc" 
      ;;
    fish) 
      # fish has its own config location
      conf_file="$HOME/.config/fish/config.fish" 
      ;;
    *)    
      # For sh/bash/dash, use a smart detection approach
      # .profile is the most universal - works with sh and bash in login mode
      # Many restricted environments (like a-shell) only read .profile
      
      # First, check what files already exist
      if [ -f "$HOME/.profile" ]; then
        conf_file="$HOME/.profile"
      elif [ -f "$HOME/.bashrc" ] && [ -f "$HOME/.bash_profile" ]; then
        # If both exist, prefer .bashrc and ensure .bash_profile sources it
        conf_file="$HOME/.bashrc"
        # Make sure .bash_profile sources .bashrc
        if ! grep -q "source.*bashrc\|\..*bashrc" "$HOME/.bash_profile" 2>/dev/null; then
          printf '\n# Source .bashrc\n[ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"\n' >> "$HOME/.bash_profile"
        fi
      elif [ -f "$HOME/.bash_profile" ]; then
        conf_file="$HOME/.bash_profile"
      elif [ -f "$HOME/.bashrc" ]; then
        conf_file="$HOME/.bashrc"
      else
        # No existing files - create .profile as it's most universal
        conf_file="$HOME/.profile"
      fi
      ;;
  esac
  
  # Try to create config directory if needed
  conf_dir=$(dirname "$conf_file")
  [ -d "$conf_dir" ] || mkdir -p "$conf_dir" 2>/dev/null || true

  if [ "$shell_name" = "fish" ]; then
    line="set -Ux OPENROUTER_API_KEY \"$key\""
  else
    line="export OPENROUTER_API_KEY=\"$key\""
  fi

  # Append only if not already present
  if [ -w "$conf_file" ] || [ ! -e "$conf_file" ]; then
    if ! grep -qxF "$line" "$conf_file" 2>/dev/null; then
      printf '\n%s\n' "$line" >> "$conf_file" 2>/dev/null || {
        log "Warning: Could not persist API key to $conf_file"
        return
      }
    fi
    log "API key persisted to $conf_file"
    
    # Special note for Terminal.app users on macOS
    if [ "$(uname)" = "Darwin" ] && [ "$conf_file" = "$HOME/.bashrc" ]; then
      log "Note: Terminal.app loads .bash_profile by default. Make sure it sources .bashrc"
    fi
  else
    log "Warning: Cannot write to $conf_file - API key set for this session only"
  fi
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
  check_deps
  dir=$(pick_install_dir)
  log "Installing to: $dir"
  install_aifixer "$dir"
  ensure_path "$dir"
  configure_api_key
  log "🎉  Installation complete.  Run:  aifixer --help"
}

main "$@"