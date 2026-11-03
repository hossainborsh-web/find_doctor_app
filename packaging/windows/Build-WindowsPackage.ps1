$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$releaseRoot = Join-Path $projectRoot 'build\windows\x64\runner\Release'
$buildRoot = Join-Path $projectRoot 'build'
$packageRoot = Join-Path $buildRoot 'FindDoctor-Windows-Installer'
$appBundle = Join-Path $packageRoot 'FindDoctor'
$archivePath = Join-Path $buildRoot 'FindDoctor-Windows.zip'

if (-not (Test-Path -LiteralPath (Join-Path $releaseRoot 'FindDoctor.exe') -PathType Leaf)) {
    throw "FindDoctor.exe was not found in '$releaseRoot'. Build the Windows release first with 'flutter build windows --release'."
}
if (Test-Path -LiteralPath $packageRoot) {
    throw "The packaging folder already exists at '$packageRoot'. Move or remove that generated folder before packaging again."
}
if (Test-Path -LiteralPath $archivePath) {
    throw "The output archive already exists at '$archivePath'. Move or remove the old archive before packaging again."
}

New-Item -ItemType Directory -Path $appBundle -Force | Out-Null
Copy-Item -Path (Join-Path $releaseRoot '*') -Destination $appBundle -Recurse -Force -Exclude '*.lib', '*.exp'
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Install-FindDoctor.cmd') -Destination $packageRoot
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Install-FindDoctor.ps1') -Destination $packageRoot

@'
Find Doctor for Windows

1. Extract the complete FindDoctor-Windows.zip.
2. Run Install-FindDoctor.cmd.
3. Open Find Doctor from the Start menu or desktop shortcut.

The app installs for your Windows account and does not require administrator access.
To remove it, open Windows Settings > Apps > Installed apps and uninstall Find Doctor.
'@ | Set-Content -LiteralPath (Join-Path $packageRoot 'README-Install.txt') -Encoding UTF8

Compress-Archive -Path (Join-Path $packageRoot '*') -DestinationPath $archivePath -CompressionLevel Optimal
Write-Host "Windows installation package created: $archivePath"
