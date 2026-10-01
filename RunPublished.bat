@echo off
setlocal
cd /d "%~dp0"
set EXE=publish\win-x64-portable\VisualFolderExplorer.exe
if not exist "%EXE%" (
  echo Prebuilt portable application was not found:
  echo   %CD%\%EXE%
  echo.
  echo Build it on a developer PC with PublishWin64.bat,
  echo or download the self-contained artifact produced by GitHub Actions.
  pause
  exit /b 1
)
start "" "%EXE%"
