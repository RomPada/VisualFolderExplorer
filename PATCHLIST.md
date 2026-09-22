# Visual Folder Explorer — Patch List / Список змін

This file is maintained for every release in English and Ukrainian.  
Цей файл оновлюється для кожної версії англійською та українською мовами.

---

## v1.0.4 — 2026-09-22

**English**
- Fixed portable artifact packaging: GitHub Actions now uploads the published folder directly instead of putting a portable ZIP inside the GitHub artifact ZIP.
- This removes the nested-ZIP extraction path that could trigger misleading password prompts in Windows Explorer.
- Added `BUILD_INFO.txt` with the SHA-256 hash of `VisualFolderExplorer.exe`.
- The artifact is now downloaded and extracted only once.

**Українська**
- Виправлено пакування portable-збірки: GitHub Actions тепер завантажує готову папку publish напряму, без вкладеного portable ZIP усередині ZIP-артефакту GitHub.
- Це прибирає сценарій ZIP-в-ZIP, через який Провідник Windows міг показувати помилковий запит пароля під час розпакування.
- Додано `BUILD_INFO.txt` із SHA-256 хешем `VisualFolderExplorer.exe`.
- Артефакт тепер потрібно завантажити та розпакувати лише один раз.

## v1.0.3 — 2026-09-22

**English**
- Fixed GitHub Actions WPF compilation errors `CS0246` for `FileSystemInfo` / `FileInfo`.
- Added source-level `GlobalUsings.cs` and explicit `System.IO` imports so WPF's temporary markup compilation project does not depend on generated implicit usings.
- Added explicit common framework usings to IO-heavy code-behind/services for more deterministic CI compilation.
- GitHub Actions now runs on pushes from any branch, not only `main` / `master`.
- Updated portable artifact naming to `VisualFolderExplorer_v1.0.3_win-x64-portable`.

**Українська**
- Виправлено помилки компіляції GitHub Actions `CS0246` для `FileSystemInfo` / `FileInfo`.
- Додано вихідний `GlobalUsings.cs` та явні імпорти `System.IO`, щоб тимчасовий WPF-проєкт компіляції XAML не залежав від автоматично згенерованих implicit usings.
- До IO-залежних code-behind/сервісів додано явні стандартні using для стабільнішої CI-збірки.
- GitHub Actions тепер запускається при push у будь-яку гілку, а не лише `main` / `master`.
- Назву portable artifact оновлено до `VisualFolderExplorer_v1.0.3_win-x64-portable`.

## v1.0.2 — 2026-09-22

**English**
- Fixed the build pipeline for self-contained Windows x64 publishing.
- Split NuGet configuration into `NuGet.Offline.Config` for local corporate/offline development and `NuGet.Config` for CI/publishing runtime packs.
- GitHub Actions now creates a ready-to-download `VisualFolderExplorer_v1.0.2_win-x64-portable.zip` containing `VisualFolderExplorer.exe` and all required .NET runtime files.
- The portable package requires no .NET SDK or .NET Desktop Runtime on the target Windows 10/11 x64 PC.

**Українська**
- Виправлено pipeline збірки self-contained Windows x64 версії.
- NuGet-конфігурацію розділено на `NuGet.Offline.Config` для локальної/корпоративної розробки без інтернету та `NuGet.Config` для CI/publish runtime-пакетів.
- GitHub Actions тепер формує готовий `VisualFolderExplorer_v1.0.2_win-x64-portable.zip` з `VisualFolderExplorer.exe` та всіма необхідними файлами .NET runtime.
- На цільовому Windows 10/11 x64 ПК не потрібно встановлювати .NET SDK або .NET Desktop Runtime.

## v1.0.1 — 2026-09-22

**English**
- Fixed corporate/offline source builds that failed with `NU1301` when `api.nuget.org` was blocked.
- Added repository `NuGet.Config` with external sources cleared; the project has no third-party NuGet package dependencies.
- Disabled NuGet vulnerability audit for local restore/build to prevent unnecessary network calls.
- Updated `StartDev.bat` and `BuildRelease.bat` to perform offline-safe restore and then build/run with `--no-restore`.
- Changed `PublishWin64.bat` to create a **self-contained Windows x64 portable folder** that requires no .NET runtime/SDK on the target PC.
- Added optional `PublishSingleFileWin64.bat` and `RunPublished.bat`.
- Updated GitHub Actions to publish both self-contained portable-folder and single-file artifacts.
- Added corporate deployment guidance covering code signing and legitimate IT allowlisting.

