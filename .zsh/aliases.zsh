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
: ${PJ_SANDBOX:=${HOME}/projects/sandbox}  # pj new / sb / keep / drop / prune
zmodload zsh/datetime              # EPOCHSECONDS
zmodload -F zsh/stat b:zstat

# Print "name<TAB>path<TAB>remote" for every git repo with an origin under $1,
# descending at most $2 levels. Does not descend into repos or the sandbox.
_pj_scan() {
  local dir remote_url
  for dir in "$1"/*(N/); do
    [[ "$dir" == "$PJ_SANDBOX" ]] && continue
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

# Print "name<TAB>path" for stdin entries (name<TAB>path[<TAB>...]) matching $1,
# case-insensitive. Only the best tier is printed: exact, else prefix, else substring.
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
    }'
}

# fzf picker over "name<TAB>path" lines on stdin, previewing the repo state
_pj_pick() {
  fzf --height=40% --reverse --delimiter=$'\t' --with-nth=1 --query="$1" \
      --prompt='pj> ' --preview-window=right,60% \
      --preview='git -C {2} log -1 --format="%C(yellow)%h%Creset %s%n%C(dim)%an, %ar%Creset" 2>/dev/null; echo; git -C {2} status -sb 2>/dev/null | head -20 || ls -A {2}'
}

# Choose one "name<TAB>path" from stdin entries matching $1.
# One match is printed directly; several open the fzf picker.
# Returns 2 when nothing matches.
_pj_select() {
  local -a lines
  lines=(${(f)"$(_pj_candidates "$1")"})
  if (( ${#lines} == 0 )); then
    return 2
  elif (( ${#lines} == 1 )); then
    print -r -- "${lines[1]}"
  elif _exists fzf; then
    print -rl -- "${lines[@]}" | _pj_pick "$1"
  else
    echo "pj: '$1' matches several projects:" >&2
    printf '  %s\n' "${lines[@]%%$'\t'*}" >&2
    return 1
  fi
}

# Resolve a (partial) project name to "name<TAB>path" via the index.
# On a miss the index is rebuilt once, in case the repo is new.
_pj_find() {
  _pj_ensure_index || return 1

  local hit rc
  hit=$(_pj_select "$1" < "$PJ_INDEX_FILE"); rc=$?
  if (( rc == 2 )); then
    local -a recent
    recent=($PJ_INDEX_FILE(N.mm-1))
    if (( ! ${#recent} )) && pj-index -q; then
      hit=$(_pj_select "$1" < "$PJ_INDEX_FILE"); rc=$?
    fi
  fi

  (( rc == 2 )) && echo "pj: no project matches '$1'" >&2
  (( rc == 0 )) && print -r -- "$hit"
  return $rc
}

# Parse pj flags into the caller's query, no_cd and actions locals
_pj_parse() {
  local arg
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
}

# cd into $1 (unless the caller's no_cd is set), then run the caller's actions
_pj_go() {
  local dir="$1" action remote_url
  [[ -z "$no_cd" ]] && { builtin cd "$dir" || return 1 }

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

Flags (also work with new and sb):
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

Sandbox ($PJ_SANDBOX):
  pj new [name|git-url]       start a scratch project (git init or clone) and cd in
  pj sb [name]                cd to the sandbox, or into one of its projects
  pj sb ls                    list sandbox projects with age and git state
  pj keep [name] [new-name]   move a sandbox project into ~/projects and index it
  pj drop [name]              delete a sandbox project (asks first)
  pj prune [days]             delete sandbox projects untouched for N days (30)
  Without a name, keep and drop act on the sandbox project you are in.
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
    new)          shift; pj-new "$@"; return ;;
    sb)           shift; pj-sb "$@"; return ;;
    keep)         shift; pj-keep "$@"; return ;;
    drop)         shift; pj-drop "$@"; return ;;
    prune)        shift; pj-prune "$@"; return ;;
    help|-h|--help) _pj_help; return ;;
    cd)           shift ;;
  esac

  local query no_cd hit
  local -a actions
  _pj_parse "$@" || return 1

  if [[ -n "$query" ]]; then
    hit=$(_pj_find "$query") || return 1
  elif _exists fzf; then
    _pj_ensure_index || return 1
    hit=$(cut -f1,2 "$PJ_INDEX_FILE" | _pj_pick) || return 1
  else
    builtin cd "${PJ_ROOTS[1]}"
    return
  fi

  _pj_go "${${hit#*$'\t'}%%$'\t'*}"
}

# --- Sandbox: scratch projects in PJ_SANDBOX ---

# "name<TAB>path" for each sandbox project, most recently modified first
_pj_sandbox_list() {
  local dir
  for dir in "$PJ_SANDBOX"/*(N/om); do
    printf '%s\t%s\n' "${dir##*/}" "$dir"
  done
}

