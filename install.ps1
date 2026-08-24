[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $ChezmoiArguments
)

$ErrorActionPreference = 'Stop'

$promptRoles = $false
if ($ChezmoiArguments.Count -gt 0 -and $ChezmoiArguments[0] -eq '--prompt-roles') {
    $promptRoles = $true
    $ChezmoiArguments = @($ChezmoiArguments | Select-Object -Skip 1)
}

$chezmoi = Get-Command chezmoi -ErrorAction SilentlyContinue
if (-not $chezmoi) {
    $binDirectory = Join-Path $HOME '.local/bin'
    Write-Host "Installing chezmoi to '$binDirectory'" -ForegroundColor Cyan
    & ([scriptblock]::Create((Invoke-RestMethod 'https://get.chezmoi.io/ps1'))) -b $binDirectory
    $chezmoiPath = Join-Path $binDirectory 'chezmoi.exe'
} else {
    $chezmoiPath = $chezmoi.Source
}

$roles = 'development,desktop,secrets'
$roleArguments = @(
    '--no-tty'
    '--promptMultichoice'
    "Roles=$($roles.Replace(',', '/'))"
)
$previousRoleDefaults = $env:CHEZMOI_ROLE_DEFAULTS
if ($promptRoles) {
    $env:CHEZMOI_ROLE_DEFAULTS = $roles
    $roleArguments = @()
}

$source = $PSScriptRoot
Push-Location $HOME
try {
    & $chezmoiPath init --apply --verbose @roleArguments "--source=$source" @ChezmoiArguments
    $chezmoiExitCode = $LASTEXITCODE
} finally {
    Pop-Location
    if ($promptRoles) {
        $env:CHEZMOI_ROLE_DEFAULTS = $previousRoleDefaults
    }
}
if ($chezmoiExitCode -ne 0) {
    exit $chezmoiExitCode
}
