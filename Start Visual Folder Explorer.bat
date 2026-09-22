@echo off
setlocal
cd /d "%~dp0"
title Visual Folder Explorer v0.9.1

rem Run the PowerShell code from memory instead of using -File.
rem This avoids execution-policy errors for unsigned downloaded .ps1 files.
powershell.exe -NoLogo -NoProfile -STA -Command "$ErrorActionPreference='Stop'; $p = Join-Path (Get-Location) 'VisualFolderExplorer.ps1'; $code = [System.IO.File]::ReadAllText($p); & ([ScriptBlock]::Create($code))"

if errorlevel 1 (
  echo.
  echo Visual Folder Explorer v0.9.1 could not be started.
  echo.
  echo If Windows blocked the downloaded ZIP, right-click the ZIP or extracted files,
  echo choose Properties, check Unblock if it is shown, then extract/run again.
  echo.
  echo Press any key to close this window.
  pause >nul
)
endlocal