# Resolve $1 to a sandbox project path; without $1, the one containing $PWD
_pj_sandbox_resolve() {
  if [[ -z "$1" ]]; then
    if [[ "$PWD" == "$PJ_SANDBOX"/* ]]; then
      local rel="${PWD#$PJ_SANDBOX/}"
      print -r -- "$PJ_SANDBOX/${rel%%/*}"
      return
    fi
    echo "pj: not inside a sandbox project, name one (pj sb ls)" >&2
    return 1
  fi

  local hit rc
  hit=$(_pj_sandbox_list | _pj_select "${1%/}"); rc=$?
  (( rc == 2 )) && echo "pj: no sandbox project matches '$1'" >&2
  (( rc == 0 )) || return 1
  print -r -- "${hit#*$'\t'}"
}

# Newest modification time (epoch) in a project, ignoring .git and node_modules
_pj_mtime() {
  setopt localoptions extendedglob
  local -a newest
  newest=("$1"/**/*~*/(.git|node_modules)/*(.DNom[1]))
  zstat +mtime "${newest[1]:-$1}"
}

# Short "3d"/"5h"/"12m" age for an epoch time
_pj_age() {
  local secs=$(( EPOCHSECONDS - $1 ))
  if   (( secs >= 86400 )); then print -r -- "$(( secs / 86400 ))d"
  elif (( secs >= 3600 ));  then print -r -- "$(( secs / 3600 ))h"
  else                           print -r -- "$(( secs / 60 ))m"
  fi
}

# Git state of a project: "clean", "N changed" or "no git"
_pj_git_state() {
  if [[ ! -e "$1/.git" ]]; then
    print -r -- "no git"
    return
  fi
  local changed=$(git -C "$1" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  if (( changed )); then print -r -- "$changed changed"; else print -r -- "clean"; fi
}

# Start a scratch project in the sandbox
# Usage: pj-new [name|git-url] [flags]
# Without a name: scratch-YYYYMMDD-HHMM. A git URL or path is cloned instead of git init.
pj-new() {
  local query no_cd
  local -a actions
  _pj_parse "$@" || return 1

  local name="$query" url
  case "$name" in
    */*|*:*)
      url="$name"
      name="${${${${url%/}%.git}%/}##*/}"
      ;;
    '')          name="scratch-$(date +%Y%m%d-%H%M)" ;;
  esac

  local dest="${PJ_SANDBOX}/${name}"
  if [[ -e "$dest" ]]; then
    echo "pj: sandbox already has '$name' (pj sb $name)" >&2
    return 1
  fi

  mkdir -p "$PJ_SANDBOX"
  if [[ -n "$url" ]]; then
    git clone "$url" "$dest" || return 1
  else
    mkdir -p "$dest" && git -C "$dest" init -q || return 1
  fi
  echo "New sandbox project: ${dest/#$HOME/~}"
  _pj_go "$dest"
}

# Jump to the sandbox or one of its projects
# Usage: pj-sb [name] [flags] | pj-sb ls
pj-sb() {
  [[ "$1" == "ls" ]] && { _pj_sandbox_ls; return }

  local query no_cd
  local -a actions
  _pj_parse "$@" || return 1

  if [[ -z "$query" ]]; then
    mkdir -p "$PJ_SANDBOX"
    _pj_go "$PJ_SANDBOX"
    return
  fi

  local dir
  dir=$(_pj_sandbox_resolve "$query") || return 1
  _pj_go "$dir"
}

