# Visual Folder Explorer — Patch List / Історія змін

Every release of Visual Folder Explorer is recorded here. Each entry is provided in English and Ukrainian.

Кожна версія Visual Folder Explorer фіксується у цьому файлі. Для кожного релізу наведено англійський та український опис.

---

## v0.11.0 — 2026-09-22

**English**
- Centralized reusable interface styling in the new `Styles.xaml` file so buttons, menus, fields, dialogs, popups, ComboBoxes, and scrollbars can share one visual system.
- Added a **Move images** drop-down panel between **Choose folder** and the UA/EN language selector.
- The move source defaults to the currently open folder; the destination restores the last successful move destination and is empty until one exists.
- Added folder pickers for source and destination.
- Moving supports all image extensions recognized by the application, scans only the selected source folder, preserves original filenames, and resolves conflicts using `_1`, `_2`, etc.
- The last successful move destination is stored in `settings.json`.
- Added Ukrainian and English localization for the new image-moving UI.
- Updated both READMEs and corrected the Semantic Versioning examples.

**Українська**
- Повторно використовувані стилі інтерфейсу винесено в новий файл `Styles.xaml`, щоб кнопки, меню, поля, діалоги, popup-панелі, ComboBox і скролбари використовували єдину візуальну систему.
- Між кнопкою **«Обрати папку»** та перемикачем UA/EN додано випадаючу панель **«Перенести»** для перенесення зображень.
- Поле джерела за замовчуванням містить поточну відкриту папку; поле призначення відновлює останню успішну адресу і до першого перенесення залишається порожнім.
- Додано вибір папок для джерела та призначення.
- Переносяться всі формати зображень, які підтримує програма, лише з вибраної папки без підпапок; початкові назви зберігаються, а конфлікти вирішуються суфіксами `_1`, `_2` тощо.
- Остання успішна папка призначення зберігається у `settings.json`.
- Новий інтерфейс перенесення локалізовано українською та англійською.
- Оновлено обидва README та виправлено приклади Semantic Versioning.

## v0.10.0 — 2026-09-22

**English**
- Added a persistent UA / EN language switcher in the top-right toolbar and made the application bilingual.
- Added localized main UI labels, image sorting controls, context menus, create/rename/delete dialogs, and common status text.
- Replaced the default Windows text-edit context menu with the application's modern styled menu and localized Cut / Copy / Paste / Select all actions.
- Replaced the old system unsaved-changes MessageBox with a modern three-button Save / Don't save / Cancel dialog.
- The selected interface language is now stored in `settings.json`.
- Kept only `README.md` (English) and `README_UA.md` (Ukrainian); the legacy `README.txt` is not included.

**Українська**
- Додано перемикач UA / EN у правому верхньому куті та двомовний інтерфейс програми.
- Локалізовано основні написи, сортування зображень, контекстні меню, вікна створення/перейменування/видалення та основні статусні повідомлення.
- Стандартне системне меню редагування тексту замінено на сучасне меню програми з локалізованими діями «Вирізати / Копіювати / Вставити / Виділити все».
- Системне попередження про незбережений текст замінено на сучасне трикнопкове вікно «Зберегти / Не зберігати / Скасувати».
- Обрана мова інтерфейсу тепер зберігається у `settings.json`.
- У комплекті залишаються лише `README.md` (англійською) та `README_UA.md` (українською); старий `README.txt` не додається.

## v0.9.1 — 2026-09-22

**English**
- Added this bilingual `PATCHLIST.md` and established it as the permanent release history.
- Replaced the old Ukrainian-only `README.txt` with `README.md` as the primary English documentation.
- Added `README_UA.md` as the Ukrainian documentation.
- Updated the version number in the application and launcher.

**Українська**
- Додано двомовний `PATCHLIST.md`, який надалі є постійною історією релізів.
- Старий україномовний `README.txt` замінено на основний англомовний `README.md`.
- Додано окремий україномовний `README_UA.md`.
- Оновлено номер версії у програмі та файлі запуску.

## v0.9.0 — 2026-09-22

**English**
- Major performance optimization for folders containing hundreds or 1000+ images.
- Added progressive thumbnail loading so the UI stays responsive while previews are created.
- Reduced thumbnail decode size and memory usage.
- Image context menus are now created on demand instead of for every tile at startup.
- Removed repeated full-tile selection refreshes during image loading.
- Folder contents are enumerated once per navigation and reused by Explorer, Images, and Text.
- Large image collections are processed in smaller adaptive batches.

