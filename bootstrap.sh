#!/usr/bin/env bash
#
# Bootstrap dotfiles on a fresh machine.
# Usage: curl -fsSL https://raw.githubusercontent.com/dolifer/dotfiles/main/bootstrap.sh | bash
#
set -euo pipefail

DOTFILES_REPO="https://github.com/dolifer/dotfiles.git"
DOTFILES_DIR="$HOME/.dotfiles"

e='\033'
info()    { echo -e "${e}[0;96m${*}${e}[0m"; }
success() { echo -e "${e}[0;92m${*}${e}[0m"; }
error()   { echo -e "${e}[0;91m${*}${e}[0m"; exit 1; }

# Ensure git is available (xcode-select on macOS, or fail)
if ! command -v git &>/dev/null; then
  if [[ "$(uname)" == "Darwin" ]]; then
    info "Installing Xcode Command Line Tools (for git)..."
    xcode-select --install 2>/dev/null
    echo "Re-run this script after Xcode CLT finishes installing."
    exit 0
  else
    error "git is required. Install it first: sudo apt install git"
  fi
fi

# Clone or update
if [[ -d "$DOTFILES_DIR/.git" ]]; then
  info "Dotfiles already cloned — pulling latest..."
  git -C "$DOTFILES_DIR" fetch origin
  git -C "$DOTFILES_DIR" reset --hard origin/main
else
  info "Cloning dotfiles..."
  git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
fi

# Run installer
info "Running install script..."
bash "$DOTFILES_DIR/install.sh"

echo
success "Bootstrap complete! Open a new terminal."
