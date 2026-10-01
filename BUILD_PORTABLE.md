# Build the portable EXE

The final portable package is built on a Windows GitHub Actions runner.

1. Push this repository to GitHub.
2. Open **Actions → build-windows-portable → Run workflow**.
3. When the run finishes, download the artifact **VisualFolderExplorer_v1.4.0_win-x64-portable**.
4. GitHub downloads the artifact as one ZIP. Extract it once.
5. Inside the extracted folder, run `VisualFolderExplorer.exe`.

The target PC does not need .NET SDK, .NET Runtime, Visual Studio, or NuGet access.
