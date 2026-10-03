# Visual Folder Explorer — Patch List / Список змін

This file is maintained for every release in English and Ukrainian.  
Цей файл оновлюється для кожної версії англійською та українською мовами.

---

## v1.5.0 — 2026-10-01

**English**
- Added **Group by similarity** to the image-actions toolbar.
- Added a fully local pHash-style perceptual similarity engine with no API or external package dependency.
- Images are normalized to 32×32 grayscale, low-frequency DCT coefficients are converted to a 63-bit perceptual hash, and Hamming similarity is used for grouping.
- Added parallel analysis with progress and unreadable-file count for large folders.
- Added a remembered similarity-threshold slider; changing it rebuilds groups from cached hashes without recalculating source images.
- Added a preview window with group thumbnails, average similarity, group/file summary, editable output-folder prefix, and per-image include/exclude checkboxes.
- Added safe confirmed output into `Similar_001`, `Similar_002`, ... folders; ungrouped and unchecked images remain in place.
- Existing filename conflict protection (`_1`, `_2`, ...) is reused during similarity grouping.
- Temporarily pauses the open-folder watcher while the similarity workflow is active.

**Українська**
- До панелі операцій додано **«Групувати за схожістю»**.
- Додано повністю локальний perceptual similarity engine у стилі pHash без API та сторонніх package-залежностей.
- Картинки нормалізуються до 32×32 grayscale, низькочастотні DCT-коефіцієнти перетворюються на 63-бітний perceptual hash, а групування виконується за Hamming similarity.
- Для великих папок додано паралельний аналіз із progress та лічильником файлів, які не вдалося прочитати.
- Додано запам'ятовуваний slider порогу схожості; зміна порогу перебудовує групи з уже порахованих хешів без повторного аналізу оригіналів.
- Додано preview-вікно з thumbnails груп, середньою схожістю, кількістю груп/файлів, редагованим префіксом папок і checkbox для включення/виключення окремих картинок.
- Після підтвердження створюються `Similar_001`, `Similar_002`, ...; файли поза групами та зняті з вибору залишаються на місці.
- Для конфліктів назв під час розкладання використовується існуюча логіка `_1`, `_2`, ...
- Watcher відкритої папки тимчасово призупиняється на час роботи режиму схожості.

## v1.4.1 — 2026-10-01

**English**
- Fixed image scrollbar dragging being intercepted by image Drag & Drop; dragging now starts only when the press originates on an image tile.
- Reworked the selected-image marker positioning to use the real WPF vertical ScrollBar and Track coordinates instead of a fixed right-side offset.
- The blue marker now centers on the actual scrollbar track/thumb width and follows template/layout changes.

**Українська**
- Виправлено перетягування скролбара: Drag & Drop зображень тепер запускається лише тоді, коли натискання почалося безпосередньо на плитці картинки.
- Позиціонування синьої відмітки перероблено: тепер воно використовує реальні координати вертикального ScrollBar/Track WPF замість фіксованого відступу справа.
- Синя відмітка центрується відносно фактичного скролбара та коректно реагує на зміни шаблону й layout.

## v1.4.0 — 2026-10-01

**English**
- Adjusted the selected-image scrollbar marker to match the scrollbar width more closely.
- Moved image metadata from the preview overlay into the Preview header and hide it automatically while zoomed.
- Removed adjustable tile sizing and restored the fixed pre-v1.3.0 tile layout.
- Reworked Explorer context menus with a fully custom rounded ContextMenu template.
- Added **Delete all conflicts** to duplicate results: it keeps one file per duplicate group and sends the remaining copies to the Recycle Bin.
- Kept context-aware sort direction labels for name, date, and size.

**Українська**
- Синю відмітку вибраного зображення підігнано під ширину скролбара.
- Метадані зображення перенесено з overlay поверх картинки у заголовок «Перегляд»; під час zoom вони автоматично ховаються.
- Регулятор розміру плиток прибрано та повернуто фіксований розмір плиток, як до v1.3.0.
- Контекстне меню «Провідника» переведено на повністю кастомний округлений шаблон ContextMenu.
- У пошуку дублікатів додано **«Видалити всі конфлікти»**: по одному файлу з кожної групи залишається, решта копій переміщується до Кошика.
- Збережено контекстні назви напрямку сортування за назвою, датою та розміром.

