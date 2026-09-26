# Denis Olifer dotfiles

💻 Public repo for my personal dotfiles.

Features
- [🚀 Starship](https://starship.rs) as a prompt
- [zinit](https://github.com/zdharma-continuum/zinit) plugin manager with turbo mode (~230ms startup)
- Syntax highlighting, autosuggestions, fzf-tab completion
- OS-aware ssh-agent (macOS Keychain / Linux ssh-agent plugin)
- Cached tool inits (starship, zoxide) for fast startup
- Useful [aliases](./.zsh/aliases.zsh) and a project jumper (`pj`, see below)
- Ghostty and Zed editor configs

## Projects: `pj`

`pj` indexes git repos under `~/projects` and jumps to them by name.

```sh
pj dotfiles        # cd into the repo (exact, prefix or substring match)
pj dot             # several matches open an fzf picker
pj                 # pick from all projects
pj dotfiles -e     # cd and open in Zed; -g opens Fork, -w the remote in the browser
pj help            # all subcommands: add, link, unlink, ls, clean, index
```

The index rebuilds itself when it is a day old or a name is not found. Set `PJ_ROOTS`, `PJ_DEPTH`, `PJ_EDITOR` or `PJ_GIT_GUI` before `aliases.zsh` is sourced to change the defaults. The old `pj-*` commands still work.

## Quick bootstrap (fresh machine)

```sh
curl -fsSL https://raw.githubusercontent.com/dolifer/dotfiles/main/bootstrap.sh | bash
```

This will install Xcode CLT (if needed), clone the repo, install Homebrew + packages, set up zinit, and sync all configs.

## Update

```sh
update
```

Pulls latest dotfiles, discards local changes, and re-syncs everything.

## Manual install

```sh
git clone https://github.com/dolifer/dotfiles.git $HOME/.dotfiles
cd $HOME/.dotfiles
./install.sh
```
