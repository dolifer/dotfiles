#!/bin/zsh
_exists() {
    command -v $1 > /dev/null 2>&1
}

# Quick reload of zsh environment
alias reload="source $HOME/.zshrc"

# Pull latest dotfiles and re-sync everything
alias update='git -C $HOME/.dotfiles fetch origin && git -C $HOME/.dotfiles reset --hard origin/main && $HOME/.dotfiles/install.sh'

# Folders Shortcuts
[ -d ~/Downloads ]            && alias dl='cd ~/Downloads'
[ -d ~/Desktop ]              && alias dt='cd ~/Desktop'

# Better ls with icons, tree view and more
# https://github.com/eza-community/eza
if _exists eza; then
  unalias ls 2>/dev/null
  alias ls='eza --icons --header --git'
  alias lt='eza --icons --tree'
  unalias l 2>/dev/null
  alias l='ls -l'
  alias la='ls -lAh'
fi

# cd with zsh-z capabilities
# https://github.com/ajeetdsouza/zoxide
# NOTE: alias is set after function definitions to avoid parse-time expansion
unalias cd 2>/dev/null

# --- Projects Index ---
# Index file: ~/.cache/pj-index.tsv (tab-separated: short_name, full_path, remote_url)
# Settings below can be overridden before this file is sourced.
PJ_INDEX_FILE="${HOME}/.cache/pj-index.tsv"
(( ${+PJ_ROOTS} )) || typeset -ga PJ_ROOTS=("${HOME}/projects")  # dirs scanned for repos
: ${PJ_DEPTH:=1}               # how many levels below each root to look for repos
: ${PJ_INDEX_TTL:=24}          # hours before the index is rebuilt automatically
: ${PJ_EDITOR:=zed}            # pj <name> -e
: ${PJ_GIT_GUI:=open -a Fork}  # pj <name> -g

# Print "name<TAB>path<TAB>remote" for every git repo with an origin under $1,
# descending at most $2 levels. Does not descend into repos.
_pj_scan() {
  local dir remote_url
  for dir in "$1"/*(N/); do
    if [[ -e "${dir}/.git" ]]; then
      remote_url=$(git -C "$dir" remote get-url origin 2>/dev/null)
      [[ -n "$remote_url" ]] && printf '%s\t%s\t%s\n' "${dir##*/}" "$dir" "$remote_url"
    elif (( $2 > 1 )); then
      _pj_scan "$dir" $(( $2 - 1 ))
    fi
  done
}