## v1.3.1 — 2026-10-01

**English**
- Fixed build error `CS0103` in `MainWindow.Features.cs` where `NoticeKind` was not visible in the feature partial class.
- Added the missing `using VisualFolderExplorer.Windows;` import so Drag & Drop error dialogs compile correctly.
- No functional changes to v1.3.0 features.

**Українська**
- Виправлено помилку збірки `CS0103` у `MainWindow.Features.cs`, де `NoticeKind` не був доступний у partial-класі функцій.
- Додано відсутній `using VisualFolderExplorer.Windows;`, щоб коректно компілювалися повідомлення про помилки Drag & Drop.
- Функціонал v1.3.0 не змінювався.

## v1.3.0 — 2026-10-01

**English**
- Added a preview pane and direct Recycle Bin deletion to duplicate search results.
- Replaced batch-rename conflict checkboxes with a warning marker and an explicit explanation of what a name conflict means.
- Added context-aware sort direction labels for name, date, and size sorting.
- Added a modern rounded scrollbar template.
- Added image counts to the folder picker.
- Added Drag & Drop for importing external files/folders and moving selected images onto Explorer folders.
- Replaced the main address field with clickable breadcrumb navigation.
- Added persistence for pane widths and image tile size.
- Added per-folder scroll-position and last-selected-image restoration.
- Added an image tile-size slider.
- Added image metadata to preview (dimensions, file size, creation and modification dates).
- Added a debounced folder watcher for external file changes.

**Українська**
- У результатах пошуку дублікатів додано прев'ю та пряме видалення вибраних файлів до Кошика.
- У масовому перейменуванні checkbox конфлікту замінено на попереджувальний маркер та додано пояснення, що саме означає конфлікт назви.
- Додано контекстні назви напрямку сортування для назви, дати та розміру.
- Додано сучасний округлений стиль скролбарів.
- У виборі папки додано лічильник зображень.
- Додано Drag & Drop для імпорту зовнішніх файлів/папок і переміщення вибраних зображень на папки у «Провіднику».
- Головний рядок адреси замінено на клікабельний breadcrumb.
- Додано запам'ятовування ширини панелей та розміру плиток.
- Додано відновлення позиції прокрутки та останнього вибраного зображення окремо для кожної папки.
- Додано регулятор розміру плиток.
- У preview додано метадані зображення: роздільність, розмір файла, дати створення та зміни.
- Додано watcher відкритої папки з debounce для автоматичного підхоплення зовнішніх змін.

## v1.2.1 — 2026-10-01

**English**
- Fixed the C# build failure introduced by enabling Windows Forms alongside WPF.
- Removed Windows Forms from the project to eliminate CS0104 ambiguous references for `KeyEventArgs`, `MouseEventArgs`, `ContextMenu`, and `Point`.
- Replaced `System.Windows.Forms.FolderBrowserDialog` with the built-in WPF `Microsoft.Win32.OpenFolderDialog`.
- Native Windows folder browsing remains available without adding a second UI framework.

**Українська**
- Виправлено помилку збірки C#, спричинену одночасним підключенням Windows Forms і WPF.
- Windows Forms прибрано з проєкту, що усуває CS0104 для `KeyEventArgs`, `MouseEventArgs`, `ContextMenu` і `Point`.
- `System.Windows.Forms.FolderBrowserDialog` замінено на вбудований WPF `Microsoft.Win32.OpenFolderDialog`.
- Стандартний Windows-вибір папок збережено без другого UI-фреймворку.

## v1.2.0 — 2026-10-01

**English**
- Moved **Move images**, **Duplicates**, and **Batch rename** out of the image header into a dedicated image-actions bar between the address toolbar and the Explorer / Images / Preview workspace.
- Simplified the image header so it now focuses on image title, sorting, and file/selection count.
- Reworked the shared folder picker used both by **Choose folder** and image-transfer browsing: the dedicated **Drive** combo was removed.
- Added **Browse...** in its place. It opens the native Windows folder-browser tree, matching the familiar address/folder-selection workflow while keeping the styled in-app picker and current-path navigation available.
- Added UA / EN labels for the new image-actions bar and native-address browsing button.
- Enabled Windows Forms support only for the native Windows folder browser; no extra software is required for portable builds.

