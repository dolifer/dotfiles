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

info() {
  echo -e "${CYAN}${*}${RESET}"
}

error() {
  echo -e "${RED}${*}${RESET}"
}

success() {
  echo -e "${GREEN}${*}${RESET}"
}

finish() {
  success "Done!"
  echo
  sleep 1
}

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
    bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
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

  cd "$SCRIPT_PATH"

  if _exists brew; then
    brew bundle
  else
    error "Error: Brew is not available"
  fi

  info "Installing zinit..."
  bash "$SCRIPT_PATH/scripts/zinit.sh"

  cd -

  finish
}

# zsh
yes | cp -f "$SCRIPT_PATH/.zshrc" ~/.zshrc

# aliases
mkdir -p ~/.zsh
yes | cp -f "$SCRIPT_PATH/.zsh/aliases.zsh" ~/.zsh/aliases.zsh

# starship
mkdir -p ~/.config
yes | cp -f "$SCRIPT_PATH/.config/starship.toml" ~/.config/starship.toml

main() {
    install_homebrew "$*"
    install_software "$*"
}

main "$*"
