# Visual Folder Explorer v1.0.3

Visual Folder Explorer is a Windows desktop application for working with folders that contain large image collections together with TXT/Markdown descriptions.

**v1.0.3 is the first deployment/hardening patch after the C#/.NET 8 WPF rewrite.** The goal of the rewrite is better performance, maintainability, asynchronous image loading, thumbnail caching, and a cleaner foundation for future features.

## Requirements

### End users

- Windows 10 or Windows 11 x64.
- Use the **self-contained published build**. It does **not** require the .NET SDK or .NET Desktop Runtime to be installed.

### Developers / build machines

- .NET 8 SDK, or Visual Studio 2022 with the **.NET desktop development** workload.
- Internet access is not required for this project itself because it has no third-party `PackageReference` dependencies. `NuGet.Config` clears external package sources and NuGet audit is disabled for local restore.

## Run / publish

### Development

- Open `VisualFolderExplorer.sln` in Visual Studio and press **F5**, or
- run `StartDev.bat` on a machine with the .NET 8 SDK.

`StartDev.bat` now restores with the repository's offline-safe `NuGet.Config`, so a corporate firewall blocking `api.nuget.org` no longer breaks this project when the local SDK contains the required Windows Desktop reference packs.

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

The PowerShell → C# rewrite was released as **v1.0.0**. Deployment/offline-restore fixes are released as **v1.0.3**.