**Українська**
- Кнопки **«Перенести»**, **«Дублікати»** та **«Масове перейменування»** винесено із заголовка блока «Зображення» в окрему панель операцій між адресним рядком і основними блоками «Провідник / Зображення / Перегляд».
- Заголовок блока «Зображення» спрощено: у ньому залишилися назва блока, сортування та лічильник файлів/вибраних елементів.
- Перероблено спільне вікно вибору папки, яке використовується і кнопкою **«Обрати папку»**, і під час перенесення: окремий блок **«Диск»** прибрано.
- Замість нього додано **«Огляд...»**, який відкриває стандартне дерево вибору папок Windows, як у звичному системному меню вибору адреси; при цьому стилізоване вікно програми та навігація поточним шляхом збережені.
- Додано UA / EN локалізацію для нової панелі операцій і кнопки системного огляду папок.
- Windows Forms увімкнено лише для системного Folder Browser; для portable-збірки це не потребує встановлення додаткового ПЗ.

## v1.1.1 — 2026-10-01

**English**
- Fixed local restore failure `NU1100` on machines that have .NET 10 SDK but not the .NET 8 reference packs.
- Retargeted the application from `net8.0-windows` to `net10.0-windows`.
- Updated `StartDev.bat`, `BuildRelease.bat`, publish scripts, and GitHub Actions to require/use .NET 10.
- Portable self-contained builds still require no .NET installation on the target PC.
- No feature regressions: v1.1.0 multi-select, selected-image move, transfer preview, duplicate search, and batch rename are unchanged.

**Українська**
- Виправлено локальну помилку restore `NU1100` на ПК, де встановлено .NET 10 SDK, але відсутні reference packs .NET 8.
- Проєкт переведено з `net8.0-windows` на `net10.0-windows`.
- `StartDev.bat`, `BuildRelease.bat`, publish-скрипти та GitHub Actions оновлено для .NET 10.
- Кінцева self-contained portable-збірка, як і раніше, не потребує встановлення .NET на ПК користувача.
- Функціональність v1.1.0 збережена без змін: мультивибір, перенесення вибраних, preview перенесення, пошук дублікатів і Batch rename.

## v1.1.0 — 2026-10-01

**English**
- Added extended image multi-selection with `Ctrl + click`, `Shift + click`, and explicit `Ctrl+A` support.
- Added selected-image count to the image header and preserved clear visual states for multi-selected, last-selected, and previewed images.
- Added **Move selected** mode. The move dialog can now operate on all images in the folder or only the current selection.
- Added a mandatory move preview showing source/destination filenames, total count, and automatic conflict renames before files are moved.
- Added exact duplicate detection using file-size prefiltering plus SHA-256 content hashing, with an option to select duplicate copies in the image grid.
- Added safe batch rename for selected images with sequential numbering and case-insensitive find/replace modes, live preview, conflict detection, and two-phase temporary renaming.
- Added modern dedicated windows for move preview, duplicate results, and batch rename.
- Added fast local-development guidance: use `StartDev.bat` with the installed .NET 8 SDK and reserve GitHub Actions for portable releases.

**Українська**
- Додано розширений мультивибір зображень через `Ctrl + клік`, `Shift + клік` і явну підтримку `Ctrl+A`.
- У заголовку блока «Зображення» тепер показується кількість вибраних файлів; окремо збережені візуальні стани мультивибору, останнього вибраного та відкритого у preview зображення.
- Додано режим **«Перенести вибрані»**: вікно перенесення працює або з усіма картинками папки, або лише з поточним вибором.
- Додано обов'язковий preview перед масовим перенесенням із поточними/новими назвами, кількістю файлів та автоматичних перейменувань через конфлікти.
- Додано пошук точних дублікатів через попереднє групування за розміром і SHA-256 перевірку вмісту; копії можна одразу виділити у сітці.
- Додано безпечний Batch rename вибраних картинок: послідовна нумерація або «знайти / замінити», live preview, перевірка конфліктів і двофазне тимчасове перейменування.
- Додано окремі сучасні вікна для preview перенесення, результатів пошуку дублікатів і масового перейменування.
- Додано рекомендацію для швидкої локальної розробки: `StartDev.bat` з установленим .NET 8 SDK, GitHub Actions — лише для portable-релізів.

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
