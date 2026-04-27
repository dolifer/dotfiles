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
# Index file: ~/.cache/pj-index.tsv (tab-separated: short_name, full_path, gitlab_url)
PJ_INDEX_FILE="${HOME}/.cache/pj-index.tsv"

# Rebuild the projects index by scanning ~/projects
# Skips non-git dirs and repos without a remote.
# Handles duplicate names by appending parent dir segments.
pj-index() {
  if [[ ! -d "${HOME}/projects" ]]; then
    echo "Error: ~/projects does not exist" >&2
    return 1
  fi

  mkdir -p "${HOME}/.cache"
  local tmpfile="${PJ_INDEX_FILE}.tmp.$$"
  local rawfile="${PJ_INDEX_FILE}.raw.$$"

  # First pass: collect raw entries to detect duplicate base names
  : > "$rawfile"
  for dir in "${HOME}/projects"/*(N/); do
    [[ ! -d "${dir}/.git" && ! -f "${dir}/.git" ]] && continue

    local remote_url=$(git -C "$dir" remote get-url origin 2>/dev/null)
    [[ -z "$remote_url" ]] && continue

    local name="${dir##*/}"
    printf '%s\t%s\t%s\n' "$name" "$dir" "$remote_url" >> "$rawfile"
  done

  # Find duplicate base names
  local -a dupes
  dupes=(${(f)"$(awk -F'\t' '{print $1}' "$rawfile" | sort | uniq -d)"})

  # Second pass: disambiguate duplicates with parent--name
  : > "$tmpfile"
  while IFS=$'\t' read -r name dir remote_url; do
    if (( ${dupes[(Ie)$name]} )); then
      local parent="${dir%/*}"
      parent="${parent##*/}"
      name="${parent}--${name}"
    fi
    printf '%s\t%s\t%s\n' "$name" "$dir" "$remote_url" >> "$tmpfile"
  done < "$rawfile"

  rm -f "$rawfile"
  mv -f "$tmpfile" "$PJ_INDEX_FILE"
  echo "Index rebuilt: $(wc -l < "$PJ_INDEX_FILE" | tr -d ' ') projects"
}

# Resolve a short name to full path via the index
_pj_resolve() {
  local query="$1"
  if [[ -f "$PJ_INDEX_FILE" ]]; then
    awk -F'\t' -v q="$query" '$1 == q { print $2; exit }' "$PJ_INDEX_FILE"
  fi
}

# Navigate to ~/projects or a specific project by short name
pj() {
  if [[ -z "$1" ]]; then
    builtin cd ~/projects
  else
    local resolved=$(_pj_resolve "$1")
    if [[ -n "$resolved" ]]; then
      builtin cd "$resolved"
    else
      echo "Error: '$1' not found in index. Run pj-index to rebuild." >&2
      return 1
    fi
  fi
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

  local project="${1%/}"
  local branch="$2"
  local repo_path=$(_pj_resolve "$project")

  if [[ -z "$repo_path" ]]; then
    echo "Error: '$project' not found in index. Run pj-index to rebuild." >&2
    return 1
  fi

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

# Clone a repo into ~/projects, detect default branch, pull it, rebuild index
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

  local dest="${HOME}/projects/${name}"

  if [[ -d "$dest" ]]; then
    echo "Already exists: $dest"
    # Still pull the default branch
  else
    mkdir -p "${HOME}/projects"
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
  if [[ ! -f "$PJ_INDEX_FILE" ]]; then
    echo "No index found. Run pj-index first." >&2
    return 1
  fi

  printf '%-35s %-50s %s\n' "PROJECT" "PATH" "REMOTE"
  printf '%-35s %-50s %s\n' "-------" "----" "------"
  awk -F'\t' -v home="$HOME" '{ gsub(home "/projects", "~/projects", $2); gsub(/^git@[^:]+:/, "", $3); printf "%-35s %-50s %s\n", $1, $2, ($3 ? $3 : "—") }' "$PJ_INDEX_FILE"
}

# --- Cleanup stale branches across all projects ---
# Removes local branches whose tracked remote branch no longer exists.
# Keeps local-only branches (no upstream set).
pj-clean() {
  local total=0
  for dir in "${HOME}/projects"/*(N/); do
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
_pj_link_complete() {
  if [[ -f "$PJ_INDEX_FILE" ]]; then
    local -a projects
    projects=(${(f)"$(awk -F'\t' '{ print $1 }' "$PJ_INDEX_FILE")"})
    compadd -a projects
  fi
}

_pj_unlink_complete() {
  local -a worktrees
  worktrees=(${(f)"$(find . -maxdepth 2 -name '.git' -type f -exec dirname {} \; 2>/dev/null | sed 's|^\./||')"})
  compadd -a worktrees
}

compdef _pj_link_complete pj-link 2>/dev/null
compdef _pj_link_complete pj 2>/dev/null
compdef _pj_unlink_complete pj-unlink 2>/dev/null

# cd with zsh-z capabilities (must be after function definitions)
# https://github.com/ajeetdsouza/zoxide
alias cd='z'
