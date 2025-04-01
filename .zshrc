ZDOTDIR=~/.zsh

# Locale
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LANGUAGE=en_US.UTF-8

# Load configurations
for rc in $ZDOTDIR/*.sh
do
    source $rc
done

unset rc

# Reset zgen on change
ZGEN_RESET_ON_CHANGE=(
  ${HOME}/.zshrc
  ${ZDOTDIR}/*.zsh
)

# Load zgen
source "${HOME}/.zgen/zgen.zsh"

# Load zgen init script
if ! zgen saved; then
    echo "Creating a zgen save"

    zgen oh-my-zsh

    # Oh-My-Zsh plugins
    zgen oh-my-zsh plugins/git
    zgen oh-my-zsh plugins/history-substring-search
    zgen oh-my-zsh plugins/sudo
    zgen oh-my-zsh plugins/command-not-found
    zgen oh-my-zsh plugins/extract
    zgen oh-my-zsh plugins/ssh-agent
    zgen oh-my-zsh plugins/gpg-agent
    zgen oh-my-zsh plugins/macos
    zgen oh-my-zsh plugins/vscode
    zgen oh-my-zsh plugins/common-aliases
    zgen oh-my-zsh plugins/direnv
    zgen oh-my-zsh plugins/docker
    zgen oh-my-zsh plugins/docker-compose

    # Custom plugins
    zgen load djui/alias-tips
    zgen load hlissner/zsh-autopair
    zgen load zsh-users/zsh-syntax-highlighting
    zgen load zsh-users/zsh-autosuggestions
    zgen load Aloxaf/fzf-tab

    # Files
    zgen load $ZDOTDIR

    # Completions
    zgen load zsh-users/zsh-completions src

    # Save all to init script
    zgen save
fi

# Fuzzy finder bindings
if [ -f "$HOME/.fzf.zsh" ]; then
  source "$HOME/.fzf.zsh"
fi

# Like cd but with z-zsh capabilities
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi
