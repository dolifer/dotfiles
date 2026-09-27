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

[[ "$(uname)" == "Darwin" ]] || error "These dotfiles are macOS-only."

# Ensure git is available (via Xcode Command Line Tools)
if ! xcode-select -p &>/dev/null; then
  info "Installing Xcode Command Line Tools (for git)..."
  xcode-select --install 2>/dev/null
  echo "Re-run this script after Xcode CLT finishes installing."
  exit 0
fi

# Clone or update
if [[ -d "$DOTFILES_DIR/.git" ]]; then
  info "Dotfiles already cloned — pulling latest..."
  git -C "$DOTFILES_DIR" pull --ff-only || error "Could not fast-forward $DOTFILES_DIR (local changes?). Resolve it, then re-run."
else
  info "Cloning dotfiles..."
  git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
fi

# Run installer
info "Running install script..."
bash "$DOTFILES_DIR/install.sh"

echo
success "Bootstrap complete! Open a new terminal."
