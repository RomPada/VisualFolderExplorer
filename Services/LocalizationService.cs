namespace VisualFolderExplorer.Services;

public sealed class LocalizationService
{
    private readonly Dictionary<string, Dictionary<string, string>> _strings = new(StringComparer.OrdinalIgnoreCase)
    {
        ["UA"] = new(StringComparer.OrdinalIgnoreCase)
        {
            ["ChooseFolder"] = "Обрати папку", ["MoveImages"] = "Перенести", ["Explorer"] = "Провідник", ["Images"] = "Зображення", ["Text"] = "Текст",
            ["Save"] = "Зберегти", ["Edit"] = "Редагувати", ["Preview"] = "Перегляд", ["BackToText"] = "До тексту", ["Ready"] = "Готово",
            ["SortName"] = "За назвою", ["SortModified"] = "За датою зміни", ["SortCreated"] = "За датою створення", ["SortSize"] = "За розміром",
            ["Ascending"] = "Звичайне ↑", ["Descending"] = "Зворотне ↓", ["Open"] = "Відкрити", ["Cut"] = "Вирізати", ["Copy"] = "Копіювати",
            ["Paste"] = "Вставити", ["Rename"] = "Перейменувати", ["Delete"] = "Видалити", ["CreateFolder"] = "Створити папку", ["CreateTxt"] = "Створити TXT-файл",
            ["CreateMd"] = "Створити Markdown-файл (.md)", ["SelectAll"] = "Виділити все", ["Cancel"] = "Скасувати", ["Yes"] = "Так", ["No"] = "Ні",
            ["SaveChanges"] = "Зберегти", ["DiscardChanges"] = "Не зберігати", ["UnsavedTitle"] = "Незбережені зміни", ["UnsavedMessage"] = "У файлі '{0}' є незбережені зміни. Зберегти їх перед продовженням?",
            ["MoveTitle"] = "Перенесення зображень", ["From"] = "Звідки", ["To"] = "Куди", ["Browse"] = "Обрати", ["Move"] = "Перенести",
            ["MoveHint"] = "Переносяться зображення лише з цієї папки. При збігу назви додається _1, _2 тощо.", ["MoveDone"] = "Перенесено: {0}. Автоперейменовано: {1}.", ["MoveSourceMissing"] = "Папка-джерело не існує.", ["MoveDestinationRequired"] = "Оберіть папку призначення.", ["MoveSameFolder"] = "Джерело і призначення не можуть бути однаковими.",
            ["NoImages"] = "У цій папці немає зображень.", ["NoText"] = "У цій папці немає файлів .txt або .md.", ["FolderPicker"] = "Оберіть папку", ["SelectThisFolder"] = "Обрати цю папку",
            ["CurrentFolder"] = "Поточна папка", ["Drive"] = "Диск", ["Up"] = "Вгору", ["NoSubfolders"] = "У цій папці немає підпапок.", ["Name"] = "Назва",
            ["NewFolder"] = "Нова папка", ["NewFile"] = "Новий файл.txt", ["NewMarkdown"] = "Новий файл.md", ["Error"] = "Помилка", ["Warning"] = "Увага",
            ["DeleteFileQuestion"] = "Перемістити '{0}' до кошика?", ["DeleteFolderQuestion"] = "Перемістити папку '{0}' разом з усім вмістом до кошика?",
            ["RenamePrompt"] = "Введіть нову назву:", ["OpenFolder"] = "Відкрито: {0}", ["Loading"] = "Завантаження прев'ю: {0} / {1}", ["Loaded"] = "Прев'ю завантажено: {0}",
            ["FilesCount"] = "{0} файлів", ["OneFile"] = "1 файл", ["Back"] = "Назад", ["Home"] = "До кореневої папки", ["FolderUp"] = "На рівень вище",
            ["UnsavedMark"] = "незбережено", ["Saved"] = "Збережено: {0}", ["ClipboardEmpty"] = "У буфері обміну немає файлів або папок для вставлення."
        },
        ["EN"] = new(StringComparer.OrdinalIgnoreCase)
        {
            ["ChooseFolder"] = "Choose folder", ["MoveImages"] = "Move images", ["Explorer"] = "Explorer", ["Images"] = "Images", ["Text"] = "Text",
            ["Save"] = "Save", ["Edit"] = "Edit", ["Preview"] = "Preview", ["BackToText"] = "Back to text", ["Ready"] = "Ready",
            ["SortName"] = "By name", ["SortModified"] = "By modified date", ["SortCreated"] = "By creation date", ["SortSize"] = "By size",
            ["Ascending"] = "Ascending ↑", ["Descending"] = "Descending ↓", ["Open"] = "Open", ["Cut"] = "Cut", ["Copy"] = "Copy", ["Paste"] = "Paste",
            ["Rename"] = "Rename", ["Delete"] = "Delete", ["CreateFolder"] = "Create folder", ["CreateTxt"] = "Create TXT file", ["CreateMd"] = "Create Markdown file (.md)",
            ["SelectAll"] = "Select all", ["Cancel"] = "Cancel", ["Yes"] = "Yes", ["No"] = "No", ["SaveChanges"] = "Save", ["DiscardChanges"] = "Don't save",
            ["UnsavedTitle"] = "Unsaved changes", ["UnsavedMessage"] = "File '{0}' has unsaved changes. Save them before continuing?", ["MoveTitle"] = "Move images", ["From"] = "From",
            ["To"] = "To", ["Browse"] = "Browse", ["Move"] = "Move", ["MoveHint"] = "Moves images from this folder only. Name conflicts receive _1, _2, and so on.",
            ["MoveDone"] = "Moved: {0}. Auto-renamed: {1}.", ["MoveSourceMissing"] = "The source folder does not exist.", ["MoveDestinationRequired"] = "Choose a destination folder.", ["MoveSameFolder"] = "Source and destination cannot be the same.", ["NoImages"] = "There are no images in this folder.", ["NoText"] = "There are no .txt or .md files in this folder.",
            ["FolderPicker"] = "Choose folder", ["SelectThisFolder"] = "Choose this folder", ["CurrentFolder"] = "Current folder", ["Drive"] = "Drive", ["Up"] = "Up",
            ["NoSubfolders"] = "This folder has no subfolders.", ["Name"] = "Name", ["NewFolder"] = "New folder", ["NewFile"] = "New file.txt", ["NewMarkdown"] = "New file.md",
            ["Error"] = "Error", ["Warning"] = "Warning", ["DeleteFileQuestion"] = "Move '{0}' to the Recycle Bin?", ["DeleteFolderQuestion"] = "Move folder '{0}' and all of its contents to the Recycle Bin?",
            ["RenamePrompt"] = "Enter a new name:", ["OpenFolder"] = "Opened: {0}", ["Loading"] = "Loading previews: {0} / {1}", ["Loaded"] = "Previews loaded: {0}",
            ["FilesCount"] = "{0} files", ["OneFile"] = "1 file", ["Back"] = "Back", ["Home"] = "Go to root folder", ["FolderUp"] = "Up one level", ["UnsavedMark"] = "unsaved",
            ["Saved"] = "Saved: {0}", ["ClipboardEmpty"] = "The clipboard does not contain files or folders to paste."
        }
    };

    public string Language { get; private set; } = "UA";
    public event EventHandler? LanguageChanged;

    public void SetLanguage(string language)
    {
        if (!_strings.ContainsKey(language)) language = "UA";
        if (Language.Equals(language, StringComparison.OrdinalIgnoreCase)) return;
        Language = language.ToUpperInvariant();
        LanguageChanged?.Invoke(this, EventArgs.Empty);
    }

    public string T(string key, params object[] args)
    {
        if (!_strings.TryGetValue(Language, out var table) || !table.TryGetValue(key, out var value)) value = key;
        return args.Length == 0 ? value : string.Format(value, args);
    }
}
