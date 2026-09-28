#!/bin/zsh
# --- dot: manage the dotfiles repo ---
# Configs in $HOME are symlinks into this repo, so editing either side edits the repo.
DOTFILES="${DOTFILES:-${HOME}/.dotfiles}"

dot() {
  local cmd="${1:-help}"
  (( $# )) && shift

  case "$cmd" in
    cd)
      builtin cd "$DOTFILES"
      ;;
    edit|e)
      local editor="${VISUAL:-${EDITOR:-}}"
      [[ -z "$editor" ]] && { (( $+commands[zed] )) && editor=zed || editor=vi; }
      ${=editor} "$DOTFILES${1:+/$1}"
      ;;
    status|st)
      git -C "$DOTFILES" status -sb
      ;;
    diff)
      git -C "$DOTFILES" diff "$@"
      ;;
    update|up)
      if [[ -n "$(git -C "$DOTFILES" status --porcelain)" ]]; then
        echo "⚠️  $DOTFILES has uncommitted changes:" >&2
        git -C "$DOTFILES" status -s >&2
        echo "Commit or stash them first (dot cd), then run dot update again." >&2
        return 1
      fi
      git -C "$DOTFILES" pull --ff-only || return 1
      "$DOTFILES/install.sh" && exec zsh
      ;;
    reload|rl)
      exec zsh
      ;;
    install)
      "$DOTFILES/install.sh"
      ;;
    doctor)
      _dot_doctor
      ;;
    help|-h|--help)
      cat <<EOF
Usage: dot <command>

  cd              cd into $DOTFILES
  edit [path]     open the repo (or a file in it) in \$EDITOR, else Zed
  status          git status of the repo
  diff [args]     git diff of the repo
  update          pull latest (refuses if the repo has local changes), re-run install, restart zsh
  reload          restart zsh to pick up config changes
  install         re-run install.sh
  doctor          check that tools, links and git signing are set up
EOF
      ;;
    *)
      echo "dot: unknown command '$cmd' (try: dot help)" >&2
      return 1
      ;;
  esac
}

_dot_doctor() {
  local problems=0
  _dot_ok()   { echo "  ✅ $*"; }
  _dot_bad()  { echo "  ❌ $*"; (( problems++ )); }
  _dot_info() { echo "  💡 $*"; }

  local profile=""
  [[ -f "${HOME}/.config/dotfiles/profile" ]] && profile=$(<"${HOME}/.config/dotfiles/profile")
  profile=${profile//[[:space:]]/}
  echo "Tools (${profile:-no} profile)"
  [[ -z "$profile" ]] && _dot_bad "no profile set (dot install asks home or work)"
  local t
  for t in brew git starship zoxide fzf fd bat eza rg delta gpg pinentry-mac \
           atuin tldr btop dust xh; do
    (( $+commands[$t] )) && _dot_ok "$t" || _dot_bad "$t not found (brew bundle --file=$DOTFILES/Brewfile)"
  done
  if [[ "$profile" == "home" ]]; then
    for t in gh; do
      (( $+commands[$t] )) && _dot_ok "$t" || _dot_bad "$t not found (brew bundle --file=$DOTFILES/Brewfile.home)"
    done
  elif [[ "$profile" == "work" ]]; then
    for t in glab; do
      (( $+commands[$t] )) && _dot_ok "$t" || _dot_bad "$t not found (brew bundle --file=$DOTFILES/Brewfile.work)"
    done
    [[ -d /Applications/MeetingBar.app ]] && _dot_ok "MeetingBar" \
      || _dot_bad "MeetingBar not found (brew bundle --file=$DOTFILES/Brewfile.work)"
  fi
  [[ -d "${HOME}/.local/share/zinit/zinit.git" ]] && _dot_ok "zinit" || _dot_bad "zinit missing (dot install)"

  echo "Links"
  local link target
  for link in .zshrc .zsh/aliases.zsh .zsh/dot.zsh .zsh/home.zsh .zsh/work.zsh .gitconfig .config/starship.toml \
              .config/zed/settings.json .config/atuin/config.toml .gnupg/gpg-agent.conf; do
    target="${HOME}/${link}"
    if [[ -L "$target" && "$(readlink "$target")" == "$DOTFILES/"* ]]; then
      _dot_ok "~/$link"
    else
      _dot_bad "~/$link is not linked to the repo (dot install)"
    fi
  done

  echo "Git"
  local name=$(git config --file "${HOME}/.gitlocal" user.name 2>/dev/null)
  [[ -n "$name" ]] && _dot_ok "identity: $name <$(git config --file "${HOME}/.gitlocal" user.email)>" \
                   || _dot_bad "~/.gitlocal has no identity (dot install)"
  local signing
  if signing=$(bash "$DOTFILES/scripts/git-signing.sh"); then
    _dot_ok "commit $signing"
  else
    _dot_info "commit $signing"
  fi

  echo "Repo"
  git -C "$DOTFILES" fetch --quiet origin 2>/dev/null
  local behind=$(git -C "$DOTFILES" rev-list --count HEAD..@{u} 2>/dev/null)
  [[ "${behind:-0}" -gt 0 ]] && _dot_info "$behind commit(s) behind origin (dot update)" || _dot_ok "up to date"
  [[ -n "$(git -C "$DOTFILES" status --porcelain)" ]] && _dot_info "uncommitted changes (dot status)"
  [[ -f "${HOME}/.zshrc.local" ]] && _dot_ok "~/.zshrc.local present" || _dot_info "no ~/.zshrc.local (optional, for machine-only settings)"

  unfunction _dot_ok _dot_bad _dot_info
  echo
  (( problems )) && { echo "$problems problem(s) found"; return 1; } || echo "All good"
}

_dot_complete() {
  local -a cmds
  cmds=(
    'cd:cd into the dotfiles repo'
    'edit:open the repo in an editor'
    'status:git status of the repo'
    'diff:git diff of the repo'
    'update:pull latest and re-run install'
    'reload:restart zsh to pick up config changes'
    'install:re-run install.sh'
    'doctor:check the setup'
    'help:show usage'
  )
  _describe 'dot command' cmds
}
compdef _dot_complete dot 2>/dev/null