# Rebuild the projects index by scanning PJ_ROOTS
# Skips non-git dirs and repos without a remote.
# Handles duplicate names by appending parent dir segments.
# Usage: pj-index [-q]
pj-index() {
  local quiet
  [[ "$1" == "-q" ]] && quiet=1

  local -a roots
  roots=(${^PJ_ROOTS}(N/))
  if (( ! ${#roots} )); then
    echo "Error: no project root exists (PJ_ROOTS: ${PJ_ROOTS[*]})" >&2
    return 1
  fi

  mkdir -p "${PJ_INDEX_FILE:h}"
  local tmpfile="${PJ_INDEX_FILE}.tmp.$$"
  local rawfile="${PJ_INDEX_FILE}.raw.$$"

  # First pass: collect raw entries to detect duplicate base names
  : > "$rawfile"
  local root
  for root in "${roots[@]}"; do
    _pj_scan "$root" "$PJ_DEPTH" >> "$rawfile"
  done

  # Find duplicate base names
  local -a dupes
  dupes=(${(f)"$(awk -F'\t' '{print $1}' "$rawfile" | sort | uniq -d)"})

  # Second pass: disambiguate duplicates with parent--name
  : > "$tmpfile"
  local name dir remote_url parent
  while IFS=$'\t' read -r name dir remote_url; do
    if (( ${dupes[(Ie)$name]} )); then
      parent="${dir%/*}"
      parent="${parent##*/}"
      name="${parent}--${name}"
    fi
    printf '%s\t%s\t%s\n' "$name" "$dir" "$remote_url" >> "$tmpfile"
  done < "$rawfile"

  rm -f "$rawfile"
  mv -f "$tmpfile" "$PJ_INDEX_FILE"
  [[ -z "$quiet" ]] && echo "Index rebuilt: $(wc -l < "$PJ_INDEX_FILE" | tr -d ' ') projects"
  return 0
}

# Rebuild the index quietly when it is missing or older than PJ_INDEX_TTL hours
_pj_ensure_index() {
  local -a fresh
  fresh=($PJ_INDEX_FILE(N.mh-${PJ_INDEX_TTL}))
  (( ${#fresh} )) || pj-index -q
}

# Print "name<TAB>path" for index entries matching $1 (case-insensitive).
# Only the best tier is printed: exact name, else prefix, else substring.
_pj_candidates() {
  awk -F'\t' -v q="$1" '
    BEGIN { q = tolower(q) }
    {
      n = tolower($1); line = $1 "\t" $2
      if (n == q)              exact[++e] = line
      else if (index(n, q) == 1) prefix[++p] = line
      else if (index(n, q))      mid[++m] = line
    }
    END {
      if (e)      for (i = 1; i <= e; i++) print exact[i]
      else if (p) for (i = 1; i <= p; i++) print prefix[i]
      else        for (i = 1; i <= m; i++) print mid[i]
    }' "$PJ_INDEX_FILE"
}

# fzf picker over "name<TAB>path" lines on stdin, previewing the repo state
_pj_pick() {
  fzf --height=40% --reverse --delimiter=$'\t' --with-nth=1 --query="$1" \
      --prompt='pj> ' --preview-window=right,60% \
      --preview='git -C {2} log -1 --format="%C(yellow)%h%Creset %s%n%C(dim)%an, %ar%Creset" 2>/dev/null; echo; git -C {2} status -sb 2>/dev/null | head -20'
}

# Resolve a (partial) project name to "name<TAB>path".
# One match is returned directly; several open the fzf picker.
# On a miss the index is rebuilt once, in case the repo is new.
_pj_find() {
  local query="$1" matches
  _pj_ensure_index || return 1

  matches=$(_pj_candidates "$query")
  if [[ -z "$matches" ]]; then
    local -a recent
    recent=($PJ_INDEX_FILE(N.mm-1))
    (( ${#recent} )) || { pj-index -q && matches=$(_pj_candidates "$query") }
  fi

  local -a lines
  lines=(${(f)matches})
  if (( ${#lines} == 0 )); then
    echo "pj: no project matches '$query'" >&2
    return 1
  elif (( ${#lines} == 1 )); then
    print -r -- "${lines[1]}"
  elif _exists fzf; then
    print -rl -- "${lines[@]}" | _pj_pick "$query"
  else
    echo "pj: '$query' matches several projects:" >&2
    printf '  %s\n' "${lines[@]%%$'\t'*}" >&2
    return 1
  fi
}

# Open a URL with the OS handler
_pj_open_url() {
  if [[ "$OSTYPE" == darwin* ]]; then
    open "$1"
  else
    xdg-open "$1" >/dev/null 2>&1
  fi
}

# Turn a git remote (ssh or https) into its web URL
_pj_web_url() {
  print -r -- "$1" | sed -E \
    -e 's#\.git$##' \
    -e 's#^ssh://([^@/]+@)?([^/:]+)(:[0-9]+)?/#https://\2/#' \
    -e 's#^[^@/:]+@([^:/]+):#https://\1/#' \
    -e 's#^(https?)://[^@/]+@#\1://#'
}

_pj_help() {
  cat <<'EOF'
Usage:
  pj                      pick a project with fzf and cd into it
  pj <name> [flags]       cd into a project (exact, prefix or substring match)
  pj cd <name> [flags]    same, for projects named like a subcommand

Flags:
  -e, --edit    open the project in $PJ_EDITOR (zed)
  -g, --git     open the project in $PJ_GIT_GUI (Fork)
  -w, --web     open the project's remote in the browser
  -n, --no-cd   stay in the current directory

Subcommands:
  pj add <git-url>            clone into the first root and reindex   (pj-add)
  pj link <name> [branch]     create a worktree here                  (pj-link)
  pj unlink <folder>          remove a worktree here                  (pj-unlink)
  pj ls                       list indexed projects                   (pj-list)
  pj clean                    delete branches whose remote is gone    (pj-clean)
  pj index [-q]               rebuild the index                       (pj-index)
EOF
}

# Jump to a project, optionally opening it in the editor, git GUI or browser.
# See _pj_help for usage.
pj() {
  case "$1" in
    add)          shift; pj-add "$@"; return ;;
    link)         shift; pj-link "$@"; return ;;
    unlink)       shift; pj-unlink "$@"; return ;;
    ls|list)      shift; pj-list "$@"; return ;;
    clean)        shift; pj-clean "$@"; return ;;
    index)        shift; pj-index "$@"; return ;;
    help|-h|--help) _pj_help; return ;;
    cd)           shift ;;
  esac

  local query arg no_cd
  local -a actions
  for arg in "$@"; do
    case "$arg" in
      -e|--edit)  actions+=(edit) ;;
      -g|--git)   actions+=(git) ;;
      -w|--web)   actions+=(web) ;;
      -n|--no-cd) no_cd=1 ;;
      -*)         echo "pj: unknown flag '$arg' (see pj help)" >&2; return 1 ;;
      *)          query="$arg" ;;
    esac
  done

  local hit
  if [[ -n "$query" ]]; then
    hit=$(_pj_find "$query") || return 1
  elif _exists fzf; then
    _pj_ensure_index || return 1
    hit=$(cut -f1,2 "$PJ_INDEX_FILE" | _pj_pick) || return 1
  else
    builtin cd "${PJ_ROOTS[1]}"
    return
  fi

  local dir="${${hit#*$'\t'}%%$'\t'*}"
  [[ -z "$no_cd" ]] && { builtin cd "$dir" || return 1 }

  local action remote_url
  for action in "${actions[@]}"; do
    case "$action" in
      edit) ${=PJ_EDITOR} "$dir" ;;
      git)  ${=PJ_GIT_GUI} "$dir" ;;
      web)
        remote_url=$(git -C "$dir" remote get-url origin 2>/dev/null)
        if [[ -z "$remote_url" ]]; then
          echo "pj: no origin remote in $dir" >&2
        else
          _pj_open_url "$(_pj_web_url "$remote_url")"
        fi
        ;;
    esac
  done
  return 0
}

