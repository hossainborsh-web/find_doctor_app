@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-FindDoctor.ps1"
if errorlevel 1 (
  echo Find Doctor could not be installed. Review the message above and try again.
  pause
)
endlocal
