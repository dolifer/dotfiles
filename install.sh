#!/usr/bin/env bash

set -e
trap on_error SIGTERM

e='\033'
RESET="${e}[0m"
BOLD="${e}[1m"
CYAN="${e}[0;96m"
RED="${e}[0;91m"
YELLOW="${e}[0;93m"
GREEN="${e}[0;92m"

_exists() {
  command -v "$1" > /dev/null 2>&1
}

# Success reporter
info() {
  echo -e "${CYAN}${*}${RESET}"
}

# Error reporter
error() {
  echo -e "${RED}${*}${RESET}"
}

# Success reporter
success() {
  echo -e "${GREEN}${*}${RESET}"
}

# End section
finish() {
  success "Done!"
  echo
  sleep 1
}

# Get Script Source Directory
# https://stackoverflow.com/questions/59895/getting-the-source-directory-of-a-bash-script-from-within

pushd . > /dev/null
SCRIPT_PATH="${BASH_SOURCE[0]}"
if ([ -h "${SCRIPT_PATH}" ]); then
  while([ -h "${SCRIPT_PATH}" ]); do cd `dirname "$SCRIPT_PATH"`;
  SCRIPT_PATH=`readlink "${SCRIPT_PATH}"`; done
fi
cd `dirname ${SCRIPT_PATH}` > /dev/null
SCRIPT_PATH=`pwd`;
popd  > /dev/null

echo -e "Will import config files from \033[0;32m$SCRIPT_PATH\033[0m folder"

install_homebrew() {
  info "Trying to detect installed Homebrew..."

  if ! _exists brew; then
    echo "Seems like you don't have Homebrew installed!"
    read -p "Do you agree to proceed with Homebrew installation? [y/N] " -n 1 answer
    echo
    if [ "${answer}" != "y" ]; then
      return
    fi

    info "Installing Homebrew..."
    bash -c "$(curl -fsSL ${HOMEBREW_INSTALLER_URL})"
    eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    success "You already have Homebrew installed. Skipping..."
  fi

  finish
}

install_software() {
  if [ "$(uname)" != "Darwin" ]; then
    return
  fi

  info "Installing software..."

  cd "$DOTFILES"

  # Homebrew Bundle
  if _exists brew; then
    brew bundle
  else
    error "Error: Brew is not available"
  fi

  # Homebrew Bundle
  if ! _exists zgen; then
      info "Installing zgen..."
      eval "$SCRIPT_PATH/scripts/zgen.sh"
  else
    error "Error: zgen is not available"
  fi

  cd -

  finish
}

# zsh
yes | cp -f "$SCRIPT_PATH/.zshrc" ~/.zshrc

yes | cp -fr "$SCRIPT_PATH/.zsh" ~/

# starship
mkdir -p ~/.config && touch ~/.config/starship.toml
yes | cp -f "$SCRIPT_PATH/.config/starship.toml" ~/.config/starship.toml

# Homebrew Bundle
main() {
    install_homebrew "$*"
    install_software "$*"
}

main "$*"
