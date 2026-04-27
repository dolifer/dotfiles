# --- Locale ---
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LANGUAGE=en_US.UTF-8

# --- PATH ---
export PATH="$HOME/.local/bin:$PATH"

# --- LSCOLORS ---
export LSCOLORS="Gxfxcxdxbxegedabagacab"
export LS_COLORS='no=00:fi=00:di=01;34:ln=00;36:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=41;33;01:ex=00;32:ow=0;41:*.cmd=00;32:*.exe=01;32:*.com=01;32:*.bat=01;32:*.btm=01;32:*.dll=01;32:*.tar=00;31:*.tbz=00;31:*.tgz=00;31:*.rpm=00;31:*.deb=00;31:*.arj=00;31:*.taz=00;31:*.lzh=00;31:*.lzma=00;31:*.zip=00;31:*.zoo=00;31:*.z=00;31:*.Z=00;31:*.gz=00;31:*.bz2=00;31:*.tb2=00;31:*.tz2=00;31:*.tbz2=00;31:*.avi=01;35:*.bmp=01;35:*.fli=01;35:*.gif=01;35:*.jpg=01;35:*.jpeg=01;35:*.mng=01;35:*.mov=01;35:*.mpg=01;35:*.pcx=01;35:*.pbm=01;35:*.pgm=01;35:*.png=01;35:*.ppm=01;35:*.tga=01;35:*.tif=01;35:*.xbm=01;35:*.xpm=01;35:*.dl=01;35:*.gl=01;35:*.wmv=01;35:*.aiff=00;32:*.au=00;32:*.mid=00;32:*.mp3=00;32:*.ogg=00;32:*.voc=00;32:*.wav=00;32:*.patch=00;34:*.o=00;32:*.so=01;35:*.ko=01;31:*.la=00;33'

# --- Zinit ---
ZINIT_HOME="${HOME}/.local/share/zinit/zinit.git"
source "${ZINIT_HOME}/zinit.zsh"

# --- OMZ libs (minimal set, no framework load) ---
zinit for \
  OMZL::git.zsh \
  OMZL::completion.zsh \
  OMZL::key-bindings.zsh \
  OMZL::history.zsh

# --- OMZ plugins (synchronous: git is needed immediately for prompt) ---
zinit snippet OMZP::git

# --- OMZ plugins (turbo: deferred after prompt) ---
zinit wait lucid for \
  zsh-users/zsh-history-substring-search \
  OMZP::direnv \
  OMZP::docker \
  OMZP::docker-compose

# --- ssh-agent: Linux only (macOS uses built-in Keychain via ~/.ssh/config) ---
if [[ "$OSTYPE" == linux* ]]; then
  zinit snippet OMZP::ssh-agent
fi

# --- Custom plugins (turbo) ---
zinit wait lucid blockf for \
  zsh-users/zsh-completions

zinit wait lucid for \
  Aloxaf/fzf-tab

zinit wait lucid for \
  hlissner/zsh-autopair \
  zsh-users/zsh-autosuggestions \
  zsh-users/zsh-syntax-highlighting

# --- Completions (single compinit, cached) ---
autoload -Uz compinit
if [[ -n ${ZDOTDIR:-$HOME}/.zcompdump(#qN.mh+24) ]]; then
  compinit
else
  compinit -C
fi
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

# --- Cached eval helper ---
_cached_eval() {
  local name=$1; shift
  local cache="${HOME}/.cache/zsh-init/${name}.zsh"
  if [[ ! -f "$cache" || -n "$cache"(#qN.mh+24) ]]; then
    mkdir -p "${cache:h}"
    eval "$@" > "$cache" 2>/dev/null
  fi
  source "$cache"
}

# --- Tool inits (cached) ---
_cached_eval starship  'starship init zsh --print-full-init'
_cached_eval zoxide   'zoxide init zsh'

# --- fzf keybindings + completion ---
[[ -f /opt/homebrew/opt/fzf/shell/key-bindings.zsh ]] && source /opt/homebrew/opt/fzf/shell/key-bindings.zsh
[[ -f /opt/homebrew/opt/fzf/shell/completion.zsh ]]    && source /opt/homebrew/opt/fzf/shell/completion.zsh

# --- Aliases & functions ---
source ~/.zsh/aliases.zsh
