param(
    [ValidateSet('Install', 'Uninstall')]
    [string]$Mode = 'Install'
)

$ErrorActionPreference = 'Stop'
$appName = 'Find Doctor'
$installRoot = Join-Path $env:LOCALAPPDATA 'Programs\Find Doctor'
$startMenuRoot = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
$startMenuLink = Join-Path $startMenuRoot 'Find Doctor.lnk'
$desktopLink = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Find Doctor.lnk'
$uninstallKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\FindDoctor'

if ($Mode -eq 'Uninstall') {
    Get-Process -Name 'FindDoctor' -ErrorAction SilentlyContinue | Stop-Process -Force
    Remove-Item -LiteralPath $startMenuLink -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $desktopLink -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $uninstallKey -Recurse -Force -ErrorAction SilentlyContinue
    $quotedRoot = $installRoot.Replace('"', '""')
    Start-Process -FilePath $env:ComSpec -WindowStyle Hidden -ArgumentList @(
        '/c', "timeout /t 2 /nobreak >nul & rmdir /s /q `"$quotedRoot`""
    )
    exit 0
}

$sourceRoot = Join-Path $PSScriptRoot 'FindDoctor'
$sourceExecutable = Join-Path $sourceRoot 'FindDoctor.exe'
if (-not (Test-Path -LiteralPath $sourceExecutable -PathType Leaf)) {
    throw "The Windows app bundle was not found at '$sourceRoot'. Extract the complete installer package and run Install-FindDoctor.cmd again."
}

# Version comes from FindDoctor.exe itself (set from pubspec.yaml at build time).
$version = (Get-Item -LiteralPath $sourceExecutable).VersionInfo.ProductVersion
if ([string]::IsNullOrWhiteSpace($version)) { $version = '1.0.0' }
$version = ($version -split '\+')[0]

New-Item -ItemType Directory -Path $installRoot -Force | Out-Null
Copy-Item -Path (Join-Path $sourceRoot '*') -Destination $installRoot -Recurse -Force

$shell = New-Object -ComObject WScript.Shell
foreach ($linkPath in @($startMenuLink, $desktopLink)) {
    $link = $shell.CreateShortcut($linkPath)
    $link.TargetPath = Join-Path $installRoot 'FindDoctor.exe'
    $link.WorkingDirectory = $installRoot
    $link.Description = 'Find Doctor medical application'
    $link.IconLocation = "$($link.TargetPath),0"
    $link.Save()
}

$uninstallScript = Join-Path $installRoot 'Install-FindDoctor.ps1'
Copy-Item -LiteralPath $PSCommandPath -Destination $uninstallScript -Force
$uninstallCommand = "powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$uninstallScript`" -Mode Uninstall"
New-Item -Path $uninstallKey -Force | Out-Null
New-ItemProperty -Path $uninstallKey -Name 'DisplayName' -Value $appName -PropertyType String -Force | Out-Null
New-ItemProperty -Path $uninstallKey -Name 'DisplayVersion' -Value $version -PropertyType String -Force | Out-Null
New-ItemProperty -Path $uninstallKey -Name 'Publisher' -Value 'Find Doctor' -PropertyType String -Force | Out-Null
New-ItemProperty -Path $uninstallKey -Name 'InstallLocation' -Value $installRoot -PropertyType String -Force | Out-Null
New-ItemProperty -Path $uninstallKey -Name 'DisplayIcon' -Value "$(Join-Path $installRoot 'FindDoctor.exe'),0" -PropertyType String -Force | Out-Null
New-ItemProperty -Path $uninstallKey -Name 'NoModify' -Value 1 -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path $uninstallKey -Name 'NoRepair' -Value 1 -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path $uninstallKey -Name 'UninstallString' -Value $uninstallCommand -PropertyType String -Force | Out-Null

Write-Host 'Find Doctor is installed.'
Write-Host "Open it from the Start menu or desktop shortcut. Install location: $installRoot"
