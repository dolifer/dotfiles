#!/bin/zsh

setopt AUTO_LIST
setopt AUTO_MENU
setopt MENU_COMPLETE

zmodload -i zsh/complist

# Completion caching
zstyle ':completion::complete:*' use-cache on
zstyle ':completion::complete:*' cache-path .zcache
zstyle ':completion:*:cd:*' ignore-parents parent pwd

# Fallback to built in ls colors
zstyle ':completion:*' list-colors ''
zstyle ':completion:*' menu yes select

# kubernetes
source <(kubectl completion zsh)

mkdir -p ~/.oh-my-zsh/completions
chmod -R 755 ~/.oh-my-zsh/completions
ln -sf /opt/kubectx/completion/kubectx.zsh ~/.oh-my-zsh/completions/_kubectx.zsh
ln -sf /opt/kubectx/completion/kubens.zsh ~/.oh-my-zsh/completions/_kubens.zsh

fpath=(~/.oh-my-zsh/completions $fpath)

autoload -U compinit && compinit

# Bind ESC to exit menu
bindkey -M menuselect '\e' send-break