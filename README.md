# Visual Folder Explorer v1.1.1

Visual Folder Explorer is a Windows desktop application for working with folders that contain large image collections together with TXT/Markdown descriptions.

**v1.1.1 is a compatibility patch for local development with the installed .NET 10 SDK. The v1.1.0 bulk-image features are preserved.** It adds true multi-selection, moving selected images with a preflight preview, exact duplicate detection, and safe batch renaming.

## What's new in v1.1.1

- Retargeted the WPF project from `net8.0-windows` to `net10.0-windows` so local offline restore works with the installed .NET 10 SDK.
- Updated local build/publish scripts and GitHub Actions to .NET 10.
- No functional changes to multi-select, selected-image move, duplicate search, move preview, or batch rename.

- **Image multi-select:** use `Ctrl + click`, `Shift + click`, and `Ctrl+A` while the image grid has focus.
- **Move selected:** the Move images dialog can switch between all images in the current folder and only the selected images.
- **Move preview:** every bulk move shows the planned source/destination names, total file count, and how many files will be auto-renamed because of name conflicts before anything is moved.
- **Exact duplicate search:** the Duplicates action first filters by file size, then verifies candidates by SHA-256 content hash. Results are grouped and duplicate copies can be selected back in the image grid.
- **Batch rename:** selected images can be renamed by sequential numbering (`prefix_001`, `prefix_002`, ...) or case-insensitive find/replace. A preview is shown before applying changes, and conflicting target names disable the operation.
- Batch rename uses a two-phase temporary rename strategy so selected files can safely swap or reuse each other's previous names.

### Fast local testing

Because you have the .NET 10 SDK installed, use `StartDev.bat` for day-to-day testing. You only need GitHub Actions when you want a self-contained portable release.

## Requirements

### End users

- Windows 10 or Windows 11 x64.
- Use the **self-contained published build**. It does **not** require the .NET SDK or .NET Desktop Runtime to be installed.

### Developers / build machines

- .NET 10 SDK, or Visual Studio 2022 with the **.NET desktop development** workload.
- For normal local development, `StartDev.bat` uses `NuGet.Offline.Config`; the project has no third-party `PackageReference` dependencies. `NuGet.Config` is kept for CI/self-contained publishing runtime packs.

## Run / publish

### Development

- Open `VisualFolderExplorer.sln` in Visual Studio and press **F5**, or
- run `StartDev.bat` on a machine with the .NET 10 SDK.

`StartDev.bat` restores with the repository's offline-safe `NuGet.Offline.Config`, so a corporate firewall blocking `api.nuget.org` no longer breaks this project when the local SDK contains the required Windows Desktop reference packs.

### End-user build without .NET installed

Run `PublishWin64.bat` on the **developer/build machine**. It creates:

`publish\win-x64-portable\`

Copy the entire folder to the target PC and run `VisualFolderExplorer.exe`. The target PC does **not** need .NET or the SDK installed.

`PublishSingleFileWin64.bat` additionally creates an optional self-contained single-file build. For tightly managed enterprise PCs, the portable self-contained folder is generally preferable because security/IT teams can inspect and allowlist the executable and its runtime files without a self-extracting bundle.

GitHub Actions now publishes both self-contained variants automatically.


## Corporate deployment

Self-contained publishing removes the .NET installation requirement, but it does **not** bypass enterprise security controls. On managed PCs, execution may still be governed by Microsoft Defender, SmartScreen, AppLocker, WDAC, EDR, or organization-specific allowlists.

For legitimate enterprise deployment:

- prefer the self-contained **portable folder** build;
- Authenticode-sign `VisualFolderExplorer.exe` with an organization-trusted code-signing certificate;
- ask IT to allowlist the signed publisher or approved application hash/path according to company policy;
- for broad deployment, package the signed build as MSI/MSIX through the organization's normal software-distribution process.

See `DEPLOYMENT.md` for details.

## Main features

- Explorer panel with folders and `.txt` / `.md` files.
- Image tile browser with sorting by name, modified date, creation date, and size, in ascending or descending order.
- Progressive asynchronous thumbnail loading so large folders remain responsive.
- Persistent thumbnail cache under `%LOCALAPPDATA%\VisualFolderExplorer\thumbcache`.
- Large image preview with 300% zoom and mouse panning.
- Last selected image marker next to the image scrollbar.
- Text editing with save / `Ctrl+S` workflow and unsaved-change confirmation.
- Markdown files open in rendered preview mode and can be switched to source-edit mode.
- Previous/next text-file navigation synchronized with the Explorer selection.
- Copy, cut, paste, rename, create, and delete operations for files/folders.
- Deleted items go to the Windows Recycle Bin.
- Paste conflicts are resolved automatically with `_1`, `_2`, etc.
- Multi-select images with Ctrl/Shift for copy/cut operations.
- Styled image-moving dialog with remembered destination and automatic conflict renaming.
- Custom styled folder picker.
- UA / EN interface switch, remembered between launches.
- Window size/state, last folder, sorting, language, last image, and move destination are persisted in `settings.json`.

## Architecture

The rewrite separates responsibilities instead of keeping everything in one script:

- `MainWindow.xaml/.cs` — main UI and orchestration.
- `Models/` — explorer and image data models.
- `Services/SettingsService.cs` — JSON settings persistence.
- `Services/ThumbnailService.cs` — async thumbnail generation + disk/memory cache.
- `Services/FileService.cs` — clipboard, recycle-bin, copy/move, conflict-safe naming.
- `Services/LocalizationService.cs` — Ukrainian/English UI text.
- `Services/MarkdownService.cs` — basic Markdown rendering.
- `Windows/` — reusable styled dialogs and folder/image-move windows.
- `Resources/Styles.xaml` — the single shared visual-style file for buttons, menus, fields, ComboBoxes, list items, dialogs, and other controls.

## Shared styles

New UI should reuse styles from `Resources/Styles.xaml`. There are also implicit styles for common controls, so new buttons, text fields, ComboBoxes, context menus, menu items, separators, and scrollbars automatically start with the same visual language.

## Large-folder performance

The C# version improves the 200–1000+ image workflow with:

- one directory scan per navigation;
- batched model insertion;
- bounded-concurrency thumbnail loading;
- background decode work;
- 240 px tile thumbnails;
- frozen WPF bitmap sources;
- persistent thumbnail cache;
- cancellation when the user switches folders/sorting before the previous load completes.

The current tile layout still uses a WPF `WrapPanel`; a future release can add true virtualized wrapping for even larger libraries (several thousand images).

## Settings and cache

Settings:

`%LOCALAPPDATA%\VisualFolderExplorer\settings.json`

The C# rewrite keeps the legacy settings property names, so existing PowerShell-era settings can be reused where compatible.

Thumbnail cache:

`%LOCALAPPDATA%\VisualFolderExplorer\thumbcache`

## Supported image formats

JPG, JPEG, PNG, BMP, GIF, TIFF/TIF and WEBP when the Windows/WPF codec can decode it.

## Versioning

Semantic Versioning is used:

- PATCH — fixes and small compatible changes;
- MINOR — backward-compatible features;
- MAJOR — major/breaking changes or architecture migrations.

The PowerShell → C# rewrite was released as **v1.0.0**. The current source target is **.NET 10 WPF** as of **v1.1.1**.

## GitHub Actions artifact

GitHub Actions now uploads the **published portable folder directly as the artifact**. GitHub creates the single downloadable ZIP itself, so the user extracts only once. The archive contains `VisualFolderExplorer.exe`, the self-contained runtime files, and `BUILD_INFO.txt` with the EXE SHA-256 hash. There is no nested ZIP.
