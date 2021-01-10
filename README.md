# dotfiles

💻 Public repo for my personal dotfiles.

# Shell

I'm using Starship, visit [starship.rs](https://starship.rs) to read more.

## Install latest version

* With Curl
```
curl -fsSL https://starship.rs/install.sh | bash
```

* With [Homebrew](https://brew.sh/)
```
brew install starship
```

* With [Scoop](https://scoop.sh)

```
Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://get.scoop.sh')

# or shorter
iwr -useb get.scoop.sh | iex
```

```
scoop install starship
```

## Add the init script to your shell's config file

### Zsh

Add the following to the end of `~/.zshrc`:

```
# ~/.zshrc

eval "$(starship init zsh)"
```

### Powershell

Add the following to the end of `Microsoft.PowerShell_profile.ps1`. 
You can check the location of this file by querying the `$PROFILE` variable in PowerShell. 
Typically the path is `~\Documents\PowerShell\Microsoft.PowerShell_profile.ps1` or `~/.config/powershell/Microsoft.PowerShell_profile.ps1` on -Nix.

```
Invoke-Expression (&starship init powershell)
```

## Configure

To get started configuring starship, create the following file: `~/.config/starship.toml`

```
mkdir -p ~/.config && touch ~/.config/starship.toml
```

After that replace the content with [my version](/.config/starship.toml) or [build your own](https://starship.rs/config/) :)
