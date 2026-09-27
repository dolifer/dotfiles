# Denis Olifer dotfiles

💻 Public repo for my personal dotfiles.

Features
- [🚀 Starship](https://starship.rs) as a prompt
- [zinit](https://github.com/zdharma-continuum/zinit) plugin manager with turbo mode (~230ms startup)
- Syntax highlighting, autosuggestions, fzf-tab completion
- macOS only; Linux boxes are reached over ssh (Ghostty terminfo is installed on them automatically)
- Configs are symlinked into the repo, so edits in `~` are edits to the repo
- Cached tool inits (brew, starship, zoxide, fzf) for fast startup
- fzf with fd and bat previews, delta for git diffs
- Useful [aliases](./.zsh/aliases.zsh) and project index (`pj` commands)
- Ghostty and Zed editor configs

## Quick bootstrap (fresh machine)

```sh
curl -fsSL https://raw.githubusercontent.com/dolifer/dotfiles/main/bootstrap.sh | bash
```

This will install Xcode CLT (if needed), clone the repo, install Homebrew + packages, set up zinit, and sync all configs.

## Everyday use: `dot`

```sh
dot update     # pull latest, re-run install, restart zsh (refuses if the repo has local changes)
dot edit       # open the repo in $EDITOR (Zed by default); dot edit .zshrc for one file
dot status     # what you've changed; dot diff to see it
dot doctor     # check tools, links, git identity; re-checks the signing key
dot cd         # jump into the repo
```

`update` still works as an alias for `dot update`.

## Machine-local settings

Put anything that shouldn't be committed (work env vars, tokens, `PJ_*` overrides) in `~/.zshrc.local`. It is sourced before the aliases and never touched by install. Git identity and signing key live in `~/.gitlocal` the same way.

Commits are signed only when a usable GPG key is present: its secret key is in the keyring, it isn't expired or revoked, and it can sign. `install`, `dot update` and `dot doctor` check this and set `commit.gpgsign` in `~/.gitlocal` on or off to match (picking the first usable key if `user.signingkey` is empty), so a machine without a key, or one whose key expired, still commits unsigned instead of failing.

## Manual install

```sh
git clone https://github.com/dolifer/dotfiles.git $HOME/.dotfiles
cd $HOME/.dotfiles
./install.sh
```
