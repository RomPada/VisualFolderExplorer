@echo off
setlocal
cd /d "%~dp0"

where dotnet >nul 2>nul
if errorlevel 1 (
  echo .NET 8 SDK was not found.
  echo This script is only for developers/build machines.
  pause
  exit /b 1
)

echo Restoring locally without NuGet.org...
dotnet restore VisualFolderExplorer.csproj --configfile NuGet.Offline.Config --ignore-failed-sources -p:NuGetAudit=false
if errorlevel 1 goto :fail

echo Building Release...
dotnet build VisualFolderExplorer.csproj -c Release --no-restore -p:NuGetAudit=false
if errorlevel 1 goto :fail

echo.
echo Release build completed.
pause
exit /b 0

:fail
echo.
echo The build failed. Fix the build errors and run again.
pause
exit /b 1
