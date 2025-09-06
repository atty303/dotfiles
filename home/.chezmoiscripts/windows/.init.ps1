# Initialization required for scripts executed by chezmoi apply

if (-not (Get-Command mise -ErrorAction SilentlyContinue)) {
    winget install --id jdx.mise --source winget
}

# The PowerShell bundled with Windows is outdated, so install the latest PowerShell Core (pwsh)
if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
    winget install --id Microsoft.PowerShell --source winget
}
