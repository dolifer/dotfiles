#!/usr/bin/env bash

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

# zsh
yes | cp -f "$SCRIPT_PATH/.zshrc" ~/.zshrc

# starship
mkdir -p  ~/.config
yes | cp -f "$SCRIPT_PATH/.config/starship.toml" ~/.config/starship.toml

echo -e "Done."