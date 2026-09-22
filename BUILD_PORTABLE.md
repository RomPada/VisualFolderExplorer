# Build the portable EXE

The final portable package is built on a Windows GitHub Actions runner.

1. Push this repository to GitHub.
2. Open **Actions → build-windows-portable → Run workflow**.
3. When the run finishes, download the artifact **VisualFolderExplorer_v1.0.2_win-x64-portable**.
4. Inside it is `VisualFolderExplorer_v1.0.2_win-x64-portable.zip`.
5. Extract it on any Windows 10/11 x64 PC and run `VisualFolderExplorer.exe`.

The target PC does not need .NET SDK, .NET Runtime, Visual Studio, or NuGet access.
