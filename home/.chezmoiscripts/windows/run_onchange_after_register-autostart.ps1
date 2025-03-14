$executables = @(
    "$env:USERPROFILE\.local\bin\atty303.ahk"
)

$executables | ForEach-Object {
    $startupPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
    $shortcutName = [System.IO.Path]::GetFileNameWithoutExtension($_)
    $shortcutPath = Join-Path $startupPath "$shortcutName.lnk"

    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $_
    $shortcut.Save()

    Write-Host "Created a shortcut to $_ in $shortcutPath"
}
