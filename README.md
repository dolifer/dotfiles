# Denis Olifer dotfiles

💻 Public repo for my personal dotfiles.

Features
- [🚀 Starship](https://starship.rs) as a prompt
- [zinit](https://github.com/zdharma-continuum/zinit) plugin manager with turbo mode (~230ms startup)
- Syntax highlighting, autosuggestions, fzf-tab completion
- OS-aware ssh-agent (macOS Keychain / Linux ssh-agent plugin)
- Cached tool inits (starship, zoxide) for fast startup
- Useful [aliases](./.zsh/aliases.zsh) and project index (`pj` commands)
- Ghostty and Zed editor configs

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
