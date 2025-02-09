#$registryPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
#Set-ItemProperty -Path $registryPath -Name "プログラム名" -Value "実行ファイルのパス"

Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Install-Module Microsoft.WinGet.Client
Import-Module Microsoft.WinGet.Client
