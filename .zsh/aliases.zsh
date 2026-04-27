#!/bin/zsh
_exists() {
    command -v $1 > /dev/null 2>&1
}

# Quick reload of zsh environment
alias reload="source $HOME/.zshrc"

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
pj-index() {
  if [[ ! -d "${HOME}/projects" ]]; then
    echo "Error: ~/projects does not exist" >&2
    return 1
  fi

  mkdir -p "${HOME}/.cache"
  local tmpfile="${PJ_INDEX_FILE}.tmp.$$"

  for dir in "${HOME}/projects"/*(N/); do
    [[ ! -d "${dir}/.git" ]] && continue

    local name="${dir##*/}"
    local remote_url=$(git -C "$dir" remote get-url origin 2>/dev/null || echo "")

    printf '%s\t%s\t%s\n' "$name" "$dir" "$remote_url"
  done > "$tmpfile"

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

# Create a symlink in current dir using the last path segment as name
# Usage: pj-link <short-name|/full/path>
pj-link() {
  if [[ -z "$1" ]]; then
    echo "Usage: pj-link <project-name or /path/to/target>" >&2
    return 1
  fi

  local target="${1%/}"

  # If not a path, try resolving from index
  if [[ "$target" != /* ]]; then
    local resolved=$(_pj_resolve "$target")
    if [[ -n "$resolved" ]]; then
      target="$resolved"
    else
      echo "Error: '$target' not found in index. Run pj-index to rebuild." >&2
      return 1
    fi
  fi

  local name="${target##*/}"

  if [[ ! -e "$target" ]]; then
    echo "Error: '$target' does not exist" >&2
    return 1
  fi

  if [[ -L "$name" ]]; then
    rm -f "$name"
  elif [[ -e "$name" ]]; then
    echo "Error: '$name' already exists and is not a symlink" >&2
    return 1
  fi

  ln -s "$target" "$name" && echo "Linked: $name → $target"
}

# Clone a repo into ~/projects and rebuild the index
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
    return 0
  fi

  mkdir -p "${HOME}/projects"
  git clone "$1" "$dest" && pj-index
}

# Remove a symlink by name, silently ignores non-symlinks and missing targets
# Usage: pj-unlink folder-name
pj-unlink() {
  if [[ -z "$1" ]]; then
    echo "Usage: pj-unlink name" >&2
    return 1
  fi

  local name="${1%/}"

  if [[ -L "$name" ]]; then
    rm -f "$name" && echo "Unlinked: $name"
  fi
}

# Pretty-print all indexed projects
pj-list() {
  if [[ ! -f "$PJ_INDEX_FILE" ]]; then
    echo "No index found. Run pj-index first." >&2
    return 1
  fi

  printf '%-35s %-50s %s\n' "PROJECT" "PATH" "REMOTE"
  printf '%-35s %-50s %s\n' "-------" "----" "------"
  awk -F'\t' -v home="$HOME" '{ gsub(home "/projects", "~/projects", $2); gsub(/^git@git\.betlab\.com:/, "", $3); printf "%-35s %-50s %s\n", $1, $2, ($3 ? $3 : "—") }' "$PJ_INDEX_FILE"
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
  local -a symlinks
  symlinks=(${(f)"$(find . -maxdepth 1 -type l -exec basename {} \;)"})
  compadd -a symlinks
}

compdef _pj_link_complete pj-link
compdef _pj_link_complete pj
compdef _pj_unlink_complete pj-unlink

# cd with zsh-z capabilities (must be after function definitions)
# https://github.com/ajeetdsouza/zoxide
alias cd='z'
