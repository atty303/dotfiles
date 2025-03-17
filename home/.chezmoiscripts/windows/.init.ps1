# Verify and install PowerShell Core (pwsh) if not present
# Purpose: Ensures environment readiness for subsequent 'run_before_' scripts
# Context: Automatically executed by chezmoi during dotfile initialization
if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
    winget install --id Microsoft.PowerShell --source winget
}