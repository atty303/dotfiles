$googleFontsToInstall = @(
    "IBM Plex Sans Condensed"
    "IBM Plex Sans JP"
)
$zipFontsToInstall = @(
    "https://github.com/yuru7/udev-gothic/releases/download/v2.1.0/UDEVGothic_v2.1.0.zip"
    "https://github.com/yuru7/udev-gothic/releases/download/v2.1.0/UDEVGothic_NF_v2.1.0.zip"
)

# ----------

function Install-ZipFont {
    [CmdletBinding(
            DefaultParameterSetName = 'ByName',
            SupportsShouldProcess
    )]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $URI
    )
    begin {
        $guid = (New-Guid).Guid
        $tempPath = Join-Path -Path $HOME -ChildPath "Fonts-$guid"
        if (-not (Test-Path -Path $tempPath -PathType Container)) {
            Write-Verbose "Create folder [$tempPath]"
            $null = New-Item -Path $tempPath -ItemType Directory
        }
    }
    process {
        $itemId = $url.Split("/")[-1]
        $downloadPath = Join-Path -Path $tempPath -ChildPath "$( $itemId ).zip"
        $expandPath = Join-Path -Path $tempPath -ChildPath $itemId

        Invoke-WebRequest -Uri $url -OutFile $downloadPath
        Expand-Archive -Path $downloadPath -Destination $expandPath -Force
        Install-Font -Path $expandPath -Recurse
    }
    end {
        Remove-Item -Path $tempPath -Recurse -Force
    }
}

Install-PSResource -Name GoogleFonts -TrustRepository
Import-Module -Name GoogleFonts

foreach ($font in $googleFontsToInstall) {
    Install-GoogleFont -Name $font
}
foreach ($url in $zipFontsToInstall) {
    Install-ZipFont -URI $url
}
