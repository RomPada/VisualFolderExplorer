@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0VisualFolderExplorer.ps1"
if errorlevel 1 (
  echo.
  echo Visual Folder Explorer could not be started.
  echo Press any key to close this window.
  pause >nul
)
endlocal
