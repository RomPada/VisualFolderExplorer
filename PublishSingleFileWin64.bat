@echo off
setlocal
cd /d "%~dp0"

where dotnet >nul 2>nul
if errorlevel 1 (
  echo .NET 8 SDK was not found.
  echo This script runs only on the developer/build machine.
  pause
  exit /b 1
)

set OUT=publish\win-x64-single
if exist "%OUT%" rmdir /s /q "%OUT%"

echo Restoring Windows x64 runtime assets locally...
dotnet restore VisualFolderExplorer.csproj -r win-x64 --configfile NuGet.Config --ignore-failed-sources -p:NuGetAudit=false
if errorlevel 1 goto :fail

echo Publishing self-contained single-file Windows x64 build...
dotnet publish VisualFolderExplorer.csproj -c Release -r win-x64 --self-contained true --no-restore ^
  -p:PublishSingleFile=true ^
  -p:IncludeNativeLibrariesForSelfExtract=true ^
  -p:EnableCompressionInSingleFile=true ^
  -p:DebugType=None ^
  -p:DebugSymbols=false ^
  -p:NuGetAudit=false ^
  -o "%OUT%"
if errorlevel 1 goto :fail

echo.
echo DONE.
echo Single-file output:
echo   %CD%\%OUT%
echo No .NET installation is required on the target PC.
echo NOTE: on tightly controlled corporate PCs the portable folder build is usually easier for IT to inspect/allowlist.
pause
exit /b 0

:fail
echo.
echo Publish failed.
pause
exit /b 1
