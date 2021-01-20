#!/bin/zsh

# Bind ctrl-left / ctrl-right
bindkey "\e[1;5D" backward-word
bindkey "\e[1;5C" forward-word

# Bind shift-tab to backwards-menu
bindkey "\e[Z" reverse-menu-complete