**Українська**
- Виправлено збірку з вихідного коду в корпоративних/offline-мережах, де блокування `api.nuget.org` спричиняло `NU1301`.
- Додано локальний `NuGet.Config` з очищеними зовнішніми sources; у проєкті немає сторонніх NuGet-залежностей.
- Вимкнено NuGet vulnerability audit для локального restore/build, щоб прибрати зайві мережеві звернення.
- `StartDev.bat` і `BuildRelease.bat` тепер роблять offline-safe restore, після чого запускають build/run з `--no-restore`.
- `PublishWin64.bat` тепер створює **self-contained portable Windows x64 папку**, яка не потребує .NET runtime/SDK на цільовому ПК.
- Додано `PublishSingleFileWin64.bat` та `RunPublished.bat`.
- GitHub Actions тепер створює обидва self-contained artifacts: portable folder і single-file.
- Додано рекомендації для корпоративного розгортання через code signing та офіційний IT allowlisting.

## v1.0.0 — 2026-09-22

**English**
- Full architecture migration from PowerShell/WPF to C#/.NET 8 WPF.
- Split the application into models, services, reusable windows, XAML resources, and main-window orchestration.
- Added asynchronous thumbnail loading with bounded concurrency and cancellation.
- Added persistent disk + memory thumbnail caching.
- Preserved explorer, text/Markdown workflow, image preview, 300% zoom/pan, sorting, clipboard operations, Recycle Bin deletion, auto-rename conflicts, UA/EN localization, remembered settings, custom folder picker, image mover, and selected-image scrollbar marker.
- Added multi-select image copy/cut support.
- Added Visual Studio solution, Release build script, development launcher, Win64 publish script, and GitHub Actions Windows build workflow.
- Centralized shared C# WPF styles in `Resources/Styles.xaml`.

**Українська**
- Повністю перенесено архітектуру з PowerShell/WPF на C#/.NET 8 WPF.
- Код розділено на моделі, сервіси, повторно використовувані вікна, XAML-ресурси та логіку головного вікна.
- Додано асинхронне завантаження thumbnail із контрольованою паралельністю та скасуванням попереднього завантаження.
- Додано постійний дисковий і оперативний кеш мініатюр.
- Збережено Провідник, роботу з TXT/Markdown, прев'ю, zoom 300% і pan, сортування, clipboard, видалення до Кошика, автоперейменування конфліктів, UA/EN, збереження налаштувань, власний вибір папки, перенесення картинок і маркер вибраного зображення на скролбарі.
- Додано мультивибір картинок для копіювання/вирізання.
- Додано Visual Studio solution, Release build script, dev launcher, Win64 publish script і GitHub Actions workflow для Windows-збірки.
- Спільні стилі C# WPF винесено в `Resources/Styles.xaml`.

## v0.11.1 — 2026-09-22

**English**
- Fixed path-field vertical clipping in the image mover.
- Kept the mover open while selecting folders.
- Replaced the legacy system folder browser with a styled bilingual WPF folder picker.

**Українська**
- Виправлено обрізання тексту в полях шляхів меню перенесення.
- Панель перенесення більше не закривалася під час вибору папки.
- Системний Folder Browser замінено на стилізований двомовний WPF-вибір папки.

## v0.11.0 — 2026-09-22

**English**
- Added shared `Styles.xaml`.
- Added the image mover between Choose folder and UA/EN.
- Added remembered destination and `_1`, `_2` conflict renaming.

**Українська**
- Додано спільний `Styles.xaml`.
- Додано меню перенесення зображень між «Обрати папку» та UA/EN.
- Додано запам'ятовування призначення та перейменування `_1`, `_2` при конфліктах.

## v0.10.0 — 2026-09-22

**English**
- Added persistent UA/EN localization.
- Replaced default text context menu and unsaved-changes MessageBox with styled application dialogs.
- Standardized README/PATCHLIST workflow.

**Українська**
- Додано постійне перемикання UA/EN.
- Стандартне меню тексту й системне попередження про незбережені зміни замінено стилізованими елементами програми.
- Стандартизовано README/PATCHLIST.

## v0.9.1 — 2026-09-22

**English**
- Added English `README.md`, Ukrainian `README_UA.md`, and bilingual `PATCHLIST.md`.

**Українська**
- Додано англійський `README.md`, український `README_UA.md` і двомовний `PATCHLIST.md`.

## v0.9.0 — 2026-09-22

**English**
- Major performance pass for 200–1000 image folders.
- Added progressive batched thumbnails, smaller decode size, shared directory scan, and lazy image context menus.

**Українська**
- Значна оптимізація папок із 200–1000 зображень.
- Додано пакетне завантаження прев'ю, менший decode size, спільне сканування папки й ліниве створення контекстних меню.

## v0.8.2 — 2026-09-22

**English**
- Reworked selected-image scrollbar marker alignment using the real scrollbar thumb.

