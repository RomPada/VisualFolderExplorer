@echo off
setlocal
cd /d "%~dp0"

where dotnet >nul 2>nul
if errorlevel 1 (
  echo .NET 8 SDK was not found.
  echo This script runs only on the developer/build machine.
  echo The published application will NOT require .NET or the SDK on the target PC.
  pause
  exit /b 1
)

set OUT=publish\win-x64-portable
if exist "%OUT%" rmdir /s /q "%OUT%"

echo Restoring Windows x64 runtime assets locally...
dotnet restore VisualFolderExplorer.csproj -r win-x64 --configfile NuGet.Config --ignore-failed-sources -p:NuGetAudit=false
if errorlevel 1 goto :fail

echo Publishing self-contained Windows x64 folder...
dotnet publish VisualFolderExplorer.csproj -c Release -r win-x64 --self-contained true --no-restore ^
  -p:PublishSingleFile=false ^
  -p:DebugType=None ^
  -p:DebugSymbols=false ^
  -p:NuGetAudit=false ^
  -o "%OUT%"
if errorlevel 1 goto :fail

echo.
echo DONE.
echo Copy the entire folder below to another Windows 10/11 x64 PC:
echo   %CD%\%OUT%
echo Run VisualFolderExplorer.exe there. No .NET SDK or .NET Runtime installation is required.
pause
exit /b 0

:fail
echo.
echo Publish failed.
echo If the SDK was installed without Windows Desktop targeting/runtime packs, repair the .NET 8 SDK on the BUILD PC.
echo The target/end-user PC still does not need any SDK or runtime installation.
pause
exit /b 1
