# Visual Folder Explorer v0.11.0

Visual Folder Explorer is a lightweight Windows desktop application for browsing folders that contain many images together with TXT or Markdown notes. It is designed for a workflow where images are shown as thumbnails while the related text remains available in the same window.

> Ukrainian documentation: see `README_UA.md`.
> Release history: see `PATCHLIST.md`.

## Requirements

- Windows 10 or Windows 11
- Windows PowerShell 5.1
- .NET Framework / WPF available in Windows
- No Python, Node.js, or third-party runtime is required

## Start

1. Extract the entire `VisualFolderExplorer_v0.11.0` folder.
2. Double-click `Start Visual Folder Explorer.bat`.
3. On first launch, choose the root folder with your materials.
4. On later launches, the application restores the last opened folder and saved window state.

## Main layout

- **Explorer** — folders plus TXT/MD files in the current location.
- **Images** — image thumbnails with sorting and file operations.
- **Text / Preview** — TXT/Markdown content or the selected image preview.

## Explorer

- Double-click a folder to open it.
- Click a `.txt` or `.md` file to open it in the right panel.
- Right-click folders or text files for file operations.
- Right-click empty space to paste items, create a folder, create a TXT file, or create a Markdown file.
- Cut/copy/paste works with the Windows clipboard.
- Name conflicts during paste are resolved automatically using suffixes such as `_1`, `_2`, and so on.
- Deleted files and folders are sent to the Windows Recycle Bin.

## Images

Supported formats: JPG, JPEG, PNG, BMP, GIF, TIFF/TIF, and WEBP when the required WPF codec is available.

- Images are shown as thumbnails.
- Sort by name, modification date, creation date, or file size.
- Use ascending or descending order.
- The chosen sorting mode is remembered between launches.
- Click an image to open it in the right preview panel.
- The image currently open in preview is strongly highlighted.
- After returning to text, the last selected image remains softly highlighted.
- A marker on the image scrollbar shows approximately where the selected image is located in a large folder.
- Right-click an image for cut, copy, rename, or delete.
- Right-click empty space in the Images area to paste clipboard items into the current folder.

### Preview zoom

- Click the preview to zoom to **300%**.
- While zoomed, hold the left mouse button and drag to pan around the image.
- Click without dragging to return to 100%.

## TXT and Markdown

- TXT files open in the text editor.
- Markdown files open in rendered Markdown mode by default.
- Use **Edit** to show Markdown source and **Preview** to return to formatted view.
- Save with the **Save** button or `Ctrl+S`.
- Use the left/right arrows below the text panel to switch between text files.
- The corresponding file is also selected in Explorer when switching with the arrows.


## Move images

A **Move images** button is located between **Choose folder** and the UA/EN language selector. It opens a styled drop-down panel:

- **From** defaults to the folder currently open in Visual Folder Explorer.
- **To** restores the last successful destination; it is empty until a destination has been used.
- Browse buttons can be used for both paths.
- Supported image files in the source folder are moved without scanning subfolders.
- Original filenames are preserved. If the destination already contains the same name, the moved file is renamed automatically using `_1`, `_2`, and so on.
- The last successful destination is saved in `settings.json`.

## Shared UI styles

All reusable UI styling is centralized in `Styles.xaml`. New buttons, context menus, combo boxes, text fields, dialogs, popups, and scrollbars should use these shared styles so new features match the rest of the application automatically.

## Interface languages

Use the **UA / EN** drop-down in the top-right corner to switch the entire interface between Ukrainian and English. The selected language is remembered between launches. Context menus, file-operation dialogs, unsaved-change prompts, sorting controls, and main navigation labels follow the selected language.

## Performance

Version 0.9.x is optimized for folders containing hundreds or even 1000+ images:

- progressive thumbnail loading keeps the window responsive;
- thumbnail decode size is reduced to lower memory and CPU usage;
- image context menus are created only when needed;
- repeated full-tile selection refreshes during loading were removed;
- folder contents are enumerated once per navigation and reused across panels;
- large image collections are processed in smaller batches.

## Saved settings

Application state is stored in:

```text
%LOCALAPPDATA%\VisualFolderExplorer\settings.json
```

The application remembers the last folder, navigation history, window size/state, image sorting preferences, selected interface language, and the last image-move destination.

## Project files

- `VisualFolderExplorer.ps1` — application code
- `Styles.xaml` — shared visual styles for buttons, menus, fields, popups, dialogs, and scrollbars
- `Start Visual Folder Explorer.bat` — launcher
- `README.md` — primary English documentation
- `README_UA.md` — Ukrainian documentation
- `PATCHLIST.md` — bilingual release history

## Versioning

The project uses Semantic Versioning-style release numbers:

- PATCH: fixes and small non-breaking changes, e.g. `v0.10.0 → v0.10.1`
- MINOR: new backward-compatible features, e.g. `v0.10.1 → v0.11.0`
- MAJOR: major or breaking releases, e.g. `v0.x.x → v1.0.0`
