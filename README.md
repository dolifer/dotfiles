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
- [zoxide](https://github.com/ajeetdsouza/zoxide) behind `cd`: `cd dot zsh` jumps by frecency, `cdi` (or `cd foo<Space><Tab>`) picks with fzf and an eza preview, `pj` projects are known before your first visit, and `zoxide edit` fixes scores
- Useful [aliases](./.zsh/aliases.zsh) and a project jumper (`pj`, see below)
- [atuin](https://atuin.sh) history database on Ctrl-G next to fzf's Ctrl-R, plus [small everyday tools](#everyday-tools) (tldr, btop, dust, xh)
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

Scratch work lives in `~/projects/sandbox`, which the index skips:

```sh
pj new api-spike   # git init a sandbox project and cd in (no name: scratch-<date>)
pj new <git-url>   # or clone into the sandbox
pj sb [name]       # go to the sandbox or one of its projects; pj sb ls lists them
pj keep            # move the current sandbox project into ~/projects
pj drop            # delete it instead (asks first)
pj prune 30        # delete sandbox projects untouched for 30 days (asks first)
```

The index rebuilds itself when it is a day old or a name is not found. Set `PJ_ROOTS`, `PJ_DEPTH`, `PJ_SANDBOX`, `PJ_EDITOR` or `PJ_GIT_GUI` in `~/.zshrc.local` to change the defaults.

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

## Home and work machines

The first `install` asks whether this is a work machine and saves the answer (`home` or `work`) in `~/.config/dotfiles/profile`. Every machine gets `Brewfile`. Home machines also get `Brewfile.home` (currently just `gh`); work machines get `Brewfile.work` ([glab](https://gitlab.com/gitlab-org/cli) and [MeetingBar](https://meetingbar.app)). To switch a machine, edit that file and run `dot install`. Switching doesn't uninstall anything, so remove the other profile's tools by hand (`brew uninstall gh`).

On a work Mac, `glab auth login` once (pick your GitLab host), then `glab mr list`, `glab mr create --fill`, `glab ci status` or `glab ci view` from inside a repo. MeetingBar needs one-time calendar access on first launch; enable "Launch at login" in its preferences.

## Shell history: fzf and atuin

**Ctrl-R** is fzf over zsh's own history: fast, fuzzy, what you're used to. **Ctrl-G** opens [atuin](https://atuin.sh), which keeps every command in a SQLite database with the directory it ran in, its exit code, duration and host. Reach for it when Ctrl-R can't answer the question:

- "What was that kubectl command I ran *in this repo* last week?" Press Ctrl-G, then press Ctrl-R inside atuin to cycle the filter between global, host, session, directory and workspace (the current git repo).
- "Which of those attempts actually worked?" Failed commands are marked, and the preview shows exit code and duration.
- The same history on both Macs, if you want it (below).

Enter or Tab puts the command on the line to edit; it never runs it straight away. Up arrow stays on zsh-history-substring-search, and atuin's AI `?` key is turned off.

```sh
atuin import zsh                                  # once per machine: pull in the existing zsh history
atuin search --cwd . --exit 0 docker              # successful docker commands run in this directory
atuin search --after yesterday kubectl            # kubectl since yesterday
atuin stats                                       # your most-used commands
```

Sync is off until you opt in on a machine: `atuin register` on the first Mac, `atuin login` on the others, then `atuin sync`. History is end-to-end encrypted with a key kept in `~/.local/share/atuin/key` (copy it to the second Mac, don't commit it). Skip this on the work Mac if its history shouldn't leave the machine; local search works the same either way. Settings live in [`.config/atuin/config.toml`](./.config/atuin/config.toml).

## Everyday tools

Small tools installed on every machine, and the exact moment each one is for.

### tldr ([tlrc](https://github.com/tldr-pages/tlrc)): "how do I use this command again?"

Short, example-first cheat sheets for thousands of commands. Use it before `man` when you just need the common invocation.

```sh
tldr tar           # extract / create archives without reading the man page
tldr kubectl logs  # multi-word pages work too
tldr --update      # refresh the local page cache (it also updates itself periodically)
```

### [btop](https://github.com/aristocratos/btop): "why is the fan spinning / what's eating memory?"

Full-screen monitor for CPU per core, memory, disks, network and processes. Quicker to read than Activity Monitor when something is hogging the machine.

```sh
btop
```

Inside: `f` filters processes by name (e.g. `docker`, `node`), `e` toggles the process tree, `k` kills the selected process, `1`–`4` hide or show the CPU, memory, network and process panels, `Esc` opens the menu, `q` quits.

### [dust](https://github.com/bootandy/dust): "what's filling the disk?"

`du` as a sorted tree with bars, so the biggest folders are obvious at a glance. Use it when the disk is full or a repo feels heavy.

```sh
dust ~                      # biggest things in your home folder
dust -d 1 ~/projects        # one level deep: which project is largest
dust -n 30 ~/Library/Caches # top 30 entries (browser, Xcode, brew caches)
dust -X node_modules -X .git ~/projects  # skip dependency and git folders
dust -t ~/Downloads         # totals by file type
```

### [xh](https://github.com/ducaale/xh): "let me just hit this endpoint"

A friendlier curl for quick API calls from the terminal: JSON by default, colored output, readable request syntax. Use it for a one-off check; keep Bruno for collections you reuse.

```sh
xh :8080/health                                   # localhost shorthand
xh https://api.example.com/users q==denis         # query param
xh POST :8080/users name=Denis admin:=true        # JSON body: = string, := raw JSON
xh :8080/me Authorization:"Bearer $TOKEN"         # header
xh -b :8080/items | jq '.[0]'                     # body only, into jq
xh -h :8080/health                                # headers only
xh --offline POST :8080/users name=Denis          # print the request without sending it
xh --curl POST :8080/users name=Denis             # translate to a curl command to share
xh -d https://example.com/file.zip                # download with a progress bar
```

## Machine-local settings

Put anything that shouldn't be committed (work env vars, tokens, `PJ_*` overrides) in `~/.zshrc.local`. It is sourced before the aliases and never touched by install. Git identity and signing key live in `~/.gitlocal` the same way.

Commits are signed only when a usable GPG key is present: its secret key is in the keyring, it isn't expired or revoked, and it can sign. `install`, `dot update` and `dot doctor` check this and set `commit.gpgsign` in `~/.gitlocal` on or off to match (picking the first usable key if `user.signingkey` is empty), so a machine without a key, or one whose key expired, still commits unsigned instead of failing.

## Manual install

```sh
git clone https://github.com/dolifer/dotfiles.git $HOME/.dotfiles
cd $HOME/.dotfiles
./install.sh
```
