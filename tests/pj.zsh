#!/bin/zsh
# Tests for the pj project jumper in .zsh/aliases.zsh.
# Runs against a throwaway HOME, so it never touches your real index.
# Usage: zsh tests/pj.zsh

emulate -L zsh

REPO="${0:A:h:h}"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home"
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1  # no url.insteadOf rewrites
unset GIT_CONFIG_COUNT
P="$HOME/projects"

fails=0 passes=0
ok()   { (( ++passes )); print -r -- "ok   $1" }
fail() { (( ++fails ));  print -r -- "FAIL $1"; [[ -n "${2-}" ]] && print -r -- "     $2" }

# expect_cd <query> <dir>: `pj <query>` succeeds and lands in <dir>
expect_cd() {
  builtin cd "$TMP"
  if pj "$1" >/dev/null 2>&1 && [[ "$PWD" == "$2" ]]; then
    ok "pj $1 -> ${2#$HOME/}"
  else
    fail "pj $1 -> ${2#$HOME/}" "landed in ${PWD#$HOME/}"
  fi
}

# expect_miss <query>: `pj <query>` fails and stays put
expect_miss() {
  builtin cd "$TMP"
  if ! pj "$1" >/dev/null 2>&1 && [[ "$PWD" == "$TMP" ]]; then
    ok "pj $1 finds nothing"
  else
    fail "pj $1 finds nothing" "landed in ${PWD#$HOME/}"
  fi
}

mkrepo() {
  mkdir -p "$1"
  git -C "$1" init -q
  [[ -n "${2-}" ]] && git -C "$1" remote add origin "$2"
  return 0
}

# Layout:
#   projects/dotfiles            repo
#   projects/github/             folder
#   projects/github/ngql         repo
#   projects/github/gitops       repo
#   projects/notes/              folder (no repos inside)
#   projects/work/dotfiles       repo with a duplicate name
#   projects/local-only          repo without origin (skipped)
#   projects/sandbox/spike       sandbox (skipped)
mkrepo "$P/dotfiles"        git@github.com:dolifer/dotfiles.git
mkrepo "$P/github/ngql"     git@github.com:dolifer/ngql.git
mkrepo "$P/github/gitops"   https://github.com/dolifer/gitops.git
mkrepo "$P/work/dotfiles"   git@gitlab.com:work/dotfiles.git
mkrepo "$P/local-only"
mkdir -p "$P/notes" "$P/sandbox/spike"

PJ_DEPTH=2
source "$REPO/.zsh/aliases.zsh" 2>/dev/null
# Hide fzf so ties print the choices instead of opening an interactive picker
_exists() { [[ "$1" != fzf ]] && command -v "$1" >/dev/null 2>&1 }

pj index -q
index=$(<"$PJ_INDEX_FILE")
field() { awk -F'\t' -v n="$1" -v c="$2" '$1 == n { print $c; exit }' "$PJ_INDEX_FILE" }

# --- index ---
[[ "$(field github 2)" == "$P/github" && -z "$(field github 3)" ]] \
  && ok "index lists folder github with no remote" || fail "index lists folder github with no remote" "$index"
[[ "$(field notes 2)" == "$P/notes" ]] \
  && ok "index lists folder notes" || fail "index lists folder notes" "$index"
[[ "$(field ngql 3)" == "git@github.com:dolifer/ngql.git" ]] \
  && ok "index lists repo ngql with its remote" || fail "index lists repo ngql with its remote" "$index"
[[ "$(field projects--dotfiles 2)" == "$P/dotfiles" && "$(field work--dotfiles 2)" == "$P/work/dotfiles" ]] \
  && ok "duplicate names get a parent prefix" || fail "duplicate names get a parent prefix" "$index"
[[ "$index" != *local-only* ]] && ok "repo without origin is skipped" || fail "repo without origin is skipped" "$index"
[[ "$index" != *sandbox* ]] && ok "sandbox is skipped" || fail "sandbox is skipped" "$index"
[[ "$index" != *$'\t'"$P/dotfiles/"* ]] && ok "repos are not descended into" || fail "repos are not descended into" "$index"
[[ "$(pj index)" == "Index rebuilt: 4 projects, 3 folders" ]] \
  && ok "pj index counts projects and folders" || fail "pj index counts projects and folders" "$(pj index)"

# --- jumping ---
expect_cd github "$P/github"          # folder, exact
expect_cd ngql   "$P/github/ngql"     # repo inside a folder, exact
expect_cd NGQL   "$P/github/ngql"     # case-insensitive
expect_cd note   "$P/notes"           # folder, prefix
expect_cd ngq    "$P/github/ngql"     # repo, prefix
expect_cd gql    "$P/github/ngql"     # repo, substring
expect_cd work   "$P/work"            # folder that only holds repos
expect_cd work--dot "$P/work/dotfiles"
expect_miss nope

# A repo and a folder that match equally well: pj asks instead of picking
builtin cd "$TMP"
out=$(pj git 2>&1); rc=$?
if (( rc != 0 )) && [[ "$PWD" == "$TMP" && "$out" == *"matches several"* && "$out" == *github* && "$out" == *gitops* ]]; then
  ok "pj git asks between folder github and repo gitops"
else
  fail "pj git asks between folder github and repo gitops" "$out"
fi
expect_miss local-only

# -n stays put
builtin cd "$TMP"; pj github -n >/dev/null 2>&1
[[ "$PWD" == "$TMP" ]] && ok "pj github -n does not cd" || fail "pj github -n does not cd"

# A folder created after the index was built is found by the rebuild on a miss
mkdir -p "$P/fresh"
touch -t 200001010000 "$PJ_INDEX_FILE"
expect_cd fresh "$P/fresh"

# pj ls marks folders
[[ "$(pj ls)" == *"~/projects/github "*"(folder)"* ]] \
  && ok "pj ls marks folders" || fail "pj ls marks folders" "$(pj ls)"

# pj link refuses a folder
builtin cd "$TMP"
pj link notes >/dev/null 2>&1 && fail "pj link refuses a folder" || ok "pj link refuses a folder"

print
print "$passes passed, $fails failed"
(( fails == 0 ))
