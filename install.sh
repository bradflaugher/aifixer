#!/usr/bin/env bash
# ------------------------------------------------------------------
#  AIFixer install script
#  Installs the `aifixer` command and (optionally) sets OPENROUTER_API_KEY
# ------------------------------------------------------------------
set -euo pipefail

# ------------------------------ constants -------------------------
REPO_RAW_URL="https://raw.githubusercontent.com/bradflaugher/aifixer/main"
AIFIXER_SCRIPT="aifixer.sh"
INSTALL_NAME="aifixer"

# ------------------------------ logging helpers ------------------
log() { printf '%b\n' "👉  $*"; }
die() { printf '%b\n' "❌  $*" >&2; exit 1; }

# ------------------------------ cli flags -------------------------
PREFIX="${PREFIX:-}"
SKIP_DEPS=0
ASK_API_KEY=1
API_KEY=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix|-p) PREFIX="$2"; shift 2 ;;
    --skip-deps) SKIP_DEPS=1; shift   ;;
    --api-key|-k) API_KEY="$2"; ASK_API_KEY=0; shift 2 ;;
    --skip-api-key) ASK_API_KEY=0; shift ;;
    -h|--help)
cat <<EOF
Usage: ./install.sh [options]

  --prefix, -p DIR       Install aifixer into DIR (default: autodetect).
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
    command_exists "$pm" && { echo "$pm"; return; }
  done
  echo ""   # none detected
}

install_pkgs() {
  local pm=$1; shift
  local pkgs=("$@")
  [[ -z "$pm" || ${#pkgs[@]} -eq 0 ]] && return

  log "Installing missing tools: ${pkgs[*]} (via $pm)"
  case "$pm" in
    apt-get) sudo apt-get update -y && sudo apt-get install -y "${pkgs[@]}" ;;
    dnf)     sudo dnf install -y "${pkgs[@]}" ;;
    yum)     sudo yum install -y "${pkgs[@]}" ;;
    pacman)  sudo pacman -Sy --noconfirm "${pkgs[@]}" ;;
    zypper)  sudo zypper install -y "${pkgs[@]}" ;;
    apk)     sudo apk add --no-cache "${pkgs[@]}" ;;
    brew)    brew install "${pkgs[@]}" ;;
    *)       die "Package-manager '$pm' unsupported for auto-install." ;;
  esac
}

ensure_deps() {
  local required=(bash curl awk grep sed)
  local missing=()
  for bin in "${required[@]}"; do
    command_exists "$bin" || missing+=("$bin")
  done

  # BusyBox/mawk detection – pulls in gawk if awk lacks common funcs
  if command_exists awk && ! awk 'BEGIN{exit ARGC<0}' 2>/dev/null; then
    missing+=("gawk")
  fi

  [[ ${#missing[@]} -eq 0 ]] && { log "All dependencies present. ✅"; return; }

  [[ $SKIP_DEPS -eq 1 ]] && die "Missing dependencies: ${missing[*]}"

  local pm; pm=$(detect_pkg_manager)
  [[ -z "$pm" ]] && die "No supported package-manager; install: ${missing[*]}"

  install_pkgs "$pm" "${missing[@]}"
}

pick_install_dir() {
  if [[ -n "$PREFIX" ]]; then
    echo "$PREFIX"; return
  fi
  local system_dir="/usr/local/bin"
  [[ -w $system_dir ]] && echo "$system_dir" || echo "$HOME/.local/bin"
}

install_aifixer() {
  local target_dir=$1
  mkdir -p "$target_dir"

  local source_path
  if [[ -f "$(dirname "$0")/$AIFIXER_SCRIPT" ]]; then
    source_path="$(dirname "$0")/$AIFIXER_SCRIPT"
  else
    source_path="$target_dir/$AIFIXER_SCRIPT"
    log "Fetching latest $AIFIXER_SCRIPT from GitHub…"
    curl -fsSL "$REPO_RAW_URL/$AIFIXER_SCRIPT" -o "$source_path" \
      || die "Download failed."
  fi

  install -m 0755 "$source_path" "$target_dir/$INSTALL_NAME"
  log "Installed $INSTALL_NAME → $target_dir/$INSTALL_NAME"
}

ensure_path() {
  local dir=$1
  [[ ":$PATH:" == *":$dir:"* ]] && return

  log "ℹ️  '$dir' not on PATH – adding for this session."
  export PATH="$dir:$PATH"
  printf '\n# Add to your shell profile for permanence:\nexport PATH="%s:$PATH"\n' "$dir"
}

persist_api_key() {
  local key=$1
  local shell_name conf_file line

  shell_name=$(basename "${SHELL:-bash}")
  case "$shell_name" in
    zsh)  conf_file="$HOME/.zshrc" ;;
    fish) conf_file="$HOME/.config/fish/config.fish" ;;
    *)    # bash (Linux: .bashrc, macOS: prefer .bash_profile if present)
          if [[ "$OSTYPE" == "darwin"* && -f "$HOME/.bash_profile" ]]; then
            conf_file="$HOME/.bash_profile"
          else
            conf_file="$HOME/.bashrc"
          fi ;;
  esac
  mkdir -p "$(dirname "$conf_file")"

  if [[ "$shell_name" == "fish" ]]; then
    line="set -Ux OPENROUTER_API_KEY \"$key\""
  else
    line="export OPENROUTER_API_KEY=\"$key\""
  fi

  # Append only if not already present
  grep -qxF "$line" "$conf_file" 2>/dev/null || echo "$line" >> "$conf_file"
  log "API key persisted to $conf_file"
}

configure_api_key() {
  # If skipping, or already set & not forced, exit early
  [[ $ASK_API_KEY -eq 0 && -z "$API_KEY" ]] && return

  if [[ -z "$API_KEY" ]]; then
    read -r -p "Would you like to set your OpenRouter API key now? (y/N): " resp
    [[ "$resp" =~ ^[Yy] ]] || return
    read -r -s -p "Enter API key (input hidden): " API_KEY
    echo
    [[ -z "$API_KEY" ]] && { log "No key entered – skipping."; return; }
  fi

  export OPENROUTER_API_KEY="$API_KEY"
  log "API key set for this session."
  persist_api_key "$API_KEY"
}

main() {
  ensure_deps
  local dir; dir=$(pick_install_dir)
  install_aifixer "$dir"
  ensure_path "$dir"
  configure_api_key
  log "🎉  Installation complete.  Run:  aifixer --help"
}

main "$@"