# Create a git worktree in current dir from a project repo
# Usage: pj-link <project-name> [branch]
# Without branch: uses the repo's default branch
# With branch: creates worktree on that branch (fetches if needed)
pj-link() {
  if [[ -z "$1" ]]; then
    echo "Usage: pj-link <project-name> [branch]" >&2
    return 1
  fi

  local branch="$2"
  local hit=$(_pj_find "${1%/}") || return 1
  local project="${hit%%$'\t'*}"
  local repo_path="${hit#*$'\t'}"

  if [[ ! -d "$repo_path/.git" ]]; then
    echo "Error: '$repo_path' is not a git repository" >&2
    return 1
  fi

  # Detect default branch if not specified
  if [[ -z "$branch" ]]; then
    branch=$(git -C "$repo_path" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')
    if [[ -z "$branch" ]]; then
      # Fallback: try common names
      for candidate in main master develop; do
        if git -C "$repo_path" rev-parse --verify "origin/$candidate" &>/dev/null; then
          branch="$candidate"
          break
        fi
      done
    fi
    if [[ -z "$branch" ]]; then
      echo "Error: cannot detect default branch for '$project'. Specify one: pj-link $project <branch>" >&2
      return 1
    fi
  fi

  local dest="${PWD}/${project}"

  if [[ -d "$dest" ]]; then
    echo "Error: '$dest' already exists" >&2
    return 1
  fi

  # Fetch the branch if not available locally
  git -C "$repo_path" fetch origin "$branch" 2>/dev/null

  # If branch is already checked out in another worktree, create a new branch
  # named after the current directory, based on the target branch
  local worktree_branch="$branch"
  if git -C "$repo_path" worktree list 2>/dev/null | grep -q "\[$branch\]"; then
    worktree_branch="$(basename "$PWD")"
    echo "Branch '$branch' in use — creating '$worktree_branch' from 'origin/$branch'"
    git -C "$repo_path" worktree add -b "$worktree_branch" "$dest" "origin/$branch" 2>&1 && \
      echo "Worktree: $project → $dest (branch: $worktree_branch ← origin/$branch)"
    return
  fi

  git -C "$repo_path" worktree add "$dest" "$branch" 2>&1 && \
    echo "Worktree: $project → $dest (branch: $branch)"
}

# Clone a repo into the first PJ_ROOTS dir, detect default branch, pull it, rebuild index
# Usage: pj-add git@host:org/repo.git or pj-add https://host/org/repo.git
pj-add() {
  if [[ -z "$1" ]]; then
    echo "Usage: pj-add <git-url>" >&2
    return 1
  fi

  local url="${1%.git}"
  local name="${url##*/}"

  if [[ -z "$name" ]]; then
    echo "Error: could not extract repo name from '$1'" >&2
    return 1
  fi

  local dest="${PJ_ROOTS[1]}/${name}"

  if [[ -d "$dest" ]]; then
    echo "Already exists: $dest"
    # Still pull the default branch
  else
    mkdir -p "${PJ_ROOTS[1]}"
    git clone "$1" "$dest" || return 1
  fi

  # Detect default branch and pull
  local branch=$(git -C "$dest" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')
  if [[ -z "$branch" ]]; then
    # HEAD ref not set — set it from remote
    git -C "$dest" remote set-head origin --auto 2>/dev/null
    branch=$(git -C "$dest" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')
  fi

  if [[ -n "$branch" ]]; then
    git -C "$dest" checkout "$branch" 2>/dev/null
    git -C "$dest" pull --ff-only origin "$branch" 2>/dev/null
    echo "Default branch: $branch (pulled)"
  fi

  pj-index
}

# Remove a git worktree by directory name in current dir
# Usage: pj-unlink folder-name
pj-unlink() {
  if [[ -z "$1" ]]; then
    echo "Usage: pj-unlink name" >&2
    return 1
  fi

  local name="${1%/}"
  local target="${PWD}/${name}"

  if [[ ! -d "$target" ]]; then
    echo "Error: '$name' does not exist" >&2
    return 1
  fi

  # Check if it's a git worktree
  if [[ -f "$target/.git" ]]; then
    # .git is a file in worktrees (points to main repo)
    local main_repo=$(git -C "$target" rev-parse --git-common-dir 2>/dev/null)
    if [[ -n "$main_repo" ]]; then
      git -C "$target" worktree remove "$target" --force 2>&1 && \
        echo "Removed worktree: $name"
      return
    fi
  fi

  echo "Error: '$name' is not a git worktree" >&2
  return 1
}

# Pretty-print all indexed projects
pj-list() {
  _pj_ensure_index || return 1

  printf '%-35s %-50s %s\n' "PROJECT" "PATH" "REMOTE"
  printf '%-35s %-50s %s\n' "-------" "----" "------"
  awk -F'\t' -v home="$HOME" '{ if (index($2, home) == 1) $2 = "~" substr($2, length(home) + 1); gsub(/^git@[^:]+:/, "", $3); printf "%-35s %-50s %s\n", $1, $2, ($3 ? $3 : "—") }' "$PJ_INDEX_FILE"
}

# --- Cleanup stale branches across all projects ---
# Removes local branches whose tracked remote branch no longer exists.
# Keeps local-only branches (no upstream set).
pj-clean() {
  _pj_ensure_index || return 1
  local total=0 dir
  local -a dirs
  dirs=(${(f)"$(cut -f2 "$PJ_INDEX_FILE")"})
  for dir in "${dirs[@]}"; do
    [[ ! -d "${dir}/.git" ]] && continue
    local name="${dir##*/}"

    # Prune remote tracking refs
    git -C "$dir" fetch --prune --quiet 2>/dev/null || continue

    # Find branches with a gone upstream
    local -a gone
    gone=(${(f)"$(git -C "$dir" for-each-ref --format='%(refname:short) %(upstream:track)' refs/heads/ 2>/dev/null | awk '/\[gone\]/{print $1}')"})

    [[ ${#gone[@]} -eq 0 ]] && continue

    echo "📂 $name"
    for b in "${gone[@]}"; do
      git -C "$dir" branch -D "$b" 2>/dev/null && echo "  🗑️  $b" && ((total++))
    done
  done

  if [[ $total -eq 0 ]]; then
    echo "✅ All clean — no stale branches found"
  else
    echo "🧹 Removed $total stale branch(es)"
  fi
}

# --- Completions ---
_pj_projects_complete() {
  local -a projects
  [[ -f "$PJ_INDEX_FILE" ]] && projects=(${(f)"$(cut -f1 "$PJ_INDEX_FILE")"})
  _wanted projects expl 'project' compadd -a projects
}

_pj_flags_complete() {
  local -a flags
  flags=(
    '-e:open in editor'
    '-g:open in git GUI'
    '-w:open remote in browser'
    '-n:do not cd'
  )
  _describe -t flags 'flag' flags
}

_pj_link_complete() {
  if (( CURRENT == 2 )); then
    _pj_projects_complete
  elif (( CURRENT == 3 )); then
    # Branches of the chosen project, local and remote
    local repo_path=$(awk -F'\t' -v q="${words[2]%/}" '$1 == q { print $2; exit }' "$PJ_INDEX_FILE" 2>/dev/null)
    [[ -z "$repo_path" ]] && return
    local -a branches
    branches=(${(f)"$(git -C "$repo_path" for-each-ref --format='%(refname:short)' refs/heads refs/remotes/origin 2>/dev/null | sed -e 's#^origin/##' -e '/^HEAD$/d' -e '/^origin$/d' | sort -u)"})
    _wanted branches expl 'branch' compadd -a branches
  fi
}

_pj_unlink_complete() {
  local -a worktrees
  worktrees=(${(f)"$(find . -maxdepth 2 -name '.git' -type f -exec dirname {} \; 2>/dev/null | sed 's|^\./||')"})
  compadd -a worktrees
}

_pj() {
  if (( CURRENT == 2 )); then
    if [[ "$PREFIX" == -* ]]; then
      _pj_flags_complete
      return
    fi
    local -a subcmds
    subcmds=(
      'add:clone a repo and index it'
      'link:create a worktree here'
      'unlink:remove a worktree here'
      'ls:list indexed projects'
      'clean:delete branches whose remote is gone'
      'index:rebuild the project index'
      'cd:jump to a project named like a subcommand'
      'help:show usage'
    )
    _describe -t commands 'subcommand' subcmds
    _pj_projects_complete
    return
  fi

  case "${words[2]}" in
    add|ls|list|clean|help) ;;
    index)  compadd -- -q ;;
    link)   (( CURRENT-- )); shift words; _pj_link_complete ;;
    unlink) _pj_unlink_complete ;;
    cd)
      if [[ "$PREFIX" == -* ]]; then _pj_flags_complete; else _pj_projects_complete; fi ;;
    *)      _pj_flags_complete ;;
  esac
}

compdef _pj pj 2>/dev/null
compdef _pj_link_complete pj-link 2>/dev/null
compdef _pj_unlink_complete pj-unlink 2>/dev/null

# cd with zsh-z capabilities (must be after function definitions)
# https://github.com/ajeetdsouza/zoxide
alias cd='z'
