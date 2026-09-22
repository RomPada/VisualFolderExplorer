@echo off
setlocal
cd /d "%~dp0"

where dotnet >nul 2>nul
if errorlevel 1 (
  echo .NET 8 SDK was not found.
  echo.
  echo This launcher is for development/source builds only.
  echo End users should run a prebuilt self-contained release instead.
  pause
  exit /b 1
)

echo Restoring locally without NuGet.org...
dotnet restore VisualFolderExplorer.csproj --configfile NuGet.Offline.Config --ignore-failed-sources -p:NuGetAudit=false
if errorlevel 1 (
  echo.
  echo Restore failed. Make sure the full .NET 8 SDK with Windows Desktop support is installed.
  pause
  exit /b 1
)

echo Starting Visual Folder Explorer...
dotnet run --project VisualFolderExplorer.csproj --no-restore
if errorlevel 1 pause
