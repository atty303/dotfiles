$paths = @(
    "$env:USERPROFILE\.local\bin"
)

$paths | ForEach-Object {
    $pathToAdd = $_
    # パスが既に含まれているかチェック
    $currentPath = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::User)
    if (-not ($currentPath -split ";" -contains $pathToAdd)) {
        # パスが含まれていない場合は追加
        $newPath = $currentPath + ";" + $pathToAdd
        [System.Environment]::SetEnvironmentVariable("Path", $newPath, [System.EnvironmentVariableTarget]::User)
    }
}