# List sandbox projects with age of the last change and git state
_pj_sandbox_ls() {
  local -a entries
  entries=(${(f)"$(_pj_sandbox_list)"})
  if (( ! ${#entries} )); then
    echo "Sandbox is empty (${PJ_SANDBOX/#$HOME/~})"
    return
  fi

  printf '%-35s %-6s %s\n' "PROJECT" "AGE" "STATE"
  printf '%-35s %-6s %s\n' "-------" "---" "-----"
  local entry dir
  for entry in "${entries[@]}"; do
    dir="${entry#*$'\t'}"
    printf '%-35s %-6s %s\n' "${entry%%$'\t'*}" "$(_pj_age "$(_pj_mtime "$dir")")" "$(_pj_git_state "$dir")"
  done
}

# Move a sandbox project into the first project root and index it
# Usage: pj-keep [name] [new-name]
pj-keep() {
  local src
  src=$(_pj_sandbox_resolve "$1") || return 1
  local dest="${PJ_ROOTS[1]}/${2:-${src##*/}}"

  if [[ -e "$dest" ]]; then
    echo "pj: ${dest/#$HOME/~} already exists, pass a new name: pj keep ${src##*/} <new-name>" >&2
    return 1
  fi

  local inside
  [[ "$PWD" == "$src" || "$PWD" == "$src"/* ]] && inside="${PWD#$src}"

  mv "$src" "$dest" || return 1
  echo "Kept: ${src##*/} → ${dest/#$HOME/~}"
  [[ -n "$inside" || "$PWD" == "$src" ]] && builtin cd "${dest}${inside}"

  if git -C "$dest" remote get-url origin &>/dev/null; then
    pj-index -q
  else
    echo "No origin remote yet. pj finds it once you add one: git remote add origin <url>"
  fi
}

# Read a y/N answer; succeeds only on y or yes
_pj_confirm() {
  local answer
  read -r answer
  [[ "${answer:l}" == (y|yes) ]]
}

# Delete a sandbox project after confirmation
# Usage: pj-drop [name]
pj-drop() {
  local src
  src=$(_pj_sandbox_resolve "$1") || return 1
  if [[ "$src" != "$PJ_SANDBOX"/?* ]]; then
    echo "pj: refusing to delete '$src' outside the sandbox" >&2
    return 1
  fi

  printf 'Delete %s (%s, %s)? [y/N] ' "${src/#$HOME/~}" "$(du -sh "$src" 2>/dev/null | cut -f1 | tr -d ' ')" "$(_pj_git_state "$src")"
  _pj_confirm || return 1

  [[ "$PWD" == "$src" || "$PWD" == "$src"/* ]] && builtin cd "$PJ_SANDBOX"
  rm -rf -- "$src" && echo "Dropped ${src##*/}"
}

# Delete sandbox projects with no changes in the last N days, after confirmation
# Usage: pj-prune [days]
pj-prune() {
  local days="${1:-30}"
  if [[ "$days" != <-> ]]; then
    echo "Usage: pj-prune [days]" >&2
    return 1
  fi

  local cutoff=$(( EPOCHSECONDS - days * 86400 )) entry dir mtime
  local -a stale
  for entry in ${(f)"$(_pj_sandbox_list)"}; do
    dir="${entry#*$'\t'}"
    mtime=$(_pj_mtime "$dir")
    if (( mtime < cutoff )); then
      stale+=("$dir")
      printf '  %-35s %-6s %s\n' "${dir##*/}" "$(_pj_age "$mtime")" "$(_pj_git_state "$dir")"
    fi
  done

  if (( ! ${#stale} )); then
    echo "Nothing in the sandbox is older than ${days}d"
    return
  fi

  printf 'Delete these %d sandbox project(s)? [y/N] ' ${#stale}
  _pj_confirm || return 1

  for dir in "${stale[@]}"; do
    [[ "$PWD" == "$dir" || "$PWD" == "$dir"/* ]] && builtin cd "$PJ_SANDBOX"
    rm -rf -- "$dir" && echo "Dropped ${dir##*/}"
  done
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

_pj_sandbox_complete() {
  local -a names
  names=(${(f)"$(_pj_sandbox_list | cut -f1)"})
  _wanted sandbox expl 'sandbox project' compadd -a names
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
      'new:start a scratch project in the sandbox'
      'sb:go to the sandbox or one of its projects'
      'keep:move a sandbox project into ~/projects'
      'drop:delete a sandbox project'
      'prune:delete sandbox projects untouched for N days'
      'cd:jump to a project named like a subcommand'
      'help:show usage'
    )
    _describe -t commands 'subcommand' subcmds
    _pj_projects_complete
    return
  fi

  case "${words[2]}" in
    add|ls|list|clean|help|prune) ;;
    new)    [[ "$PREFIX" == -* ]] && _pj_flags_complete ;;
    sb)
      if [[ "$PREFIX" == -* ]]; then _pj_flags_complete
      elif (( CURRENT == 3 )); then compadd ls; _pj_sandbox_complete
      fi ;;
    keep|drop) (( CURRENT == 3 )) && _pj_sandbox_complete ;;
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
# Agents (Claude Code, Cursor, Codex) replay aliases in shells where zoxide's
# chpwd hook isn't set up, so `z` prints its "configuration issue" warning or
# fails on plain paths there. Keep the builtin cd for them.
if [[ -o interactive && -z "$CLAUDECODE$CURSOR_AGENT$CODEX_SANDBOX" ]]; then
  alias cd='z'
fi
