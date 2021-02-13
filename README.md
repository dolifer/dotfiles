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

```poweshell
# WARNING: this will replace your Powershell profile
Set-Content -Value 'Invoke-Expression (&starship init powershell)' -Path $PROFILE
```

or manually edit the file with your favourite text editor and add this line to the end of file

```poweshell
Invoke-Expression (&starship init powershell)
```

## Configure

To get started configuring starship, create the following file: `~/.config/starship.toml`

-Nix
```
mkdir -p ~/.config && touch ~/.config/starship.toml
```

-Windows
```
New-Item -Type File -Path ~/.config/starship.toml -Force
```

After that replace the content with [my version](/.config/starship.toml) or [build your own](https://starship.rs/config/) :)

# `kubectx` + `kubens`: Power tools for kubectl

[kubectx]( https://github.com/ahmetb/kubectx ) repository provides both `kubectx` and `kubens` tools.

**`kubectx`** helps you switch between clusters back and forth:
![kubectx demo GIF]( https://github.com/ahmetb/kubectx/blob/master/img/kubectx-demo.gif)

**`kubens`** helps you switch between Kubernetes namespaces smoothly:
![kubens demo GIF]( https://github.com/ahmetb/kubectx/blob/master/img/kubens-demo.gif)
