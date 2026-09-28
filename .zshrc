# --- Locale ---
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LANGUAGE=en_US.UTF-8

# Don't print '%' for partial lines (e.g. curl output without trailing newline)
unsetopt PROMPT_SP

# --- Cached eval helper ---
# Caches the output of an init command for 24h. Skipped if the command isn't installed.
_cached_eval() {
  local name=$1; shift
  local cmd=${1%% *}
  [[ -x $cmd ]] || (( $+commands[$cmd] )) || return
  local cache="${HOME}/.cache/zsh-init/${name}.zsh"
  if [[ ! -s "$cache" || -n "$cache"(#qN.mh+24) ]]; then
    mkdir -p "${cache:h}"
    eval "$@" > "$cache" 2>/dev/null
  fi
  source "$cache"
}

# --- Homebrew (Apple Silicon or Intel) ---
if [[ -x /opt/homebrew/bin/brew ]]; then
  _cached_eval brew '/opt/homebrew/bin/brew shellenv'
elif [[ -x /usr/local/bin/brew ]]; then
  _cached_eval brew '/usr/local/bin/brew shellenv'
fi

# --- PATH ---
export PATH="$HOME/.local/bin:$PATH"

# --- .NET (dotnet-install.sh in ~/.dotnet, or the official pkg/brew cask) ---
for _dotnet_root in "$HOME/.dotnet" /usr/local/share/dotnet; do
  if [[ -x $_dotnet_root/dotnet ]]; then
    export DOTNET_ROOT=$_dotnet_root
    path=($DOTNET_ROOT $path)
    break
  fi
done
unset _dotnet_root
path+=("$HOME/.dotnet/tools")

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

# --- Custom plugins (turbo) ---
zinit wait lucid blockf for \
  zsh-users/zsh-completions

zinit wait lucid for \
  Aloxaf/fzf-tab

# Autosuggestions (turbo — sync load causes doubled keystrokes in sudo/SSH shells)
zinit wait lucid for \
  zsh-users/zsh-autosuggestions

zinit wait lucid for \
  hlissner/zsh-autopair \
  zsh-users/zsh-syntax-highlighting

# --- Completions (single compinit, cached) ---
autoload -Uz compinit
if [[ -n ${ZDOTDIR:-$HOME}/.zcompdump(#qN.mh+24) ]]; then
  compinit -u
else
  compinit -u -C
fi
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

# --- Tool inits (cached) ---
_cached_eval starship  'starship init zsh --print-full-init'
# zoxide: `cd` ranks directories by frecency, `cdi` (or `cd foo<Space><Tab>`) picks one with fzf.
# Agents (Claude Code, Cursor, Codex) snapshot shell functions into shells without the
# chpwd hook, so they get the plain `z`/`zi` commands and keep the builtin cd.
export _ZO_EXCLUDE_DIRS="$HOME:/tmp/*:/private/tmp/*:/private/var/*:/var/folders/*:/Volumes/*"
(( $+commands[eza] )) && export _ZO_FZF_OPTS="--exact --no-sort --cycle --keep-right --height=45% \
--layout=reverse --info=inline --border=sharp --select-1 --exit-0 \
--preview='eza -1 --color=always --icons {2..}' --preview-window=down,30%,sharp"
if [[ -o interactive && -z "$CLAUDECODE$CURSOR_AGENT$CODEX_SANDBOX" ]]; then
  _cached_eval zoxide-cd 'zoxide init zsh --cmd cd'
  alias z='cd' zi='cdi'
else
  _cached_eval zoxide 'zoxide init zsh'
fi

# --- fzf keybindings + completion (Ctrl-T files, Ctrl-R history, Alt-C dirs) ---
_cached_eval fzf 'fzf --zsh'
if (( $+commands[fd] )); then
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND='fd --type d --hidden --exclude .git'
fi
(( $+commands[bat] )) && export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:200 {}'"
(( $+commands[eza] )) && export FZF_ALT_C_OPTS="--preview 'eza -1 --color=always --icons {}'"

# --- atuin: history database (dir, exit code, duration, optional sync), searched with Ctrl-G.
# Ctrl-R and Up keep their fzf / substring-search behaviour, and `?` stays a plain `?`
# (no Atuin AI). Not loaded in agent shells, so their commands stay out of the history.
if [[ -o interactive && -z "$CLAUDECODE$CURSOR_AGENT$CODEX_SANDBOX" ]] && (( $+commands[atuin] )); then
  _cached_eval atuin 'atuin init zsh --disable-up-arrow --disable-ctrl-r --disable-ai'
  bindkey '^g' atuin-search
fi

# --- fzf-tab: group switching and previews ---
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*' menu no
zstyle ':fzf-tab:*' switch-group '<' '>'
zstyle ':fzf-tab:complete:(cd|z|__zoxide_z):*' fzf-preview \
  'eza -1 --color=always --icons $realpath 2>/dev/null'
zstyle ':fzf-tab:complete:(ls|eza|cat|bat|less|zed|vim|nvim|code|open|rm|cp|mv):*' fzf-preview \
  '[[ -d $realpath ]] && eza -1 --color=always --icons $realpath || bat --color=always --style=numbers --line-range=:200 $realpath 2>/dev/null'

# --- Profile settings (tracked: .zsh/home.zsh or .zsh/work.zsh, per ~/.config/dotfiles/profile) ---
[[ -f ~/.config/dotfiles/profile ]] && DOTFILES_PROFILE=${"$(<~/.config/dotfiles/profile)"//[[:space:]]/}
[[ -n $DOTFILES_PROFILE && -f ~/.zsh/$DOTFILES_PROFILE.zsh ]] && source ~/.zsh/$DOTFILES_PROFILE.zsh

# --- Machine-local overrides (untracked: secrets, tokens; wins over the profile file) ---
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

# --- Aliases & functions ---
source ~/.zsh/aliases.zsh
source ~/.zsh/dot.zsh

# --- Seed zoxide with pj projects (only paths it doesn't know yet, once per reindex) ---
_zoxide_seed_pj() {
  local index=${PJ_INDEX_FILE:-$HOME/.cache/pj-index.tsv}
  local stamp=$HOME/.cache/zsh-init/zoxide-pj.stamp
  (( $+commands[zoxide] )) && [[ -s $index && ( ! -e $stamp || $index -nt $stamp ) ]] || return 0
  local -a known new
  known=(${(f)"$(zoxide query --list 2>/dev/null)"})
  for dir in ${(f)"$(cut -f2 "$index")"}; do
    [[ -d $dir ]] && (( ! ${known[(Ie)$dir]} )) && new+=($dir)
  done
  (( $#new )) && zoxide add -- $new
  mkdir -p ${stamp:h} && touch $stamp
}
_zoxide_seed_pj
unfunction _zoxide_seed_pj
