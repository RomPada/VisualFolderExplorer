# Visual Folder Explorer v1.6.0

Visual Folder Explorer is a Windows desktop application for working with folders that contain large image collections together with TXT/Markdown descriptions.

**v1.6.0 adds selective descriptive-metadata cleanup for images and videos.** The operation previews Windows File Properties → Details values and backs up each original before attempting to clear only Title, Subject, Comments and/or Authors. It never invokes a video/image encoder.



## What's new in v1.6.0

- Added **Clean metadata** in the Image actions toolbar. It operates on selected image tiles or all supported files in the current directory, including videos not displayed as image tiles.
- Scans the four Windows Shell properties `System.Title`, `System.Subject`, `System.Comment` and `System.Author` for `.jpg`, `.jpeg`, `.png`, `.mp4`, `.m4v` and `.mov`. Read/write availability is determined by the Windows metadata handler installed for that file and codec.
- Displays a per-file preview of the current values and expected cleared values (`before → after`). File and property selections are independent.
- Creates mandatory per-operation backups in `<current folder>/_VFE_MetadataBackups/<timestamp>_<id>/` and checks SHA-256 of each original vs. its backup before changing anything.
- Uses the native Windows `IPropertyStore` handler with `VT_EMPTY` and `Commit`, so no decoding/re-encoding of the picture/video stream is requested. For JPEG/PNG, decoded pixel hashes are compared before/after; a separate property-store read verifies that the selected values are empty afterwards.
- If a property handler rejects writing, or verification fails, the original bytes are restored from backup. Individual file results report failures; unsupported formats are never modified.
- Retains original filesystem creation and modification times where the OS allows. Successful rows are scanned again, so the preview shows the actual updated values.
- Provides progress, confirmation, UA/EN labels, an **Open backup folder** control and a `restore-map.json` mapping in each backup folder to aid manual restoration.

**Important limitations:** This is a targeted cleanup of four *Windows Shell properties*, **not** an exhaustive scrub of EXIF, XMP, location, device identifiers, hidden application tags or all container metadata. MP4/MOV handlers on some Windows systems are read-only and may report a failed/unsupported edit. No media transcoding is requested, but the exact storage implementation is controlled by the Windows property handler; for irreplaceable originals, test one file first and retain the backup. Backups themselves still contain the original metadata.

## What's new in v1.5.2

- The `...` **parent-folder** control is now pinned directly under the Explorer heading, outside its scrolling file list. It stays visible while you scroll hundreds of folders and TXT/MD entries.
- One click on the pinned `...` goes one directory up. Drag & Drop onto the pinned control still targets the parent directory. The control stays visible but is disabled at a filesystem root.
- Rename dialogs for files select only the filename stem. For example, `text.txt` opens with only `text` selected, leaving `.txt` unchanged by default. Folder renames and new-file dialogs continue to select their entire text.
- At v1.5.2 no metadata was removed. The confirmed backup-aware operation was added in v1.6.0.

## What's new in v1.5.1

- Moving the similarity-threshold slider now updates only the percentage while the mouse is held down; group rebuilding starts only when the thumb is released. This keeps the slider responsive in folders with hundreds or thousands of images.
- Keyboard threshold changes are applied after the navigation key is released as well.
- Explorer now always starts with a `...` parent-navigation item above folders/text files. Double-click it to go one directory up.
- The `...` item has a safe context menu with only the **Up one level** action; rename/delete/cut operations are never offered for it.
- Dragging files onto `...` targets the parent folder.

## What's new in v1.5.0

- Added **Group by similarity** to the Image actions bar.
- Similarity analysis is fully local and uses a 63-bit perceptual hash (low-frequency DCT / pHash-style comparison), not SHA-256.
- The existing **Duplicates** command remains separate and continues to identify byte-identical files; similarity grouping is intended for visually related images, including resized or recompressed variants.
- Added a remembered **Similarity threshold** slider. Higher values are stricter; lower values create broader visual groups.
- Hashes are calculated once per analysis. Moving the threshold slider immediately rebuilds groups without decoding every source image again.
- Added group preview with thumbnails, average similarity, group/file counts, and per-image checkboxes. Unchecked images stay in the current folder.
- Nothing is moved until **Create folders and organize** is confirmed.
- Output folders use `Similar_001`, `Similar_002`, ... by default; the prefix is editable. Existing folder names are skipped safely.
- Filename conflicts inside generated folders still use the existing `_1`, `_2`, ... protection.
- Images that do not belong to a group are left untouched.
- Large folders are analyzed in parallel with visible progress and unreadable-file count.
- The folder watcher is paused while the similarity dialog is open so bulk organization does not trigger repeated background refreshes.

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
- Large image preview with 300% zoom and mouse panning; metadata is shown in the Preview header and hidden while zoomed.
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
- Window size/state, pane layout, last folder, sorting, language, last image, scroll position, and move destination are persisted in `settings.json`.

- Visual similarity grouping with local perceptual hashing, adjustable threshold, preview, exclusion controls, and safe folder creation.
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

The PowerShell → C# rewrite was released as **v1.0.0**. The current source target is **.NET 10 WPF** as of **v1.1.1**; v1.2.1 uses WPF `Microsoft.Win32.OpenFolderDialog` for native folder selection; Windows Forms is no longer enabled.

## GitHub Actions artifact

GitHub Actions now uploads the **published portable folder directly as the artifact**. GitHub creates the single downloadable ZIP itself, so the user extracts only once. The archive contains `VisualFolderExplorer.exe`, the self-contained runtime files, and `BUILD_INFO.txt` with the EXE SHA-256 hash. There is no nested ZIP.