**Українська**
- Значно оптимізовано роботу з папками, у яких сотні або 1000+ зображень.
- Додано поступове завантаження прев'ю, щоб інтерфейс залишався доступним під час підвантаження.
- Зменшено технічний розмір thumbnail та використання пам'яті.
- Контекстні меню картинок створюються лише за потреби, а не для кожної плитки під час запуску.
- Прибрано повторний повний перерахунок стану всіх плиток під час завантаження.
- Вміст папки читається один раз і повторно використовується блоками «Провідник», «Зображення» та «Текст».
- Великі колекції зображень обробляються невеликими адаптивними порціями.

## v0.8.2 — 2026-09-21

**English**
- Fixed the selected-image scrollbar marker by positioning it relative to the actual scrollbar thumb instead of a hard-coded offset.

**Українська**
- Виправлено позицію маркера вибраної картинки: тепер він прив'язується до фактичного повзунка скролбара, а не до фіксованого відступу.

## v0.8.1 — 2026-09-21

**English**
- First visual alignment fix for the selected-image scrollbar marker.

**Українська**
- Перше візуальне виправлення вирівнювання маркера вибраної картинки на скролбарі.

## v0.8.0 — 2026-09-21

**English**
- Paste name conflicts now create a unique name such as `name_1`, `name_2`, etc. instead of skipping the item.
- Switching TXT/MD files with the text-panel arrows now also selects and scrolls to the matching file in Explorer.
- Added a persistent marker on the Images scrollbar to show approximately where the last selected image is located.

**Українська**
- При конфлікті назв під час вставлення новий файл або папка автоматично отримує унікальну назву на кшталт `назва_1`, `назва_2` тощо.
- Перемикання TXT/MD стрілками в блоці «Текст» тепер також виділяє та прокручує до відповідного файла у «Провіднику».
- Додано постійний маркер на скролбарі блока «Зображення», який показує приблизне положення останньої вибраної картинки.

## v0.7.2 — 2026-09-21

**English**
- Fixed a WPF startup crash caused by a forward `StaticResource` reference in the scrollbar styling.

**Українська**
- Виправлено падіння WPF під час запуску через передчасне посилання `StaticResource` у стилях скролбара.

## v0.7.1 — 2026-09-21

**English**
- Reworked the custom scrollbar XAML for better Windows PowerShell 5.1 / WPF compatibility.
- Corrected the version displayed by the BAT launcher.

**Українська**
- Перероблено XAML кастомного скролбара для кращої сумісності з Windows PowerShell 5.1 / WPF.
- Виправлено номер версії, який показував BAT-файл запуску.

## v0.7.0 — 2026-09-21

**English**
- Added styled buttons to rename/create dialogs.
- Added custom styled delete confirmation dialogs.
- Added paste to the empty area of the Images panel.
- Added a custom scrollbar appearance and continued general UI polishing.

**Українська**
- Додано стилізовані кнопки у вікнах перейменування та створення.
- Додано власні стилізовані вікна підтвердження видалення.
- Додано вставлення через правий клік по порожньому місцю блока «Зображення».
- Додано кастомний вигляд скролбарів та продовжено загальне полірування інтерфейсу.

## v0.6.2 — 2026-09-21

**English**
- Styled right-click context menus.
- Styled image sorting ComboBoxes and their drop-down lists.

**Українська**
- Стилізовано контекстні меню правої кнопки миші.
- Стилізовано поля сортування зображень та їхні випадаючі списки.

## v0.6.1 — 2026-09-21

**English**
- Replaced the old Visual Basic InputBox with a cleaner custom text input dialog.
- Improved spacing and width of image sorting controls.

**Українська**
- Старий Visual Basic InputBox замінено на акуратніше власне вікно вводу.
- Покращено відступи та ширину елементів сортування зображень.

## v0.6.0 — 2026-09-21

**English**
- Renamed the left panel from “Folders” to “Explorer”.
- Added image sorting by name, modified date, creation date, and size, with ascending/descending order.
- Sorting preference is saved between launches.
- Added folder creation plus cut/copy/rename/delete operations for folders.
- Folder deletion sends the folder to the Windows Recycle Bin.

**Українська**
- Лівий блок «Папки» перейменовано на «Провідник».
- Додано сортування зображень за назвою, датою зміни, датою створення та розміром, зі звичайним і зворотним напрямком.
- Обраний тип сортування запам'ятовується між запусками.
- Додано створення папок та операції вирізання, копіювання, перейменування і видалення папок.
- Видалені папки відправляються до Кошика Windows.