**Українська**
- Вирівнювання маркера вибраної картинки перероблено відносно реального thumb скролбара.

## v0.8.1 — 2026-09-22

**English**
- Visual adjustment of the selected-image scrollbar marker.

**Українська**
- Візуально скориговано маркер вибраної картинки на скролбарі.

## v0.8.0 — 2026-09-22

**English**
- Added automatic `_1`, `_2` naming for paste conflicts.
- Synced text-arrow navigation with Explorer selection.
- Added a persistent selected-image level marker near the image scrollbar.

**Українська**
- Додано автоматичні `_1`, `_2` при конфліктах вставлення.
- Стрілки текстових файлів синхронізовано з вибором у Провіднику.
- Додано постійний маркер рівня вибраної картинки біля скролбара.

## v0.7.2 — 2026-09-22

**English**
- Fixed remaining WPF `StaticResource` startup error.

**Українська**
- Виправлено залишкову помилку запуску WPF `StaticResource`.

## v0.7.1 — 2026-09-22

**English**
- Fixed XAML startup error introduced by custom scrollbar styling.

**Українська**
- Виправлено XAML-помилку запуску, пов'язану зі стилізацією скролбара.

## v0.7.0 — 2026-09-22

**English**
- Styled rename/delete dialogs and buttons.
- Added paste on empty image-panel area.
- Added custom scrollbar visual styling.

**Українська**
- Стилізовано діалоги перейменування/видалення та кнопки.
- Додано вставлення по порожньому місцю блока «Зображення».
- Додано власне оформлення скролбара.

## v0.6.2 — 2026-09-22

**English**
- Styled right-click context menus and image-sort dropdowns.

**Українська**
- Стилізовано контекстні меню та dropdown сортування зображень.

## v0.6.1 — 2026-09-22

**English**
- Replaced old system rename/create input boxes with styled WPF dialogs.

**Українська**
- Старі системні InputBox для створення/перейменування замінено стилізованими WPF-діалогами.

## v0.6.0 — 2026-09-22

**English**
- Renamed the left block to Explorer.
- Added image sorting by name/date/size and ascending/descending direction.
- Added create/cut/copy/rename/delete folder operations.

**Українська**
- Лівий блок перейменовано на «Провідник».
- Додано сортування зображень за назвою/датою/розміром та прямим/зворотним порядком.
- Додано створення, вирізання, копіювання, перейменування та видалення папок.

## v0.5.0 — 2026-09-22

**English**
- Increased image preview zoom to 300%.
- Added active/last-image tile highlighting.
- Added rendered Markdown view with edit/preview switching.

**Українська**
- Zoom прев'ю збільшено до 300%.
- Додано активне/м'яке виділення вибраної картинки.
- Додано відформатований Markdown та перемикання редагування/перегляду.

## v0.4.1 — 2026-09-22

**English**
- Remembered window size and maximized state.

**Українська**
- Додано запам'ятовування розміру та розгорнутого стану вікна.

## v0.4.0 — 2026-09-22

**English**
- Added 200% preview pan.
- Added paste from Windows clipboard / Ctrl+V.
- Improved text filename visibility and one-click text opening.

**Українська**
- Додано перетягування збільшеного до 200% прев'ю.
- Додано вставлення з Windows clipboard / Ctrl+V.
- Покращено відображення назви текстового файла та відкриття одним кліком.

## v0.3.1 — 2026-09-22

**English**
- Fixed PowerShell parse error caused by typographic apostrophes.

**Українська**
- Виправлено PowerShell ParseException через типографічні апострофи.

## v0.3.0 — 2026-09-22

**English**
- Added image zoom, image/text context menus, text files in Explorer, create TXT/MD, and Recycle Bin deletion.

**Українська**
- Додано zoom, контекстні меню зображень/тексту, текстові файли в Провіднику, створення TXT/MD і видалення до Кошика.

## v0.2.0 — legacy PowerShell branch

**English**
- Added TXT/MD editing and save workflow, text-file navigation, image preview in the right panel, last-folder memory, and navigation history.

**Українська**
- Додано редагування/збереження TXT/MD, навігацію між текстовими файлами, прев'ю праворуч, пам'ять останньої папки та історію навігації.

## v0.1.0 — legacy PowerShell branch

**English**
- Added the first stable Explorer/Image/Text layout and folder navigation workflow.

**Українська**
- Додано першу стабільну структуру Провідник/Зображення/Текст і навігацію по папках.

## v0.0.1–v0.0.x — prototype branch

**English**
- Initial PowerShell/WPF prototype: choose a folder, show image tiles and text files, switch between text descriptions.

**Українська**
- Початковий прототип PowerShell/WPF: вибір папки, плитки зображень, текстові файли та перемикання між описами.
