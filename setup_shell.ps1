Write-Host "Setting up Powershell in $PROFILE"

Copy-Item ./.config/starship.toml ~/.config/starship.toml
Copy-Item ./Microsoft.PowerShell_profile.ps1 $PROFILE