## v0.5.0 — 2026-09-21

**English**
- Preview zoom changed to 300%.
- Added active and soft “last selected” image highlights.
- Markdown files now open in rendered Markdown view by default.
- Added Edit/Preview switching for Markdown.

**Українська**
- Зум прев'ю змінено на 300%.
- Додано яскраве виділення активної картинки та м'яке виділення останньої вибраної.
- Markdown-файли тепер за замовчуванням відкриваються у відформатованому вигляді.
- Додано перемикання Markdown між режимами «Редагувати» та «Перегляд».

## v0.4.1 — 2026-09-21

**English**
- Added persistence of window size and maximized state between launches.

**Українська**
- Додано запам'ятовування розміру вікна та стану «на весь екран» між запусками.

## v0.4.0 — 2026-09-21

**English**
- Added panning of zoomed image previews by dragging with the left mouse button.
- Added Paste to the Explorer empty-area context menu and `Ctrl+V` support.
- Improved visibility of the current text filename.
- TXT/MD files open with a single click in Explorer.

**Українська**
- Додано переміщення збільшеного прев'ю затиснутою лівою кнопкою миші.
- Додано «Вставити» у контекстне меню порожнього місця «Провідника» та підтримку `Ctrl+V`.
- Покращено видимість назви поточного текстового файла.
- TXT/MD-файли відкриваються одним кліком у «Провіднику».

## v0.3.1 — 2026-09-21

**English**
- Fixed a PowerShell parsing error caused by typographic apostrophes in UI strings.

**Українська**
- Виправлено помилку парсингу PowerShell, спричинену типографічними апострофами у текстах інтерфейсу.

## v0.3.0 — 2026-09-21

**English**
- Added click-to-zoom image preview behavior.
- Added image context menu: cut, copy, rename, delete.
- TXT/MD files are now listed in Explorer and have their own context menu.
- Added creation of TXT and Markdown files from the Explorer empty area.
- Deletes now go to the Windows Recycle Bin.

**Українська**
- Додано збільшення картинки кліком у прев'ю.
- Додано контекстне меню картинок: вирізати, копіювати, перейменувати, видалити.
- TXT/MD-файли додано до «Провідника» з окремим контекстним меню.
- Додано створення TXT і Markdown-файлів через правий клік по порожньому місцю.
- Видалення тепер відправляє файли до Кошика Windows.

## v0.2.0 — 2026-09-21

**English**
- Added editing and saving of TXT and Markdown files.
- Added `Ctrl+S`.
- Added unsaved-change prompts when switching files/folders or closing the app.
- Added basic encoding preservation.

**Українська**
- Додано редагування та збереження TXT і Markdown-файлів.
- Додано `Ctrl+S`.
- Додано попередження про незбережені зміни при переходах або закритті програми.
- Додано базове збереження початкового кодування файла.

## v0.1.1 — 2026-09-21

**English**
- Moved the “Back to text” button to the left side.
- Fixed navigation buttons so they work immediately when the last folder is restored at startup.
- Improved restored navigation history behavior.

**Українська**
- Кнопку «До тексту» перенесено в ліву частину панелі.
- Виправлено кнопки навігації, щоб вони працювали одразу після автоматичного відкриття останньої папки.
- Покращено відновлення історії навігації.

## v0.1.0 — 2026-09-21

**English**
- Fixed image preview invocation errors.
- Image preview moved into the right panel instead of a separate window.
- Added “Back to text”.
- Added remembering and restoring the last opened folder.

**Українська**
- Виправлено помилки виклику прев'ю зображення.
- Прев'ю перенесено у праву панель замість окремого вікна.
- Додано кнопку «До тексту».
- Додано запам'ятовування та відновлення останньої відкритої папки.

## v0.0.2 — 2026-09-21

**English**
- Reworked the launcher to avoid the common unsigned PowerShell script execution-policy block.

**Українська**
- Перероблено запуск, щоб обійти типове блокування непідписаних PowerShell-скриптів політикою виконання Windows.

## v0.0.1 — 2026-09-21

**English**
- Initial working prototype.
- Folder navigation, image thumbnails, and TXT viewing in a right-side panel.
- Added switching between multiple text files using arrow buttons.

**Українська**
- Перша робоча версія.
- Навігація по папках, плитки зображень та перегляд TXT у правій панелі.
- Додано перемикання між кількома текстовими файлами стрілками.
