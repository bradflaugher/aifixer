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
SKIP_DEPS=0
ASK_API_KEY=1
API_KEY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --prefix|-p) PREFIX="$2"; shift 2 ;;
    --skip-deps) SKIP_DEPS=1; shift   ;;
    --api-key|-k) API_KEY="$2"; ASK_API_KEY=0; shift 2 ;;
    --skip-api-key) ASK_API_KEY=0; shift ;;
    -h|--help)
cat <<EOF
Usage: ./install.sh [options]

  --prefix, -p DIR       Install aifixer into DIR/bin (default: autodetect).
  --skip-deps            Do not install missing dependencies; just warn.
  --api-key, -k KEY      Persist KEY as OPENROUTER_API_KEY non-interactively.
  --skip-api-key         Do not prompt to set an API key.
  --help                 Show this help and exit.
EOF
      exit 0 ;;
    *) die "Unknown flag: $1" ;;
  esac
done

# ------------------------------ utils -----------------------------
command_exists() { command -v "$1" >/dev/null 2>&1; }

detect_pkg_manager() {
  for pm in apt-get dnf yum pacman zypper apk brew; do
    if command_exists "$pm"; then
      echo "$pm"
      return
    fi
  done
  echo ""   # none detected
}

install_pkgs() {
  pm=$1; shift
  pkgs="$*"
  [ -z "$pm" ] || [ -z "$pkgs" ] && return

  log "Installing missing tools: $pkgs (via $pm)"
  case "$pm" in
    apt-get) sudo apt-get update -y && sudo apt-get install -y $pkgs ;;
    dnf)     sudo dnf install -y $pkgs ;;
    yum)     sudo yum install -y $pkgs ;;
    pacman)  sudo pacman -Sy --noconfirm $pkgs ;;
    zypper)  sudo zypper install -y $pkgs ;;
    apk)     sudo apk add --no-cache $pkgs ;;
    brew)    brew install $pkgs ;;
    *)       die "Package-manager '$pm' unsupported for auto-install." ;;
  esac
}

ensure_deps() {
  required="bash curl awk grep sed"
  missing=""
  for bin in $required; do
    if ! command_exists "$bin"; then
      missing="$missing $bin"
    fi
  done

  # BusyBox/mawk detection – pulls in gawk if awk lacks common funcs
  if command_exists awk && ! awk 'BEGIN{exit ARGC<0}' 2>/dev/null; then
    missing="$missing gawk"
  fi

  # Trim leading space
  missing=$(echo "$missing" | sed 's/^ //')

  [ -z "$missing" ] && { log "All dependencies present. ✅"; return; }

  [ $SKIP_DEPS -eq 1 ] && die "Missing dependencies: $missing"

  pm=$(detect_pkg_manager)
  [ -z "$pm" ] && die "No supported package-manager; install: $missing"

  install_pkgs "$pm" $missing
}

pick_install_dir() {
  if [ -n "$PREFIX" ]; then
    echo "$PREFIX/bin" # <--- MODIFIED: Always use /bin within PREFIX
    return
  fi
  system_dir="/usr/local/bin"
  if [ -w "$system_dir" ]; then
    echo "$system_dir"
  else
    echo "$HOME/.local/bin"
  fi
}

install_aifixer() {
  target_dir=$1
  mkdir -p "$target_dir"

  source_path=""
  script_dir=$(dirname "$0")
  if [ -f "$script_dir/$AIFIXER_SCRIPT" ]; then
    source_path="$script_dir/$AIFIXER_SCRIPT"
  else
    # If not local, download to a temp location first, then install
    temp_script=$(mktemp 2>/dev/null || mktemp -t 'aifixer_download')
    source_path="$temp_script"
    log "Fetching latest $AIFIXER_SCRIPT from GitHub…"
    curl -fsSL "$REPO_RAW_URL/$AIFIXER_SCRIPT" -o "$source_path" \
      || die "Download failed."
  fi

  install -m 0755 "$source_path" "$target_dir/$INSTALL_NAME"
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
  mkdir -p "$(dirname "$conf_file")"

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

  # Check if API key is already set in environment
  if [ -n "$OPENROUTER_API_KEY" ] && [ -z "$API_KEY" ]; then
    log "OPENROUTER_API_KEY is already set in your environment."
    printf "Would you like to overwrite it? (y/N): "
    read resp
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
      read resp
      case "$resp" in
        [Yy]*) ;;
        *) return ;;
      esac
    fi
    
    # POSIX sh doesn't support read -s, so we use stty
    printf "Enter API key (input hidden): "
    stty -echo 2>/dev/null || true
    read API_KEY
    stty echo 2>/dev/null || true
    echo
    
    [ -z "$API_KEY" ] && { log "No key entered – skipping."; return; }
  fi

  OPENROUTER_API_KEY="$API_KEY"
  export OPENROUTER_API_KEY
  log "API key set for this session."
  persist_api_key "$API_KEY"
}

main() {
  ensure_deps
  dir=$(pick_install_dir)
  install_aifixer "$dir"
  ensure_path "$dir"
  configure_api_key
  log "🎉  Installation complete.  Run:  aifixer --help"
}

main "$@"