$targetDir = Join-Path $env:USERPROFILE ".local\bin"
if (-not (Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir -Force
}

$targetPath = Join-Path $targetDir "atuin.exe"
if (-not (Test-Path $targetPath)) {
    Invoke-WebRequest -Uri "https://github.com/atty303/dotfiles/releases/download/atuin/atuin.exe" -OutFile $targetPath
}

$targetPath = Join-Path $targetDir "gitpod.exe"
if (-not (Test-Path $targetPath)) {
    Invoke-WebRequest -Uri "https://releases.gitpod.io/cli/stable/gitpod-windows-amd64.exe" -OutFile $targetPath
}
