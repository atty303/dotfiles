$targetDir = Join-Path $env:USERPROFILE ".local\bin"
if (-not (Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir -Force
}

$targetPath = Join-Path $targetDir "atuin.exe"
Invoke-WebRequest -Uri "https://github.com/atty303/dotfiles/releases/download/atuin/atuin.exe" -OutFile $targetPath
