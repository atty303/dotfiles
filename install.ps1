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
if ($promptRoles) {
    $selection = Read-Host "Roles (development,desktop,gaming,secrets,work) [$roles]"
    if ($selection -eq '-') {
        $roles = ''
    } elseif ($selection) {
        $roles = $selection
    }
}

$source = $PSScriptRoot
Push-Location $HOME
try {
    & $chezmoiPath init --apply --verbose --no-tty `
        --promptString "Roles=$roles" `
        "--source=$source" @ChezmoiArguments
    $chezmoiExitCode = $LASTEXITCODE
} finally {
    Pop-Location
}
if ($chezmoiExitCode -ne 0) {
    exit $chezmoiExitCode
}
