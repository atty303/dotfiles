# Verify and install PowerShell Core (pwsh) if not present
# Purpose: Ensures environment readiness for subsequent 'run_before_' scripts
# Context: Automatically executed by chezmoi during dotfile initialization
if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
    winget install --id Microsoft.PowerShell --source winget
}

# https://gerardog.github.io/gsudo/
if (-not (Get-Command gsudo -ErrorAction SilentlyContinue)) {
    PowerShell -Command "Set-ExecutionPolicy RemoteSigned -scope Process; [Net.ServicePointManager]::SecurityProtocol = 'Tls12'; iwr -useb https://raw.githubusercontent.com/gerardog/gsudo/25d89fcac99b25534108804cb843fcbebe05a872/installgsudo.ps1 | iex"
}
