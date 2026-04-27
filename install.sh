#!/usr/bin/env bash
set -euo pipefail

e='\033'
RESET="${e}[0m"
BOLD="${e}[1m"
DIM="${e}[2m"
CYAN="${e}[0;96m"
RED="${e}[0;91m"
GREEN="${e}[0;92m"
YELLOW="${e}[0;93m"
BLUE="${e}[0;94m"
MAGENTA="${e}[0;95m"
WHITE="${e}[1;97m"

_exists() { command -v "$1" > /dev/null 2>&1; }

# --- Logging ---
ok()      { echo -e "  ${GREEN}✅${RESET} ${*}"; }
skip()    { echo -e "  ${DIM}⏭️  ${*}${RESET}"; }
warn()    { echo -e "  ${YELLOW}⚠️ ${RESET} ${*}"; }
fail()    { echo -e "  ${RED}❌${RESET} ${*}"; }
info()    { echo -e "  ${CYAN}💡${RESET} ${*}"; }
indent()  { sed 's/^/  /' ; }

# --- Progress ---
TOTAL_STEPS=6
CURRENT_STEP=0
RESULTS=()
START_TIME=$(date +%s)

step() {
  CURRENT_STEP=$((CURRENT_STEP + 1))
  echo
  echo -e "  ${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "  ${WHITE}[$CURRENT_STEP/$TOTAL_STEPS]${RESET} ${BOLD}${*}${RESET}"
  echo -e "  ${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

track() {
  local emoji="$1" label="$2"
  RESULTS+=("${emoji} ${label}")
}

# Resolve script directory
DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Header ---
print_header() {
  echo
  echo -e "${MAGENTA}${BOLD}"
  cat << 'EOF'
    ██████╗  ██████╗ ████████╗███████╗██╗██╗     ███████╗███████╗
    ██╔══██╗██╔═══██╗╚══██╔══╝██╔════╝██║██║     ██╔════╝██╔════╝
    ██║  ██║██║   ██║   ██║   █████╗  ██║██║     █████╗  ███████╗
    ██║  ██║██║   ██║   ██║   ██╔══╝  ██║██║     ██╔══╝  ╚════██║
    ██████╔╝╚██████╔╝   ██║   ██║     ██║███████╗███████╗███████║
    ╚═════╝  ╚═════╝    ╚═╝   ╚═╝     ╚═╝╚══════╝╚══════╝╚══════╝
EOF
  echo -e "${RESET}"
  echo -e "    ${WHITE}${BOLD}Denis Olifer${RESET}  ${DIM}— personal development environment${RESET}"
  echo -e "    ${DIM}📂 ${DOTFILES}${RESET}"
  echo
}

# --- Sync a config file: backup existing, copy new ---
sync_file() {
  local src="$1" dest="$2"
  local name="$(basename "$dest")"
  mkdir -p "$(dirname "$dest")"

  if [[ -f "$dest" ]]; then
    if diff -q "$src" "$dest" &>/dev/null; then
      ok "${name} ${DIM}(unchanged)${RESET}"
      return
    fi
    cp "$dest" "${dest}.bak"
    warn "${name} ${DIM}(updated, backup → .bak)${RESET}"
  else
    ok "${name} ${DIM}(new)${RESET}"
  fi

  cp -f "$src" "$dest"
}

# --- Homebrew ---
install_homebrew() {
  step "🍺 Homebrew"

  if _exists brew; then
    ok "Already installed"
    track "🍺" "Homebrew — already installed"
    return
  fi

  read -p "  Install Homebrew? [y/N] " -n 1 answer
  echo
  if [[ "$answer" != "y" ]]; then
    skip "Skipped"
    track "⏭️" "Homebrew — skipped"
    return
  fi

  bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  if [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -f /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
  ok "Installed"
  track "🍺" "Homebrew — installed"
}

# --- Brew bundle ---
install_software() {
  step "📦 Packages (Brewfile)"

  if [[ "$(uname)" != "Darwin" ]]; then
    skip "Not macOS"
    track "⏭️" "Packages — not macOS"
    return
  fi

  if _exists brew; then
    brew bundle --file="$DOTFILES/Brewfile" --no-lock 2>&1 | grep -E '^(Installing|Upgrading|Using)' | indent || true
    ok "Brew bundle complete"
    track "📦" "Packages — synced"
  else
    fail "Homebrew not available"
    track "❌" "Packages — Homebrew missing"
  fi
}

# --- Zinit ---
install_zinit() {
  step "⚡ Zinit"
  bash "$DOTFILES/scripts/zinit.sh" 2>&1 | indent
  ok "Ready"
  track "⚡" "Zinit — ready"
}

# --- SSH config (merge, don't overwrite) ---
sync_ssh_config() {
  local src="$DOTFILES/.ssh/config"
  local dest="$HOME/.ssh/config"
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"

  if [[ ! -f "$dest" ]]; then
    cp "$src" "$dest"
    chmod 600 "$dest"
    ok "ssh/config ${DIM}(new)${RESET}"
    return
  fi

  # Detect key type on this machine
  local key_file="id_ed25519"
  if [[ ! -f "$HOME/.ssh/id_ed25519" ]] && [[ -f "$HOME/.ssh/id_rsa" ]]; then
    key_file="id_rsa"
  fi

  local changed=false

  # Ensure Host * block has our keys
  for directive in "AddKeysToAgent yes" "UseKeychain yes" "IdentitiesOnly yes"; do
    if ! grep -qF "$directive" "$dest"; then
      # Append to Host * block or create one
      if grep -q "^Host \*" "$dest"; then
        sed -i '' "/^Host \*/a\\
  ${directive}
" "$dest"
      else
        printf '\nHost *\n  %s\n' "$directive" >> "$dest"
      fi
      changed=true
    fi
  done

  # Ensure Host github.com block exists
  if ! grep -q "^Host github.com" "$dest"; then
    cat >> "$dest" <<EOF

Host github.com
  HostName github.com
  IdentityFile ~/.ssh/${key_file}
EOF
    changed=true
  fi

  chmod 600 "$dest"
  if [[ "$changed" == true ]]; then
    warn "ssh/config ${DIM}(updated — merged missing directives)${RESET}"
  else
    ok "ssh/config ${DIM}(unchanged)${RESET}"
  fi
}

# --- Config files ---
sync_configs() {
  step "🔗 Config files"

  sync_ssh_config
  sync_file "$DOTFILES/.zshrc"                "$HOME/.zshrc"
  sync_file "$DOTFILES/.zsh/aliases.zsh"      "$HOME/.zsh/aliases.zsh"
  sync_file "$DOTFILES/.gitconfig"            "$HOME/.gitconfig"
  sync_file "$DOTFILES/.curlrc"               "$HOME/.curlrc"
  sync_file "$DOTFILES/.config/starship.toml" "$HOME/.config/starship.toml"
  sync_file "$DOTFILES/.config/zed/settings.json" "$HOME/.config/zed/settings.json"

  # ghostty (macOS uses ~/Library path, Linux uses ~/.config)
  if [[ "$(uname)" == "Darwin" ]]; then
    local ghostty_dir="$HOME/Library/Application Support/com.mitchellh.ghostty"
  else
    local ghostty_dir="$HOME/.config/ghostty"
  fi
  sync_file "$DOTFILES/.config/ghostty/config" "$ghostty_dir/config"

  # GPG agent (pinentry-mac)
  sync_file "$DOTFILES/.gnupg/gpg-agent.conf" "$HOME/.gnupg/gpg-agent.conf"
  chmod 700 "$HOME/.gnupg" 2>/dev/null
  gpgconf --kill gpg-agent 2>/dev/null || true

  # k8s prompt helper
  mkdir -p "$HOME/.local/bin"
  cp -f "$DOTFILES/scripts/k8s-prompt.sh" "$HOME/.local/bin/k8s-prompt"
  chmod +x "$HOME/.local/bin/k8s-prompt"
  ok "k8s-prompt ${DIM}(installed)${RESET}"

  # flush caches
  rm -rf "$HOME/.cache/zsh-init" "$HOME/.zcompdump"*
  ok "Caches flushed"

  track "🔗" "Configs — synced"
}

# --- macOS defaults ---
setup_macos() {
  if [[ "$(uname)" != "Darwin" ]]; then
    track "⏭️" "macOS — not macOS"
    return
  fi

  step "🍎 macOS defaults"
  bash "$DOTFILES/scripts/macos.sh" 2>/dev/null | indent
  ok "Applied"
  track "🍎" "macOS defaults — applied"
}

# --- Git local identity ---
setup_gitlocal() {
  step "🔑 Git identity"

  if [[ -f "$HOME/.gitlocal" ]]; then
    local name=$(git config --file "$HOME/.gitlocal" user.name 2>/dev/null || echo "")
    local email=$(git config --file "$HOME/.gitlocal" user.email 2>/dev/null || echo "")
    ok "${name} <${email}>"

    # Auto-detect GPG signing key if not set
    local current_key=$(git config --file "$HOME/.gitlocal" user.signingkey 2>/dev/null || echo "")
    if [[ -z "$current_key" ]] && _exists gpg; then
      local gpg_key=$(gpg --list-secret-keys --keyid-format long 2>/dev/null | awk '/^sec/{print $2}' | cut -d/ -f2 | head -1)
      if [[ -n "$gpg_key" ]]; then
        git config --file "$HOME/.gitlocal" user.signingkey "$gpg_key"
        ok "GPG signing key → ${gpg_key}"
      fi
    elif [[ -n "$current_key" ]]; then
      ok "GPG signing key → ${current_key}"
    fi

    track "🔑" "Git identity — ${name}"
    return
  fi

  echo -e "  ${YELLOW}No ~/.gitlocal found — let's set up your git identity${RESET}"
  read -p "  Name (e.g. Denis Olifer): " git_name
  read -p "  Email: " git_email

  cat > "$HOME/.gitlocal" <<EOF
[user]
	name = $git_name
	email = $git_email
EOF

  ok "Created ~/.gitlocal"
  track "🔑" "Git identity — created"
}

# --- Summary ---
print_summary() {
  local end_time=$(date +%s)
  local elapsed=$((end_time - START_TIME))

  echo
  echo -e "  ${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "  ${GREEN}${BOLD}🎉 All done!${RESET}  ${DIM}(${elapsed}s)${RESET}"
  echo -e "  ${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo
  for r in "${RESULTS[@]}"; do
    echo -e "    ${r}"
  done
  echo
  echo -e "  ${CYAN}${BOLD}→ Open a new terminal to apply changes${RESET}"
  echo
}

# --- Main ---
main() {
  print_header

  install_homebrew
  install_software
  install_zinit
  sync_configs
  setup_macos
  setup_gitlocal

  print_summary
}

main
