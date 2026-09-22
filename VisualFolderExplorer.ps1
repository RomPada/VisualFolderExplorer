Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Xaml
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName Microsoft.VisualBasic

[System.Windows.Forms.Application]::EnableVisualStyles()

$script:RootFolder = $null
$script:CurrentFolder = $null
$script:TextFiles = @()
$script:TextIndex = -1
$script:ImageExtensions = @('.jpg', '.jpeg', '.png', '.bmp', '.gif', '.tif', '.tiff', '.webp')
$script:AppVersion = '0.11.1'
$script:ImageSortField = 'Name'
$script:ImageSortDescending = $false
$script:InitializingSortControls = $true
$script:PreviewZoomed = $false
$script:PreviewImagePath = $null
$script:PreviewDragging = $false
$script:PreviewDragMoved = $false
$script:PreviewDragStart = [System.Windows.Point]::new(0, 0)
$script:PreviewDragOriginX = 0.0
$script:PreviewDragOriginY = 0.0
$script:PreviewScaleTransform = $null
$script:PreviewTranslateTransform = $null
$script:LastSelectedImagePath = $null
$script:ImageTiles = @{}
# Performance: image tiles are loaded incrementally so folders with hundreds of
# images do not block the UI.  The generation number cancels stale batches when
# the user changes folders or sorting while a previous folder is still loading.
$script:ImageLoadTimer = $null
$script:ImageLoadGeneration = 0
$script:PendingImages = @()
$script:PendingImageIndex = 0
$script:ImageLoadBatchSize = 14
$script:ImageThumbnailDecodeWidth = 240
$script:ImageLoadStartedAt = $null
$script:MarkerUpdateTimer = $null
$script:SyncingExplorerSelection = $false
$script:IsCurrentMarkdown = $false
$script:MarkdownRendered = $false
$script:IsLoadingText = $false
$script:TextDirty = $false
$script:CurrentTextEncoding = [System.Text.UTF8Encoding]::new($false)
$script:SettingsFolder = Join-Path $env:LOCALAPPDATA 'VisualFolderExplorer'
$script:SettingsPath = Join-Path $script:SettingsFolder 'settings.json'

$script:AppFolder = if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { (Get-Location).Path }
$script:StylesPath = Join-Path $script:AppFolder 'Styles.xaml'
if (-not (Test-Path -LiteralPath $script:StylesPath -PathType Leaf)) {
    throw "Styles.xaml was not found: $script:StylesPath"
}
$styleFileText = [System.IO.File]::ReadAllText($script:StylesPath)
$styleMatch = [regex]::Match($styleFileText, '(?s)<ResourceDictionary[^>]*>(.*)</ResourceDictionary>\s*$')
if (-not $styleMatch.Success) {
    throw 'Styles.xaml has an invalid ResourceDictionary structure.'
}
$script:StyleResourceFragment = $styleMatch.Groups[1].Value

$script:LastMoveDestination = ''

$script:Language = 'UA'
$script:InitializingLanguageControl = $true
$script:Strings = @{
    UA = @{
        ChooseFolder='Обрати папку'; Explorer='Провідник'; Images='Зображення'; Text='Текст'; Preview="Прев'ю"; BackToText='До тексту';
        Save='Зберегти'; Edit='Редагувати'; PreviewMode='Перегляд'; Ready='Готово'; PathPlaceholder='Оберіть кореневу папку';
        BackTip='Назад'; UpTip='На рівень вище'; HomeTip='До кореневої папки'; SortFieldTip='Поле сортування'; SortDirectionTip='Напрям сортування';
        SortName='За назвою'; SortModified='За датою зміни'; SortCreated='За датою створення'; SortSize='За розміром'; Ascending='Звичайне ↑'; Descending='Зворотне ↓';
        ReturnTip='Повернутися до текстового опису'; MarkdownTip='Перемкнути між переглядом Markdown і редагуванням'; SaveTip='Зберегти зміни (Ctrl+S)';
        PreviousTextTip='Попередній текстовий файл'; NextTextTip='Наступний текстовий файл'; PreviewError="Не вдалося відкрити прев'ю.";
        Open='Відкрити'; Cut='Вирізати'; Copy='Копіювати'; Paste='Вставити'; Rename='Перейменувати'; Delete='Видалити'; SelectAll='Виділити все';
        CreateFolder='Створити папку'; CreateTxt='Створити TXT-файл'; CreateMd='Створити Markdown-файл (.md)';
        OK='OK'; Cancel='Скасувати'; Yes='Так'; No='Ні'; SaveChanges='Зберегти'; DiscardChanges='Не зберігати';
        UnsavedTitle='Незбережені зміни'; UnsavedMessage="У файлі '{0}' є незбережені зміни. Зберегти їх перед продовженням?"; UnsavedMark='незбережено';
        NoTextFiles='У цій папці немає файлів .txt або .md.'; NoImages='У цій папці немає зображень.'; SelectRoot='Оберіть кореневу папку, щоб почати.';
        FilesOne='1 файл'; FilesMany='{0} файлів'; NoFiles='0 файлів';
        RenameFolderTitle='Перейменувати папку'; RenameImageTitle='Перейменувати зображення'; RenameTextTitle='Перейменувати текстовий файл'; RenamePrompt='Введіть нову назву файлу:'; RenameFolderPrompt='Введіть нову назву папки:';
        DeleteFolderTitle='Видалити папку'; DeleteImageTitle='Видалити зображення'; DeleteTextTitle='Видалити текстовий файл'; DeleteFolderMessage="Перемістити папку '{0}' разом з усім вмістом до кошика?"; DeleteFileMessage="Перемістити '{0}' до кошика?";
        CreateFolderTitle='Створити папку'; CreateFolderPrompt='Назва нової папки:'; NewFolder='Нова папка'; CreateTxtTitle='Створити TXT'; CreateTxtPrompt='Назва нового TXT-файлу:'; NewTxt='Новий файл.txt'; CreateMdTitle='Створити Markdown'; CreateMdPrompt='Назва нового Markdown-файлу:'; NewMd='Новий файл.md';
        FolderDialog='Оберіть кореневу папку з вашими матеріалами'; Saved='Збережено: {0}'; OpenedText='Відкрито текстовий файл: {0}'; UnsavedStatus='Є незбережені зміни';
        PreviewZoomHint="Лівий клік по прев'ю: збільшити до 300%. Після збільшення затисніть і перетягуйте зображення.";
        ClipboardEmpty='У буфері обміну немає файлів або папок для вставлення.'; PasteTitle='Вставлення';
        ClipboardErrorTitle='Помилка буфера обміну'; ClipboardError='Не вдалося помістити файл у буфер обміну.'; DeleteErrorTitle='Помилка видалення'; FileRecycleError='Не вдалося перемістити файл до кошика.'; FolderRecycleError='Не вдалося перемістити папку до кошика.';
        CannotPasteInside="Не можна вставити папку '{0}' всередину неї самої."; Moved='Переміщено'; Copied='Скопійовано'; AutoRenamed='Автоперейменовано через збіг назв: {0}.'; PasteSummary='{0}: {1}. Пропущено: {2}. {3}'; PasteIncomplete='Не всі елементи вдалося вставити:';
        SaveErrorTitle='Помилка збереження'; SaveError='Не вдалося зберегти файл:'; ReadFileError='Не вдалося прочитати файл.'; TextReadError='Помилка читання текстових файлів';
        PreviewLoaded="Прев'ю зображень завантажено: {0}{1}"; Seconds=' за {0:N1} с'; PreviewLoading="Завантаження прев'ю: {0} / {1}"; ImageReadError='Помилка читання зображень'; ExplorerReadError='Помилка читання папок і текстових файлів'; FolderReadError='Помилка читання папки'; OpenedFolder='Відкрито: {0}';
        CutFolder='Вирізано папку до буфера обміну: {0}'; CopyFolder='Скопійовано папку до буфера обміну: {0}'; CutClipboard='Вирізано до буфера обміну: {0}'; CopyClipboard='Скопійовано до буфера обміну: {0}';
        InvalidNameTitle='Некоректна назва'; InvalidFolderName='Назва папки містить недопустимі символи.'; InvalidFileName='Назва файлу містить недопустимі символи.'; FolderExists='Папка з такою назвою вже існує.'; FileExists='Файл з такою назвою вже існує.'; RenameTitle='Перейменування';
        ErrorTitle='Помилка'; RenameFolderError='Не вдалося перейменувати папку.'; RenameFileError='Не вдалося перейменувати файл.'; FolderRenamed='Перейменовано папку: {0}'; Renamed='Перейменовано: {0}'; FolderRecycled='Папку переміщено до кошика: {0}'; Recycled='Переміщено до кошика: {0}';
        FolderCreated='Створено папку: {0}'; FileCreated='Створено: {0}'; CreateFolderError='Не вдалося створити папку.'; CreateFileError='Не вдалося створити файл.'; CreateFolderExistsTitle='Створення папки'; CreateFileExistsTitle='Створення файлу';
        ZoomDragDone="Прев'ю 300%: перетягування завершено. Клік без руху повертає стандартний масштаб."; ZoomNormal="Масштаб прев'ю: стандартний"; Zoom300="Масштаб прев'ю: 300% — затисніть ліву кнопку та перетягуйте. Клік без руху повертає 100%.";
        MoveImagesButton='Перенести'; MoveImagesTitle='Перенесення зображень'; MoveSource='Звідки'; MoveDestination='Куди'; Browse='Обрати'; MoveStart='Перенести'; MoveHint='Переносяться зображення лише з цієї папки (без підпапок). При збігу назви додається _1, _2 тощо.'; MoveSourceMissing='Папка-джерело не існує.'; MoveDestinationRequired='Оберіть папку призначення.'; MoveSameFolder='Джерело і призначення не можуть бути однаковими.'; MoveNoImages='У папці-джерелі немає підтримуваних зображень.'; MoveComplete='Перенесено зображень: {0}. Автоперейменовано: {1}.'; MoveError='Не вдалося перенести зображення.'; MoveSelectSource='Оберіть папку-джерело'; MoveSelectDestination='Оберіть папку призначення'; FolderPickerPath='Поточна папка'; FolderPickerDrives='Диск'; FolderPickerUp='Вгору'; FolderPickerSelect='Обрати цю папку'; FolderPickerEmpty='У цій папці немає підпапок.'; FolderPickerInvalid='Вказана папка не існує або недоступна.';
    }
    EN = @{
        ChooseFolder='Choose folder'; Explorer='Explorer'; Images='Images'; Text='Text'; Preview='Preview'; BackToText='Back to text';
        Save='Save'; Edit='Edit'; PreviewMode='Preview'; Ready='Ready'; PathPlaceholder='Choose a root folder';
        BackTip='Back'; UpTip='Up one level'; HomeTip='Go to root folder'; SortFieldTip='Sort field'; SortDirectionTip='Sort direction';
        SortName='By name'; SortModified='By modified date'; SortCreated='By creation date'; SortSize='By size'; Ascending='Ascending ↑'; Descending='Descending ↓';
        ReturnTip='Return to text'; MarkdownTip='Switch between Markdown preview and editing'; SaveTip='Save changes (Ctrl+S)';
        PreviousTextTip='Previous text file'; NextTextTip='Next text file'; PreviewError='Could not open preview.';
        Open='Open'; Cut='Cut'; Copy='Copy'; Paste='Paste'; Rename='Rename'; Delete='Delete'; SelectAll='Select all';
        CreateFolder='Create folder'; CreateTxt='Create TXT file'; CreateMd='Create Markdown file (.md)';
        OK='OK'; Cancel='Cancel'; Yes='Yes'; No='No'; SaveChanges='Save'; DiscardChanges="Don't save";
        UnsavedTitle='Unsaved changes'; UnsavedMessage="File '{0}' has unsaved changes. Save them before continuing?"; UnsavedMark='unsaved';
        NoTextFiles='There are no .txt or .md files in this folder.'; NoImages='There are no images in this folder.'; SelectRoot='Choose a root folder to begin.';
        FilesOne='1 file'; FilesMany='{0} files'; NoFiles='0 files';
        RenameFolderTitle='Rename folder'; RenameImageTitle='Rename image'; RenameTextTitle='Rename text file'; RenamePrompt='Enter a new file name:'; RenameFolderPrompt='Enter a new folder name:';
        DeleteFolderTitle='Delete folder'; DeleteImageTitle='Delete image'; DeleteTextTitle='Delete text file'; DeleteFolderMessage="Move folder '{0}' and all of its contents to the Recycle Bin?"; DeleteFileMessage="Move '{0}' to the Recycle Bin?";
        CreateFolderTitle='Create folder'; CreateFolderPrompt='New folder name:'; NewFolder='New folder'; CreateTxtTitle='Create TXT'; CreateTxtPrompt='New TXT file name:'; NewTxt='New file.txt'; CreateMdTitle='Create Markdown'; CreateMdPrompt='New Markdown file name:'; NewMd='New file.md';
        FolderDialog='Choose the root folder containing your materials'; Saved='Saved: {0}'; OpenedText='Opened text file: {0}'; UnsavedStatus='There are unsaved changes';
        PreviewZoomHint='Left-click the preview to zoom to 300%. When zoomed, hold the left mouse button and drag to pan.';
        ClipboardEmpty='The clipboard does not contain files or folders to paste.'; PasteTitle='Paste';
        ClipboardErrorTitle='Clipboard error'; ClipboardError='Could not place the item on the clipboard.'; DeleteErrorTitle='Delete error'; FileRecycleError='Could not move the file to the Recycle Bin.'; FolderRecycleError='Could not move the folder to the Recycle Bin.';
        CannotPasteInside="Cannot paste folder '{0}' inside itself."; Moved='Moved'; Copied='Copied'; AutoRenamed='Auto-renamed because of name conflicts: {0}.'; PasteSummary='{0}: {1}. Skipped: {2}. {3}'; PasteIncomplete='Some items could not be pasted:';
        SaveErrorTitle='Save error'; SaveError='Could not save file:'; ReadFileError='Could not read file.'; TextReadError='Error reading text files';
        PreviewLoaded='Image previews loaded: {0}{1}'; Seconds=' in {0:N1} s'; PreviewLoading='Loading previews: {0} / {1}'; ImageReadError='Error reading images'; ExplorerReadError='Error reading folders and text files'; FolderReadError='Error reading folder'; OpenedFolder='Opened: {0}';
        CutFolder='Cut folder to clipboard: {0}'; CopyFolder='Copied folder to clipboard: {0}'; CutClipboard='Cut to clipboard: {0}'; CopyClipboard='Copied to clipboard: {0}';
        InvalidNameTitle='Invalid name'; InvalidFolderName='The folder name contains invalid characters.'; InvalidFileName='The file name contains invalid characters.'; FolderExists='A folder with this name already exists.'; FileExists='A file with this name already exists.'; RenameTitle='Rename';
        ErrorTitle='Error'; RenameFolderError='Could not rename the folder.'; RenameFileError='Could not rename the file.'; FolderRenamed='Folder renamed: {0}'; Renamed='Renamed: {0}'; FolderRecycled='Folder moved to Recycle Bin: {0}'; Recycled='Moved to Recycle Bin: {0}';
        FolderCreated='Folder created: {0}'; FileCreated='Created: {0}'; CreateFolderError='Could not create folder.'; CreateFileError='Could not create file.'; CreateFolderExistsTitle='Create folder'; CreateFileExistsTitle='Create file';
        ZoomDragDone='Preview 300%: panning finished. Click without dragging to return to the standard scale.'; ZoomNormal='Preview scale: standard'; Zoom300='Preview scale: 300% — hold the left mouse button and drag. Click without moving to return to 100%.';
        MoveImagesButton='Move images'; MoveImagesTitle='Move images'; MoveSource='From'; MoveDestination='To'; Browse='Browse'; MoveStart='Move'; MoveHint='Moves supported images from this folder only (not subfolders). Name conflicts receive _1, _2, and so on.'; MoveSourceMissing='The source folder does not exist.'; MoveDestinationRequired='Choose a destination folder.'; MoveSameFolder='Source and destination cannot be the same.'; MoveNoImages='The source folder contains no supported images.'; MoveComplete='Moved images: {0}. Auto-renamed: {1}.'; MoveError='Could not move images.'; MoveSelectSource='Choose source folder'; MoveSelectDestination='Choose destination folder'; FolderPickerPath='Current folder'; FolderPickerDrives='Drive'; FolderPickerUp='Up'; FolderPickerSelect='Choose this folder'; FolderPickerEmpty='This folder has no subfolders.'; FolderPickerInvalid='The selected folder does not exist or is not accessible.';
    }
}

function T {
    param([string]$Key, [object[]]$Values = @())
    $langTable = $script:Strings[$script:Language]
    $value = if ($langTable -and $langTable.ContainsKey($Key)) { [string]$langTable[$Key] } else { $Key }
    if ($Values.Count -gt 0) { return [string]::Format($value, $Values) }
    return $value
}

# Reuse frozen brushes instead of converting the same color strings thousands
# of times while creating/updating image tiles.
function New-FrozenBrush([string]$hex) {
    $color = [System.Windows.Media.ColorConverter]::ConvertFromString($hex)
    $brush = [System.Windows.Media.SolidColorBrush]::new($color)
    if ($brush.CanFreeze) { $brush.Freeze() }
    return $brush
}
$script:BrushTileNormalBg     = New-FrozenBrush '#F7F8FA'
$script:BrushTileNormalBorder = New-FrozenBrush '#E2E6EA'
$script:BrushTileActiveBg     = New-FrozenBrush '#DCEEFF'
$script:BrushTileActiveBorder = New-FrozenBrush '#2B7CD3'
$script:BrushTileLastBg       = New-FrozenBrush '#EEF5FA'
$script:BrushTileLastBorder   = New-FrozenBrush '#A8C8E3'
$script:BrushImageWellBg      = New-FrozenBrush '#ECEFF2'
$script:BrushTileLabel        = New-FrozenBrush '#3C434A'
$script:BrushMutedText        = New-FrozenBrush '#7A838B'

# Shared file-operation actions used by dynamically created context menus.
$script:SetFileClipboardAction = {
    param([string]$Path, [bool]$Cut)
    try {
        $data = New-Object System.Windows.DataObject
        $files = New-Object System.Collections.Specialized.StringCollection
        [void]$files.Add($Path)
        $data.SetFileDropList($files)

        # Explorer understands Preferred DropEffect: 1 = copy, 2 = move/cut.
        [byte[]]$effect = if ($Cut) { 2,0,0,0 } else { 1,0,0,0 }
        $stream = [System.IO.MemoryStream]::new($effect)
        $data.SetData('Preferred DropEffect', $stream)
        [System.Windows.Clipboard]::SetDataObject($data, $true)
        return $true
    } catch {
        [System.Windows.MessageBox]::Show(
            "$(T 'ClipboardError')`r`n`r`n$($_.Exception.Message)",
            (T 'ClipboardErrorTitle'),
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        ) | Out-Null
        return $false
    }
}

$script:SendFileToRecycleBinAction = {
    param([string]$Path)
    try {
        [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile(
            $Path,
            [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
            [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin,
            [Microsoft.VisualBasic.FileIO.UICancelOption]::ThrowException
        )
        return $true
    } catch {
        [System.Windows.MessageBox]::Show(
            "$(T 'FileRecycleError')`r`n`r`n$($_.Exception.Message)",
            (T 'DeleteErrorTitle'),
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        ) | Out-Null
        return $false
    }
}

$script:SendFolderToRecycleBinAction = {
    param([string]$Path)
    try {
        [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory(
            $Path,
            [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
            [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin,
            [Microsoft.VisualBasic.FileIO.UICancelOption]::ThrowException
        )
        return $true
    } catch {
        [System.Windows.MessageBox]::Show(
            "$(T 'FolderRecycleError')`r`n`r`n$($_.Exception.Message)",
            (T 'DeleteErrorTitle'),
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        ) | Out-Null
        return $false
    }
}

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Visual Folder Explorer v0.11.1" Height="820" Width="1420"
        MinHeight="620" MinWidth="980"
        WindowStartupLocation="CenterScreen"
        Background="#F4F6F8" FontFamily="Segoe UI">
    <Window.Resources>
$($script:StyleResourceFragment)
    </Window.Resources>

    <Grid Margin="14">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="12"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <Border Grid.Row="0" Background="White" CornerRadius="12" Padding="10" BorderBrush="#E3E7EA" BorderThickness="1">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>

                <Button x:Name="BackButton" Grid.Column="0" Content="←" Style="{StaticResource NavButton}" ToolTip="Назад"/>
                <Button x:Name="UpButton" Grid.Column="1" Content="↑" Style="{StaticResource NavButton}" ToolTip="На рівень вище"/>
                <Button x:Name="HomeButton" Grid.Column="2" Content="⌂" Style="{StaticResource NavButton}" ToolTip="До кореневої папки"/>

                <Border Grid.Column="3" Background="#F5F7F9" CornerRadius="8" Margin="0,0,10,0" Padding="10,7">
                    <TextBlock x:Name="PathText" Text="Оберіть кореневу папку" Foreground="#4A525A" FontSize="14" TextTrimming="CharacterEllipsis" VerticalAlignment="Center"/>
                </Border>

                <Button x:Name="ChooseRootButton" Grid.Column="4" Content="Обрати папку" Style="{StaticResource ToolbarButton}" Margin="0,0,8,0"/>
                <Button x:Name="MoveImagesButton" Grid.Column="5" Content="Перенести" Style="{StaticResource ToolbarButton}" Margin="0,0,8,0"/>
                <ComboBox x:Name="LanguageCombo" Grid.Column="6" Width="82" Height="34" Style="{StaticResource ModernComboBox}" ToolTip="Language / Мова">
                    <ComboBoxItem Content="UA" Tag="UA"/>
                    <ComboBoxItem Content="EN" Tag="EN"/>
                </ComboBox>

                <Popup x:Name="MoveImagesPopup"
                       PlacementTarget="{Binding ElementName=MoveImagesButton}"
                       Placement="Bottom"
                       HorizontalOffset="0"
                       VerticalOffset="8"
                       AllowsTransparency="True"
                       StaysOpen="True"
                       PopupAnimation="Fade">
                    <Border Style="{StaticResource ModernPopupCard}" Width="610">
                        <Grid>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="14"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="12"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="12"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="16"/>
                                <RowDefinition Height="Auto"/>
                            </Grid.RowDefinitions>
                            <TextBlock x:Name="MovePopupTitle" Grid.Row="0" FontSize="16" FontWeight="SemiBold" Foreground="#1B1F23"/>

                            <Grid Grid.Row="2">
                                <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                                <TextBlock x:Name="MoveSourceLabel" Grid.Row="0" Style="{StaticResource ModernFieldLabel}"/>
                                <Grid Grid.Row="1">
                                    <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                    <TextBox x:Name="MoveSourceTextBox" Grid.Column="0" Height="42" Style="{StaticResource ModernTextBox}"/>
                                    <Button x:Name="MoveSourceBrowseButton" Grid.Column="1" Content="Обрати" Style="{StaticResource ToolbarButton}" Margin="8,0,0,0" MinWidth="82"/>
                                </Grid>
                            </Grid>

                            <Grid Grid.Row="4">
                                <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                                <TextBlock x:Name="MoveDestinationLabel" Grid.Row="0" Style="{StaticResource ModernFieldLabel}"/>
                                <Grid Grid.Row="1">
                                    <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                    <TextBox x:Name="MoveDestinationTextBox" Grid.Column="0" Height="42" Style="{StaticResource ModernTextBox}"/>
                                    <Button x:Name="MoveDestinationBrowseButton" Grid.Column="1" Content="Обрати" Style="{StaticResource ToolbarButton}" Margin="8,0,0,0" MinWidth="82"/>
                                </Grid>
                            </Grid>

                            <TextBlock x:Name="MoveHintText" Grid.Row="6" Foreground="#6D767E" FontSize="12" TextWrapping="Wrap"/>

                            <StackPanel Grid.Row="8" Orientation="Horizontal" HorizontalAlignment="Right">
                                <Button x:Name="MoveCancelButton" Style="{StaticResource ModernDialogSecondaryButton}" Margin="0,0,8,0"/>
                                <Button x:Name="MoveStartButton" Style="{StaticResource ModernDialogPrimaryButton}"/>
                            </StackPanel>
                        </Grid>
                    </Border>
                </Popup>
            </Grid>
        </Border>

        <Grid Grid.Row="2">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="260" MinWidth="190"/>
                <ColumnDefinition Width="8"/>
                <ColumnDefinition Width="*" MinWidth="380"/>
                <ColumnDefinition Width="8"/>
                <ColumnDefinition Width="390" MinWidth="300" MaxWidth="560"/>
            </Grid.ColumnDefinitions>

            <Border Grid.Column="0" Background="White" CornerRadius="12" BorderBrush="#E3E7EA" BorderThickness="1" Padding="12">
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="8"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>
                    <TextBlock x:Name="ExplorerTitleText" Text="Провідник" FontWeight="SemiBold" FontSize="16" Foreground="#1B1F23"/>
                    <ListBox x:Name="FolderList" Grid.Row="2" BorderThickness="0" Background="Transparent" ScrollViewer.HorizontalScrollBarVisibility="Disabled">
                        <ListBox.Resources>
                            <Style TargetType="ScrollBar" BasedOn="{StaticResource ModernVerticalScrollBar}"/>
                        </ListBox.Resources>
                        <ListBox.ItemContainerStyle>
                            <Style TargetType="ListBoxItem">
                                <Setter Property="Padding" Value="8,9"/>
                                <Setter Property="Margin" Value="0,1"/>
                                <Setter Property="Cursor" Value="Hand"/>
                                <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
                                <Setter Property="Template">
                                    <Setter.Value>
                                        <ControlTemplate TargetType="ListBoxItem">
                                            <Border x:Name="Bd" Background="Transparent" CornerRadius="7" Padding="{TemplateBinding Padding}">
                                                <ContentPresenter/>
                                            </Border>
                                            <ControlTemplate.Triggers>
                                                <Trigger Property="IsMouseOver" Value="True">
                                                    <Setter TargetName="Bd" Property="Background" Value="#F1F4F6"/>
                                                </Trigger>
                                                <Trigger Property="IsSelected" Value="True">
                                                    <Setter TargetName="Bd" Property="Background" Value="#E7F0F8"/>
                                                </Trigger>
                                            </ControlTemplate.Triggers>
                                        </ControlTemplate>
                                    </Setter.Value>
                                </Setter>
                            </Style>
                        </ListBox.ItemContainerStyle>
                    </ListBox>
                </Grid>
            </Border>

            <GridSplitter Grid.Column="1" Width="8" HorizontalAlignment="Stretch" Background="Transparent"/>

            <Border Grid.Column="2" Background="White" CornerRadius="12" BorderBrush="#E3E7EA" BorderThickness="1" Padding="12">
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="8"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <TextBlock x:Name="ImagesTitleText" Grid.Column="0" Text="Зображення" FontWeight="SemiBold" FontSize="16" Foreground="#1B1F23" VerticalAlignment="Center"/>
                        <ComboBox x:Name="ImageSortFieldCombo" Grid.Column="2" Width="170" Height="34" Margin="10,0,8,0" VerticalAlignment="Center" Style="{StaticResource ModernComboBox}" ToolTip="Поле сортування">
                            <ComboBoxItem Content="За назвою" Tag="Name"/>
                            <ComboBoxItem Content="За датою зміни" Tag="Modified"/>
                            <ComboBoxItem Content="За датою створення" Tag="Created"/>
                            <ComboBoxItem Content="За розміром" Tag="Size"/>
                        </ComboBox>
                        <ComboBox x:Name="ImageSortDirectionCombo" Grid.Column="3" Width="148" Height="34" Margin="0,0,10,0" VerticalAlignment="Center" Style="{StaticResource ModernComboBox}" ToolTip="Напрям сортування">
                            <ComboBoxItem Content="Звичайне ↑" Tag="Ascending"/>
                            <ComboBoxItem Content="Зворотне ↓" Tag="Descending"/>
                        </ComboBox>
                        <TextBlock x:Name="ImageCountText" Grid.Column="4" Foreground="#7A838B" FontSize="13" VerticalAlignment="Center"/>
                    </Grid>
                    <Grid Grid.Row="2">
                        <ScrollViewer x:Name="ImageScrollViewer" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Background="Transparent">
                            <ScrollViewer.Resources>
                                <Style TargetType="ScrollBar" BasedOn="{StaticResource ModernVerticalScrollBar}"/>
                            </ScrollViewer.Resources>
                            <WrapPanel x:Name="ImagePanel" Orientation="Horizontal" Background="Transparent"/>
                        </ScrollViewer>
                        <Canvas x:Name="ImageScrollMarkerLayer"
                                Margin="0,3,0,3"
                                HorizontalAlignment="Stretch"
                                VerticalAlignment="Stretch"
                                IsHitTestVisible="False"
                                Panel.ZIndex="50">
                            <Border x:Name="ImageScrollMarker"
                                    Width="8"
                                    Height="4"
                                    Background="#2B7CD3"
                                    BorderThickness="0"
                                    CornerRadius="2"
                                    Visibility="Collapsed"/>
                        </Canvas>
                    </Grid>
                </Grid>
            </Border>

            <GridSplitter Grid.Column="3" Width="8" HorizontalAlignment="Stretch" Background="Transparent"/>

            <Border Grid.Column="4" Background="White" CornerRadius="12" BorderBrush="#E3E7EA" BorderThickness="1" Padding="14">
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="8"/>
                        <RowDefinition Height="*"/>
                        <RowDefinition Height="10"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>

                    <Grid Grid.Row="0">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <Button x:Name="ReturnToTextButton" Grid.Row="0" Grid.Column="0" Content="До тексту" Style="{StaticResource ToolbarButton}" Margin="0,0,8,0" Padding="9,5" FontSize="12" Visibility="Collapsed" ToolTip="Повернутися до текстового опису"/>
                        <TextBlock x:Name="SidePanelTitle" Grid.Row="0" Grid.Column="1" Text="Текст" FontWeight="SemiBold" FontSize="16" Foreground="#1B1F23" VerticalAlignment="Center"/>
                        <StackPanel Grid.Row="0" Grid.Column="2" Orientation="Horizontal">
                            <Button x:Name="MarkdownModeButton" Content="Редагувати" Style="{StaticResource ToolbarButton}" Margin="0,0,8,0" Padding="10,5" FontSize="12" Visibility="Collapsed" ToolTip="Перемкнути між переглядом Markdown і редагуванням"/>
                            <Button x:Name="SaveTextButton" Content="Зберегти" Style="{StaticResource ToolbarButton}" Margin="0" Padding="10,5" FontSize="12" IsEnabled="False" ToolTip="Зберегти зміни (Ctrl+S)"/>
                        </StackPanel>
                        <Border Grid.Row="1" Grid.Column="0" Grid.ColumnSpan="3" Margin="0,8,0,0" Padding="9,6" Background="#F5F7F9" CornerRadius="7">
                            <TextBlock x:Name="TextFileName" Foreground="#2F3740" FontSize="13" FontWeight="SemiBold" TextTrimming="CharacterEllipsis" VerticalAlignment="Center" TextAlignment="Left" ToolTip="{Binding Text, RelativeSource={RelativeSource Self}}"/>
                        </Border>
                    </Grid>

                    <Grid Grid.Row="2">
                        <Border x:Name="TextContentBorder" BorderBrush="#E6EAED" BorderThickness="1" CornerRadius="8" Background="#FBFCFD" ClipToBounds="True">
                            <Grid>
                                <TextBox x:Name="TextViewer" BorderThickness="0" Background="Transparent" Padding="12" TextWrapping="Wrap"
                                         AcceptsReturn="True" AcceptsTab="True" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled"
                                         IsReadOnly="True" FontSize="14" Foreground="#252A2E" SpellCheck.IsEnabled="False">
                                    <TextBox.Resources>
                                        <Style TargetType="ScrollBar" BasedOn="{StaticResource ModernVerticalScrollBar}"/>
                                    </TextBox.Resources>
                                </TextBox>
                                <FlowDocumentScrollViewer x:Name="MarkdownViewer" Visibility="Collapsed" IsToolBarVisible="False" Background="Transparent">
                                    <FlowDocumentScrollViewer.Resources>
                                        <Style TargetType="ScrollBar" BasedOn="{StaticResource ModernVerticalScrollBar}"/>
                                    </FlowDocumentScrollViewer.Resources>
                                </FlowDocumentScrollViewer>
                            </Grid>
                        </Border>

                        <Border x:Name="PreviewContentBorder" BorderBrush="#E6EAED" BorderThickness="1" CornerRadius="8" Background="#101214" Visibility="Collapsed" ClipToBounds="True">
                            <Grid>
                                <Image x:Name="PreviewImage" Stretch="Uniform" Margin="8"/>
                                <TextBlock x:Name="PreviewError" Text="Не вдалося відкрити прев'ю." Foreground="White" FontSize="14" HorizontalAlignment="Center" VerticalAlignment="Center" Visibility="Collapsed"/>
                            </Grid>
                        </Border>
                    </Grid>

                    <Grid x:Name="TextNavigationPanel" Grid.Row="4">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <Button x:Name="PrevTextButton" Grid.Column="0" Content="←" Style="{StaticResource NavButton}" ToolTip="Попередній текстовий файл"/>
                        <TextBlock x:Name="TextCounter" Grid.Column="1" HorizontalAlignment="Center" VerticalAlignment="Center" Foreground="#66707A" FontSize="13"/>
                        <Button x:Name="NextTextButton" Grid.Column="2" Content="→" Style="{StaticResource NavButton}" Margin="0" ToolTip="Наступний текстовий файл"/>
                    </Grid>
                </Grid>
            </Border>
        </Grid>

        <TextBlock Grid.Row="3" x:Name="StatusText" Margin="4,10,0,0" Foreground="#6D767E" FontSize="12" Text="Готово"/>
    </Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$BackButton      = $window.FindName('BackButton')
$UpButton        = $window.FindName('UpButton')
$HomeButton      = $window.FindName('HomeButton')
$ChooseRootButton= $window.FindName('ChooseRootButton')
$MoveImagesButton = $window.FindName('MoveImagesButton')
$MoveImagesPopup = $window.FindName('MoveImagesPopup')
$MovePopupTitle = $window.FindName('MovePopupTitle')
$MoveSourceLabel = $window.FindName('MoveSourceLabel')
$MoveDestinationLabel = $window.FindName('MoveDestinationLabel')
$MoveSourceTextBox = $window.FindName('MoveSourceTextBox')
$MoveDestinationTextBox = $window.FindName('MoveDestinationTextBox')
$MoveSourceBrowseButton = $window.FindName('MoveSourceBrowseButton')
$MoveDestinationBrowseButton = $window.FindName('MoveDestinationBrowseButton')
$MoveHintText = $window.FindName('MoveHintText')
$MoveCancelButton = $window.FindName('MoveCancelButton')
$MoveStartButton = $window.FindName('MoveStartButton')
$LanguageCombo   = $window.FindName('LanguageCombo')
$ExplorerTitleText = $window.FindName('ExplorerTitleText')
$ImagesTitleText = $window.FindName('ImagesTitleText')
$PathText        = $window.FindName('PathText')
$FolderList      = $window.FindName('FolderList')
$ImagePanel      = $window.FindName('ImagePanel')
$ImageScrollViewer = $window.FindName('ImageScrollViewer')
$ImageScrollMarkerLayer = $window.FindName('ImageScrollMarkerLayer')
$ImageScrollMarker = $window.FindName('ImageScrollMarker')
$ImageCountText  = $window.FindName('ImageCountText')
$ImageSortFieldCombo = $window.FindName('ImageSortFieldCombo')
$ImageSortDirectionCombo = $window.FindName('ImageSortDirectionCombo')
$TextViewer      = $window.FindName('TextViewer')
$MarkdownViewer  = $window.FindName('MarkdownViewer')
$MarkdownModeButton = $window.FindName('MarkdownModeButton')
$TextFileName    = $window.FindName('TextFileName')
$SaveTextButton  = $window.FindName('SaveTextButton')
$SidePanelTitle  = $window.FindName('SidePanelTitle')
$ReturnToTextButton = $window.FindName('ReturnToTextButton')
$TextContentBorder = $window.FindName('TextContentBorder')
$PreviewContentBorder = $window.FindName('PreviewContentBorder')
$PreviewImage    = $window.FindName('PreviewImage')
$PreviewError    = $window.FindName('PreviewError')
$TextNavigationPanel = $window.FindName('TextNavigationPanel')
$PrevTextButton  = $window.FindName('PrevTextButton')
$NextTextButton  = $window.FindName('NextTextButton')
$TextCounter     = $window.FindName('TextCounter')
$StatusText      = $window.FindName('StatusText')

$script:History = New-Object System.Collections.Generic.List[string]

function Get-NaturalSortKey([string]$name) {
    return [regex]::Replace($name, '\d+', { param($m) $m.Value.PadLeft(12, '0') })
}



function Show-TextInputDialog {
    param(
        [string]$Title,
        [string]$Prompt,
        [string]$DefaultText = ''
    )

    [xml]$dialogXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Dialog"
        SizeToContent="WidthAndHeight"
        MinWidth="460"
        WindowStartupLocation="CenterOwner"
        ResizeMode="NoResize"
        ShowInTaskbar="False"
        Background="#F4F6F8"
        FontFamily="Segoe UI">
    <Window.Resources>
$($script:StyleResourceFragment)
    </Window.Resources>
    <Border Background="White" BorderBrush="#E3E7EA" BorderThickness="1" CornerRadius="12" Padding="18">
        <Grid>
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="14"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="18"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            <TextBlock x:Name="PromptText" Grid.Row="0" TextWrapping="Wrap" Foreground="#2F3740" FontSize="14"/>
            <TextBox x:Name="ValueTextBox" Grid.Row="2" MinWidth="400" Height="38" Style="{StaticResource ModernTextBox}"/>
            <StackPanel Grid.Row="4" Orientation="Horizontal" HorizontalAlignment="Right">
                <Button x:Name="CancelButton" Content="Cancel" Style="{StaticResource DialogSecondaryButton}" Margin="0,0,8,0"/>
                <Button x:Name="OkButton" Content="OK" Style="{StaticResource DialogPrimaryButton}" IsDefault="True"/>
            </StackPanel>
        </Grid>
    </Border>
</Window>
"@

    $dialogReader = New-Object System.Xml.XmlNodeReader $dialogXaml
    $dialog = [Windows.Markup.XamlReader]::Load($dialogReader)
    if ($window) { $dialog.Owner = $window }
    $dialog.Title = $Title

    $promptText = $dialog.FindName('PromptText')
    $valueTextBox = $dialog.FindName('ValueTextBox')
    $okButton = $dialog.FindName('OkButton')
    $cancelButton = $dialog.FindName('CancelButton')
    $okButton.Content = T 'OK'
    $cancelButton.Content = T 'Cancel'

    $promptText.Text = $Prompt
    $valueTextBox.Text = $DefaultText

    $okButton.Add_Click({
        $dialog.DialogResult = $true
        $dialog.Close()
    })
    $cancelButton.Add_Click({
        $dialog.DialogResult = $false
        $dialog.Close()
    })
    $dialog.Add_ContentRendered({
        $valueTextBox.Focus() | Out-Null
        $valueTextBox.SelectAll()
    })
    $valueTextBox.Add_KeyDown({
        if ($_.Key -eq [System.Windows.Input.Key]::Escape) {
            $dialog.DialogResult = $false
            $dialog.Close()
            $_.Handled = $true
        }
    })

    $result = $dialog.ShowDialog()
    if ($result -eq $true) {
        return $valueTextBox.Text
    }
    return $null
}

function Show-ConfirmDialog {
    param(
        [string]$Title,
        [string]$Message,
        [string]$ConfirmText = 'Так',
        [string]$CancelText = 'Ні'
    )

    [xml]$dialogXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Dialog"
        SizeToContent="WidthAndHeight"
        MinWidth="450"
        WindowStartupLocation="CenterOwner"
        ResizeMode="NoResize"
        ShowInTaskbar="False"
        Background="#F4F6F8"
        FontFamily="Segoe UI">
    <Window.Resources>
$($script:StyleResourceFragment)
    </Window.Resources>
    <Border Background="White" BorderBrush="#E3E7EA" BorderThickness="1" CornerRadius="12" Padding="18">
        <Grid>
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="18"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="20"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            <Grid Grid.Row="0">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="14"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>
                <Border Width="38" Height="38" CornerRadius="19" Background="#E8F2FB" VerticalAlignment="Top">
                    <TextBlock Text="?" HorizontalAlignment="Center" VerticalAlignment="Center" FontSize="22" FontWeight="Bold" Foreground="#3D74A8"/>
                </Border>
                <TextBlock x:Name="MessageText" Grid.Column="2" TextWrapping="Wrap" Foreground="#1F262C" FontSize="14" VerticalAlignment="Center"/>
            </Grid>
            <StackPanel Grid.Row="4" Orientation="Horizontal" HorizontalAlignment="Right">
                <Button x:Name="CancelButton" Content="Ні" Style="{StaticResource DialogSecondaryButton}" Margin="0,0,8,0" IsCancel="True"/>
                <Button x:Name="ConfirmButton" Content="Так" Style="{StaticResource DialogPrimaryButton}" IsDefault="True"/>
            </StackPanel>
        </Grid>
    </Border>
</Window>
"@

    $dialogReader = New-Object System.Xml.XmlNodeReader $dialogXaml
    $dialog = [Windows.Markup.XamlReader]::Load($dialogReader)
    if ($window) { $dialog.Owner = $window }
    $dialog.Title = $Title

    $messageText = $dialog.FindName('MessageText')
    $confirmButton = $dialog.FindName('ConfirmButton')
    $cancelButton = $dialog.FindName('CancelButton')
    $messageText.Text = $Message
    $confirmButton.Content = $ConfirmText
    $cancelButton.Content = $CancelText

    $confirmButton.Add_Click({
        $dialog.DialogResult = $true
        $dialog.Close()
    })
    $cancelButton.Add_Click({
        $dialog.DialogResult = $false
        $dialog.Close()
    })

    $result = $dialog.ShowDialog()
    return ($result -eq $true)
}


function Show-UnsavedChangesDialog {
    param([string]$FileName)
    [xml]$dialogXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Dialog" SizeToContent="WidthAndHeight" MinWidth="500" WindowStartupLocation="CenterOwner"
        ResizeMode="NoResize" ShowInTaskbar="False" Background="#F4F6F8" FontFamily="Segoe UI">
    <Window.Resources>
$($script:StyleResourceFragment)
    </Window.Resources>
    <Border Background="White" BorderBrush="#E3E7EA" BorderThickness="1" CornerRadius="12" Padding="20">
        <Grid><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="18"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
            <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="14"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                <Border Width="40" Height="40" CornerRadius="20" Background="#FFF3D9"><TextBlock Text="!" FontSize="22" FontWeight="Bold" Foreground="#9A6A14" HorizontalAlignment="Center" VerticalAlignment="Center"/></Border>
                <TextBlock x:Name="MessageText" Grid.Column="2" MaxWidth="520" TextWrapping="Wrap" Foreground="#1F262C" FontSize="14" VerticalAlignment="Center"/>
            </Grid>
            <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right">
                <Button x:Name="CancelButton" Style="{StaticResource Secondary}" Margin="0,0,8,0" IsCancel="True"/>
                <Button x:Name="DiscardButton" Style="{StaticResource Secondary}" Margin="0,0,8,0"/>
                <Button x:Name="SaveButton" Style="{StaticResource Primary}" IsDefault="True"/>
            </StackPanel>
        </Grid>
    </Border>
</Window>
"@
    $reader = New-Object System.Xml.XmlNodeReader $dialogXaml
    $dialog = [Windows.Markup.XamlReader]::Load($reader)
    if ($window) { $dialog.Owner = $window }
    $dialog.Title = T 'UnsavedTitle'
    $message = $dialog.FindName('MessageText')
    $save = $dialog.FindName('SaveButton')
    $discard = $dialog.FindName('DiscardButton')
    $cancel = $dialog.FindName('CancelButton')
    $message.Text = T 'UnsavedMessage' @($FileName)
    $save.Content = T 'SaveChanges'
    $discard.Content = T 'DiscardChanges'
    $cancel.Content = T 'Cancel'
    $script:UnsavedDialogResult = 'Cancel'
    $save.Add_Click({ $script:UnsavedDialogResult='Save'; $dialog.DialogResult=$true; $dialog.Close() })
    $discard.Add_Click({ $script:UnsavedDialogResult='Discard'; $dialog.DialogResult=$true; $dialog.Close() })
    $cancel.Add_Click({ $script:UnsavedDialogResult='Cancel'; $dialog.DialogResult=$false; $dialog.Close() })
    [void]$dialog.ShowDialog()
    return $script:UnsavedDialogResult
}

function Show-NoticeDialog {
    param(
        [string]$Title,
        [string]$Message,
        [ValidateSet('Info','Warning','Error')][string]$Kind = 'Info'
    )

    $accentBackground = '#E8F2FB'
    $accentForeground = '#3D74A8'
    $symbol = 'i'
    if ($Kind -eq 'Warning') {
        $accentBackground = '#FFF3D9'
        $accentForeground = '#9A6A14'
        $symbol = '!'
    } elseif ($Kind -eq 'Error') {
        $accentBackground = '#FDE8E8'
        $accentForeground = '#B04444'
        $symbol = '!'
    }

    [xml]$dialogXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Dialog" SizeToContent="WidthAndHeight" MinWidth="460" WindowStartupLocation="CenterOwner"
        ResizeMode="NoResize" ShowInTaskbar="False" Background="#F4F6F8" FontFamily="Segoe UI">
    <Window.Resources>
$($script:StyleResourceFragment)
    </Window.Resources>
    <Border Background="White" BorderBrush="#E3E7EA" BorderThickness="1" CornerRadius="12" Padding="20">
        <Grid>
            <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="20"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
            <Grid Grid.Row="0">
                <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="14"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                <Border x:Name="IconBorder" Width="40" Height="40" CornerRadius="20">
                    <TextBlock x:Name="IconText" FontSize="20" FontWeight="Bold" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                </Border>
                <TextBlock x:Name="MessageText" Grid.Column="2" MaxWidth="540" TextWrapping="Wrap" Foreground="#1F262C" FontSize="14" VerticalAlignment="Center"/>
            </Grid>
            <Button x:Name="OkButton" Grid.Row="2" HorizontalAlignment="Right" Style="{StaticResource ModernDialogPrimaryButton}" IsDefault="True"/>
        </Grid>
    </Border>
</Window>
"@
    $reader = New-Object System.Xml.XmlNodeReader $dialogXaml
    $dialog = [Windows.Markup.XamlReader]::Load($reader)
    if ($window) { $dialog.Owner = $window }
    $dialog.Title = $Title
    $dialog.FindName('MessageText').Text = $Message
    $dialog.FindName('IconBorder').Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString($accentBackground)
    $dialog.FindName('IconText').Text = $symbol
    $dialog.FindName('IconText').Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString($accentForeground)
    $ok = $dialog.FindName('OkButton')
    $ok.Content = T 'OK'
    $ok.Add_Click({ $dialog.DialogResult = $true; $dialog.Close() })
    [void]$dialog.ShowDialog()
}

function New-ModernContextMenu {
    $menu = New-Object System.Windows.Controls.ContextMenu
    $menu.Style = $window.FindResource('ModernContextMenu')
    return $menu
}

function New-ModernMenuItem {
    $item = New-Object System.Windows.Controls.MenuItem
    $item.Style = $window.FindResource('ModernMenuItem')
    return $item
}

function New-ModernSeparator {
    $separator = New-Object System.Windows.Controls.Separator
    $separator.Style = $window.FindResource('ModernSeparator')
    return $separator
}


function Update-TextContextMenuState {
    if ($null -eq $script:TextCutMenuItem) { return }
    $hasSelection = ($TextViewer.SelectionLength -gt 0)
    $script:TextCutMenuItem.IsEnabled = (-not $TextViewer.IsReadOnly -and $hasSelection)
    $script:TextCopyMenuItem.IsEnabled = $hasSelection
    $script:TextPasteMenuItem.IsEnabled = (-not $TextViewer.IsReadOnly -and [System.Windows.Clipboard]::ContainsText())
    $script:TextSelectAllMenuItem.IsEnabled = ($TextViewer.Text.Length -gt 0)
}

function Apply-Language {
    $window.Title = "Visual Folder Explorer v$($script:AppVersion)"
    $ChooseRootButton.Content = T 'ChooseFolder'
    $MoveImagesButton.Content = T 'MoveImagesButton'
    $MovePopupTitle.Text = T 'MoveImagesTitle'
    $MoveSourceLabel.Text = T 'MoveSource'
    $MoveDestinationLabel.Text = T 'MoveDestination'
    $MoveSourceBrowseButton.Content = T 'Browse'
    $MoveDestinationBrowseButton.Content = T 'Browse'
    $MoveSourceBrowseButton.ToolTip = T 'MoveSelectSource'
    $MoveDestinationBrowseButton.ToolTip = T 'MoveSelectDestination'
    $MoveHintText.Text = T 'MoveHint'
    $MoveCancelButton.Content = T 'Cancel'
    $MoveStartButton.Content = T 'MoveStart'
    $ExplorerTitleText.Text = T 'Explorer'
    $ImagesTitleText.Text = T 'Images'
    $BackButton.ToolTip = T 'BackTip'
    $UpButton.ToolTip = T 'UpTip'
    $HomeButton.ToolTip = T 'HomeTip'
    if (-not $script:CurrentFolder) { $PathText.Text = T 'PathPlaceholder' }
    $ImageSortFieldCombo.ToolTip = T 'SortFieldTip'
    $ImageSortDirectionCombo.ToolTip = T 'SortDirectionTip'
    $ImageSortFieldCombo.Items[0].Content = T 'SortName'
    $ImageSortFieldCombo.Items[1].Content = T 'SortModified'
    $ImageSortFieldCombo.Items[2].Content = T 'SortCreated'
    $ImageSortFieldCombo.Items[3].Content = T 'SortSize'
    $ImageSortDirectionCombo.Items[0].Content = T 'Ascending'
    $ImageSortDirectionCombo.Items[1].Content = T 'Descending'
    $ReturnToTextButton.Content = T 'BackToText'
    $ReturnToTextButton.ToolTip = T 'ReturnTip'
    $SaveTextButton.Content = T 'Save'
    $SaveTextButton.ToolTip = T 'SaveTip'
    $MarkdownModeButton.Content = if ($script:MarkdownRendered) { T 'Edit' } else { T 'PreviewMode' }
    $MarkdownModeButton.ToolTip = T 'MarkdownTip'
    $PrevTextButton.ToolTip = T 'PreviousTextTip'
    $NextTextButton.ToolTip = T 'NextTextTip'
    $PreviewError.Text = T 'PreviewError'
    $SidePanelTitle.Text = if ($PreviewContentBorder.Visibility -eq 'Visible') { T 'Preview' } else { T 'Text' }
    if ($script:TextDirty) { Set-TextDirty $true }
    if ($script:TextFiles.Count -eq 0 -and $PreviewContentBorder.Visibility -ne 'Visible') { $TextViewer.Text = T 'NoTextFiles' }
    $imageTotal = if ($script:PendingImages.Count -gt 0) { $script:PendingImages.Count } else { $script:ImageTiles.Count }
    $ImageCountText.Text = if ($imageTotal -eq 0) { T 'NoFiles' } elseif ($imageTotal -eq 1) { T 'FilesOne' } else { T 'FilesMany' @($imageTotal) }

    if ($null -ne $pasteMenuItem) { $pasteMenuItem.Header = T 'Paste' }
    if ($null -ne $createFolderMenuItem) { $createFolderMenuItem.Header = T 'CreateFolder' }
    if ($null -ne $createTxtMenuItem) { $createTxtMenuItem.Header = T 'CreateTxt' }
    if ($null -ne $createMdMenuItem) { $createMdMenuItem.Header = T 'CreateMd' }
    if ($null -ne $imagePasteMenuItem) { $imagePasteMenuItem.Header = T 'Paste' }
    if ($null -ne $script:TextCutMenuItem) { $script:TextCutMenuItem.Header = T 'Cut' }
    if ($null -ne $script:TextCopyMenuItem) { $script:TextCopyMenuItem.Header = T 'Copy' }
    if ($null -ne $script:TextPasteMenuItem) { $script:TextPasteMenuItem.Header = T 'Paste' }
    if ($null -ne $script:TextSelectAllMenuItem) { $script:TextSelectAllMenuItem.Header = T 'SelectAll' }

    foreach ($entry in @($script:ImageTiles.GetEnumerator())) { if ($entry.Value) { $entry.Value.ContextMenu = $null } }
    if ($script:CurrentFolder) { Load-Folders $script:CurrentFolder }
}

function New-BitmapImage([string]$path, [int]$decodeWidth = 0) {
    try {
        $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
        $bitmap.BeginInit()
        $bitmap.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $bitmap.CreateOptions = [System.Windows.Media.Imaging.BitmapCreateOptions]::IgnoreImageCache
        if ($decodeWidth -gt 0) { $bitmap.DecodePixelWidth = $decodeWidth }
        $bitmap.UriSource = New-Object System.Uri($path, [System.UriKind]::Absolute)
        $bitmap.EndInit()
        $bitmap.Freeze()
        return $bitmap
    } catch {
        return $null
    }
}


function Get-UniqueDestinationPath {
    param(
        [string]$Destination,
        [bool]$IsDirectory
    )

    if (-not (Test-Path -LiteralPath $Destination)) { return $Destination }

    $directory = [System.IO.Path]::GetDirectoryName($Destination)
    $leaf = [System.IO.Path]::GetFileName($Destination)
    if ($IsDirectory) {
        $baseName = $leaf
        $extension = ''
    } else {
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($leaf)
        $extension = [System.IO.Path]::GetExtension($leaf)
    }

    $counter = 1
    do {
        $candidateName = "${baseName}_$counter$extension"
        $candidate = Join-Path $directory $candidateName
        $counter++
    } while (Test-Path -LiteralPath $candidate)

    return $candidate
}

function Sync-ExplorerSelectionToCurrentText {
    if ($script:TextFiles.Count -eq 0 -or $script:TextIndex -lt 0 -or $script:TextIndex -ge $script:TextFiles.Count) { return }
    $targetPath = $script:TextFiles[$script:TextIndex].FullName

    foreach ($item in @($FolderList.Items)) {
        if ($null -eq $item -or $null -eq $item.Tag) { continue }
        $tag = $item.Tag
        if ($tag.Type -eq 'Text' -and ([string]$tag.Path).Equals($targetPath, [System.StringComparison]::OrdinalIgnoreCase)) {
            $script:SyncingExplorerSelection = $true
            try {
                $FolderList.SelectedItem = $item
                $FolderList.ScrollIntoView($item)
            } finally {
                $script:SyncingExplorerSelection = $false
            }
            break
        }
    }
}

function Find-VisualDescendantByType {
    param(
        [System.Windows.DependencyObject]$Root,
        [Type]$Type,
        [scriptblock]$Predicate = $null
    )

    if ($null -eq $Root) { return $null }
    $count = [System.Windows.Media.VisualTreeHelper]::GetChildrenCount($Root)
    for ($i = 0; $i -lt $count; $i++) {
        $child = [System.Windows.Media.VisualTreeHelper]::GetChild($Root, $i)
        if ($Type.IsInstanceOfType($child)) {
            if ($null -eq $Predicate -or (& $Predicate $child)) { return $child }
        }
        $found = Find-VisualDescendantByType -Root $child -Type $Type -Predicate $Predicate
        if ($null -ne $found) { return $found }
    }
    return $null
}

function Position-ImageScrollMarkerHorizontally {
    if ($null -eq $ImageScrollMarker -or $null -eq $ImageScrollMarkerLayer -or $null -eq $ImageScrollViewer) { return }

    try {
        $verticalBar = Find-VisualDescendantByType -Root $ImageScrollViewer -Type ([System.Windows.Controls.Primitives.ScrollBar]) -Predicate {
            param($control)
            return ($control.Orientation -eq [System.Windows.Controls.Orientation]::Vertical -and $control.Visibility -eq 'Visible')
        }
        if ($null -eq $verticalBar) { return }

        $thumb = Find-VisualDescendantByType -Root $verticalBar -Type ([System.Windows.Controls.Primitives.Thumb])
        if ($null -eq $thumb -or $thumb.ActualWidth -le 0) { return }

        $thumbPoint = $thumb.TranslatePoint([System.Windows.Point]::new(0, 0), $ImageScrollMarkerLayer)
        $markerWidth = [double]$ImageScrollMarker.ActualWidth
        if ($markerWidth -le 0) { $markerWidth = 8.0 }
        $thumbCenterX = [double]$thumbPoint.X + ([double]$thumb.ActualWidth / 2.0)
        [System.Windows.Controls.Canvas]::SetLeft($ImageScrollMarker, ($thumbCenterX - ($markerWidth / 2.0)))
    } catch {
        # Keep UI alive if the scrollbar visual tree changes.
    }
}

function Update-ImageScrollMarker {
    if ($null -eq $ImageScrollMarker -or $null -eq $ImageScrollMarkerLayer) { return }

    if ([string]::IsNullOrWhiteSpace($script:LastSelectedImagePath) -or
        -not $script:ImageTiles.ContainsKey($script:LastSelectedImagePath)) {
        $ImageScrollMarker.Visibility = 'Collapsed'
        return
    }

    $tile = $script:ImageTiles[$script:LastSelectedImagePath]
    if ($null -eq $tile) {
        $ImageScrollMarker.Visibility = 'Collapsed'
        return
    }

    $contentHeight = [double]$ImagePanel.ActualHeight
    $trackHeight = [double]$ImageScrollMarkerLayer.ActualHeight
    if ($contentHeight -le 0 -or $trackHeight -le 0) {
        $ImageScrollMarker.Visibility = 'Collapsed'
        return
    }

    try {
        $point = $tile.TranslatePoint([System.Windows.Point]::new(0, 0), $ImagePanel)
        $tileHeight = [double]$tile.ActualHeight
        if ($tileHeight -le 0) { $tileHeight = [double]$tile.Height }
        $centerY = [double]$point.Y + ($tileHeight / 2.0)
        $ratio = $centerY / $contentHeight
        if ($ratio -lt 0) { $ratio = 0 }
        if ($ratio -gt 1) { $ratio = 1 }

        $markerHeight = [double]$ImageScrollMarker.ActualHeight
        if ($markerHeight -le 0) { $markerHeight = 4.0 }
        $available = [Math]::Max(0.0, $trackHeight - $markerHeight)
        $top = [Math]::Max(0.0, [Math]::Min($available, $ratio * $available))
        [System.Windows.Controls.Canvas]::SetTop($ImageScrollMarker, $top)
        Position-ImageScrollMarkerHorizontally
        $ImageScrollMarker.Visibility = 'Visible'
    } catch {
        $ImageScrollMarker.Visibility = 'Collapsed'
    }
}

function Set-ImageTileVisualState {
    param(
        [System.Windows.Controls.Border]$Tile,
        [string]$Path
    )
    if ($null -eq $Tile) { return }

    $isActivePreview = ($PreviewContentBorder.Visibility -eq 'Visible' -and
        $script:PreviewImagePath -and
        $script:PreviewImagePath.Equals($Path, [System.StringComparison]::OrdinalIgnoreCase))
    $isLastSelected = ($script:LastSelectedImagePath -and
        $script:LastSelectedImagePath.Equals($Path, [System.StringComparison]::OrdinalIgnoreCase))

    if ($isActivePreview) {
        $Tile.Background = $script:BrushTileActiveBg
        $Tile.BorderBrush = $script:BrushTileActiveBorder
        $Tile.BorderThickness = [System.Windows.Thickness]::new(2)
    } elseif ($isLastSelected) {
        $Tile.Background = $script:BrushTileLastBg
        $Tile.BorderBrush = $script:BrushTileLastBorder
        $Tile.BorderThickness = [System.Windows.Thickness]::new(1)
    } else {
        $Tile.Background = $script:BrushTileNormalBg
        $Tile.BorderBrush = $script:BrushTileNormalBorder
        $Tile.BorderThickness = [System.Windows.Thickness]::new(1)
    }
}

function Update-ImageTileSelection {
    foreach ($entry in @($script:ImageTiles.GetEnumerator())) {
        Set-ImageTileVisualState -Tile $entry.Value -Path ([string]$entry.Key)
    }
    Update-ImageScrollMarker
}

function Request-ImageScrollMarkerUpdate {
    # SizeChanged can fire hundreds of times while a large folder is being
    # populated. Coalesce those calls into a single marker update.
    if ($null -eq $script:MarkerUpdateTimer) {
        $script:MarkerUpdateTimer = New-Object System.Windows.Threading.DispatcherTimer
        $script:MarkerUpdateTimer.Interval = [TimeSpan]::FromMilliseconds(70)
        $script:MarkerUpdateTimer.Add_Tick({
            $script:MarkerUpdateTimer.Stop()
            Update-ImageScrollMarker
        })
    }
    $script:MarkerUpdateTimer.Stop()
    $script:MarkerUpdateTimer.Start()
}

function Add-MarkdownInlineContent {
    param(
        [System.Windows.Documents.Paragraph]$Paragraph,
        [string]$Text
    )

    if ($null -eq $Text) { return }
    $pattern = '(\*\*[^*]+\*\*|`[^`]+`|\*[^*]+\*|\[[^\]]+\]\([^)]+\))'
    $matches = [regex]::Matches($Text, $pattern)
    $position = 0

    foreach ($match in $matches) {
        if ($match.Index -gt $position) {
            [void]$Paragraph.Inlines.Add(([System.Windows.Documents.Run]::new($Text.Substring($position, $match.Index - $position))))
        }

        $token = $match.Value
        if ($token.StartsWith('**') -and $token.EndsWith('**')) {
            $run = [System.Windows.Documents.Run]::new($token.Substring(2, $token.Length - 4))
            $run.FontWeight = [System.Windows.FontWeights]::SemiBold
            [void]$Paragraph.Inlines.Add($run)
        } elseif ($token.StartsWith('`') -and $token.EndsWith('`')) {
            $run = [System.Windows.Documents.Run]::new($token.Substring(1, $token.Length - 2))
            $run.FontFamily = [System.Windows.Media.FontFamily]::new('Consolas')
            $run.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#EEF1F4')
            [void]$Paragraph.Inlines.Add($run)
        } elseif ($token.StartsWith('*') -and $token.EndsWith('*')) {
            $run = [System.Windows.Documents.Run]::new($token.Substring(1, $token.Length - 2))
            $run.FontStyle = [System.Windows.FontStyles]::Italic
            [void]$Paragraph.Inlines.Add($run)
        } elseif ($token.StartsWith('[')) {
            $linkMatch = [regex]::Match($token, '^\[([^\]]+)\]\(([^)]+)\)$')
            if ($linkMatch.Success) {
                $run = [System.Windows.Documents.Run]::new($linkMatch.Groups[1].Value)
                $run.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#2563A6')
                $run.TextDecorations = [System.Windows.TextDecorations]::Underline
                $run.ToolTip = $linkMatch.Groups[2].Value
                [void]$Paragraph.Inlines.Add($run)
            } else {
                [void]$Paragraph.Inlines.Add(([System.Windows.Documents.Run]::new($token)))
            }
        } else {
            [void]$Paragraph.Inlines.Add(([System.Windows.Documents.Run]::new($token)))
        }
        $position = $match.Index + $match.Length
    }

    if ($position -lt $Text.Length) {
        [void]$Paragraph.Inlines.Add(([System.Windows.Documents.Run]::new($Text.Substring($position))))
    }
}

function Render-Markdown([string]$markdown) {
    $document = New-Object System.Windows.Documents.FlowDocument
    $document.PagePadding = [System.Windows.Thickness]::new(14)
    $document.FontFamily = [System.Windows.Media.FontFamily]::new('Segoe UI')
    $document.FontSize = 14
    $document.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#252A2E')

    $lines = [regex]::Split([string]$markdown, "\r?\n")
    $inCodeBlock = $false
    $codeLines = New-Object System.Collections.Generic.List[string]

    foreach ($line in $lines) {
        if ($line -match '^\s*```') {
            if ($inCodeBlock) {
                $p = New-Object System.Windows.Documents.Paragraph
                $p.Margin = [System.Windows.Thickness]::new(0,6,0,10)
                $p.Padding = [System.Windows.Thickness]::new(10)
                $p.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#F0F2F4')
                $p.FontFamily = [System.Windows.Media.FontFamily]::new('Consolas')
                [void]$p.Inlines.Add(([System.Windows.Documents.Run]::new(($codeLines -join "`r`n"))))
                [void]$document.Blocks.Add($p)
                $codeLines.Clear()
                $inCodeBlock = $false
            } else {
                $inCodeBlock = $true
            }
            continue
        }

        if ($inCodeBlock) {
            $codeLines.Add($line)
            continue
        }

        if ([string]::IsNullOrWhiteSpace($line)) {
            $spacer = New-Object System.Windows.Documents.Paragraph
            $spacer.Margin = [System.Windows.Thickness]::new(0,0,0,5)
            [void]$document.Blocks.Add($spacer)
            continue
        }

        $heading = [regex]::Match($line, '^(#{1,6})\s+(.+)$')
        if ($heading.Success) {
            $level = $heading.Groups[1].Value.Length
            $sizes = @(28,24,21,18,16,14)
            $p = New-Object System.Windows.Documents.Paragraph
            $p.FontSize = $sizes[$level - 1]
            $p.FontWeight = [System.Windows.FontWeights]::SemiBold
            $p.Margin = [System.Windows.Thickness]::new(0,10,0,6)
            Add-MarkdownInlineContent $p $heading.Groups[2].Value
            [void]$document.Blocks.Add($p)
            continue
        }

        if ($line -match '^\s*(---|\*\*\*|___)\s*$') {
            $border = New-Object System.Windows.Controls.Border
            $border.Height = 1
            $border.Margin = [System.Windows.Thickness]::new(0,9,0,9)
            $border.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#D9DEE3')
            $block = [System.Windows.Documents.BlockUIContainer]::new($border)
            [void]$document.Blocks.Add($block)
            continue
        }

        $bullet = [regex]::Match($line, '^\s*[-+*]\s+(.+)$')
        if ($bullet.Success) {
            $p = New-Object System.Windows.Documents.Paragraph
            $p.Margin = [System.Windows.Thickness]::new(14,2,0,2)
            [void]$p.Inlines.Add(([System.Windows.Documents.Run]::new('•  ')))
            Add-MarkdownInlineContent $p $bullet.Groups[1].Value
            [void]$document.Blocks.Add($p)
            continue
        }

        $ordered = [regex]::Match($line, '^\s*(\d+)\.\s+(.+)$')
        if ($ordered.Success) {
            $p = New-Object System.Windows.Documents.Paragraph
            $p.Margin = [System.Windows.Thickness]::new(14,2,0,2)
            [void]$p.Inlines.Add(([System.Windows.Documents.Run]::new(($ordered.Groups[1].Value + '.  '))))
            Add-MarkdownInlineContent $p $ordered.Groups[2].Value
            [void]$document.Blocks.Add($p)
            continue
        }

        $quote = [regex]::Match($line, '^\s*>\s?(.*)$')
        if ($quote.Success) {
            $p = New-Object System.Windows.Documents.Paragraph
            $p.Margin = [System.Windows.Thickness]::new(8,5,0,5)
            $p.Padding = [System.Windows.Thickness]::new(10,6,8,6)
            $p.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#F3F6F8')
            $p.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#4F5A63')
            Add-MarkdownInlineContent $p $quote.Groups[1].Value
            [void]$document.Blocks.Add($p)
            continue
        }

        $p = New-Object System.Windows.Documents.Paragraph
        $p.Margin = [System.Windows.Thickness]::new(0,2,0,6)
        Add-MarkdownInlineContent $p $line
        [void]$document.Blocks.Add($p)
    }

    if ($inCodeBlock -and $codeLines.Count -gt 0) {
        $p = New-Object System.Windows.Documents.Paragraph
        $p.Padding = [System.Windows.Thickness]::new(10)
        $p.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#F0F2F4')
        $p.FontFamily = [System.Windows.Media.FontFamily]::new('Consolas')
        [void]$p.Inlines.Add(([System.Windows.Documents.Run]::new(($codeLines -join "`r`n"))))
        [void]$document.Blocks.Add($p)
    }

    $MarkdownViewer.Document = $document
}

function Set-MarkdownViewMode([bool]$rendered) {
    if (-not $script:IsCurrentMarkdown) {
        $script:MarkdownRendered = $false
        $MarkdownModeButton.Visibility = 'Collapsed'
        $MarkdownViewer.Visibility = 'Collapsed'
        $TextViewer.Visibility = 'Visible'
        return
    }

    $MarkdownModeButton.Visibility = 'Visible'
    if ($rendered) {
        Render-Markdown $TextViewer.Text
        $TextViewer.Visibility = 'Collapsed'
        $MarkdownViewer.Visibility = 'Visible'
        $MarkdownModeButton.Content = T 'Edit'
        $MarkdownModeButton.ToolTip = T 'MarkdownTip'
        $script:MarkdownRendered = $true
    } else {
        $MarkdownViewer.Visibility = 'Collapsed'
        $TextViewer.Visibility = 'Visible'
        $MarkdownModeButton.Content = T 'PreviewMode'
        $MarkdownModeButton.ToolTip = T 'MarkdownTip'
        $script:MarkdownRendered = $false
        $TextViewer.Focus() | Out-Null
    }
}

function Reset-PreviewTransform {
    $scale = New-Object System.Windows.Media.ScaleTransform
    $scale.ScaleX = 1
    $scale.ScaleY = 1

    $translate = New-Object System.Windows.Media.TranslateTransform
    $translate.X = 0
    $translate.Y = 0

    $group = New-Object System.Windows.Media.TransformGroup
    [void]$group.Children.Add($scale)
    [void]$group.Children.Add($translate)

    $PreviewImage.RenderTransformOrigin = [System.Windows.Point]::new(0.5, 0.5)
    $PreviewImage.RenderTransform = $group
    $PreviewImage.Cursor = [System.Windows.Input.Cursors]::Hand

    $script:PreviewScaleTransform = $scale
    $script:PreviewTranslateTransform = $translate
    $script:PreviewZoomed = $false
    $script:PreviewDragging = $false
    $script:PreviewDragMoved = $false
    $script:PreviewDragOriginX = 0.0
    $script:PreviewDragOriginY = 0.0
}

function Set-PreviewZoom([bool]$zoomed) {
    if ($null -eq $script:PreviewScaleTransform -or $null -eq $script:PreviewTranslateTransform) {
        Reset-PreviewTransform
    }

    if ($zoomed) {
        $script:PreviewScaleTransform.ScaleX = 3
        $script:PreviewScaleTransform.ScaleY = 3
        $script:PreviewTranslateTransform.X = 0
        $script:PreviewTranslateTransform.Y = 0
        $script:PreviewZoomed = $true
        $PreviewImage.Cursor = [System.Windows.Input.Cursors]::SizeAll
    } else {
        Reset-PreviewTransform
    }
}

function Get-ClipboardFileDropInfo {
    try {
        $data = [System.Windows.Clipboard]::GetDataObject()
        if ($null -eq $data -or -not $data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
            return [pscustomobject]@{ HasFiles = $false; Paths = @(); IsCut = $false }
        }

        $paths = @()
        foreach ($clipboardPath in [System.Windows.Clipboard]::GetFileDropList()) {
            $candidate = [string]$clipboardPath
            if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath $candidate)) {
                $paths += $candidate
            }
        }

        $isCut = $false
        if ($paths.Count -gt 0 -and $data.GetDataPresent('Preferred DropEffect')) {
            try {
                $effectData = $data.GetData('Preferred DropEffect')
                [byte[]]$effectBytes = @()
                if ($effectData -is [System.IO.MemoryStream]) {
                    $effectBytes = $effectData.ToArray()
                } elseif ($effectData -is [byte[]]) {
                    $effectBytes = $effectData
                } elseif ($effectData -is [System.IO.Stream]) {
                    $oldPosition = $effectData.Position
                    $effectData.Position = 0
                    $buffer = New-Object byte[] 4
                    $read = $effectData.Read($buffer, 0, 4)
                    $effectData.Position = $oldPosition
                    if ($read -gt 0) { $effectBytes = $buffer }
                }
                if ($effectBytes.Length -gt 0) {
                    $isCut = (($effectBytes[0] -band 2) -eq 2)
                }
            } catch {
                $isCut = $false
            }
        }

        return [pscustomobject]@{ HasFiles = ($paths.Count -gt 0); Paths = @($paths); IsCut = $isCut }
    } catch {
        return [pscustomobject]@{ HasFiles = $false; Paths = @(); IsCut = $false }
    }
}

function Paste-ClipboardItems {
    if (-not $script:CurrentFolder -or -not (Test-Path -LiteralPath $script:CurrentFolder -PathType Container)) { return }

    $clip = Get-ClipboardFileDropInfo
    if (-not $clip.HasFiles) {
        $StatusText.Text = T 'ClipboardEmpty'
        return
    }

    if (-not (Confirm-PendingTextChanges)) { return }

    $previousTextPath = $null
    if ($script:TextFiles.Count -gt 0 -and $script:TextIndex -ge 0 -and $script:TextIndex -lt $script:TextFiles.Count) {
        $previousTextPath = $script:TextFiles[$script:TextIndex].FullName
    }

    $successCount = 0
    $skipCount = 0
    $renamedCount = 0
    $errors = New-Object System.Collections.Generic.List[string]

    foreach ($source in @($clip.Paths)) {
        try {
            if (-not (Test-Path -LiteralPath $source)) { $skipCount++; continue }
            $name = Split-Path -Leaf $source
            $destination = Join-Path $script:CurrentFolder $name
            $sourceIsDirectory = (Test-Path -LiteralPath $source -PathType Container)

            $resolvedSource = (Resolve-Path -LiteralPath $source).Path
            $sameAsDestination = $resolvedSource.Equals($destination, [System.StringComparison]::OrdinalIgnoreCase)
            if ($sameAsDestination -and $clip.IsCut) {
                $skipCount++
                continue
            }

            if (Test-Path -LiteralPath $destination) {
                $destination = Get-UniqueDestinationPath -Destination $destination -IsDirectory $sourceIsDirectory
                $renamedCount++
            }

            if ($sourceIsDirectory) {
                $sourcePrefix = $resolvedSource.TrimEnd('\') + '\'
                $targetResolved = [System.IO.Path]::GetFullPath($script:CurrentFolder).TrimEnd('\') + '\'
                if ($targetResolved.StartsWith($sourcePrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $errors.Add((T 'CannotPasteInside' @($name)))
                    $skipCount++
                    continue
                }
            }

            if ($clip.IsCut) {
                Move-Item -LiteralPath $source -Destination $destination -ErrorAction Stop
            } else {
                if ($sourceIsDirectory) {
                    Copy-Item -LiteralPath $source -Destination $destination -Recurse -ErrorAction Stop
                } else {
                    Copy-Item -LiteralPath $source -Destination $destination -ErrorAction Stop
                }
            }
            $successCount++
        } catch {
            $errors.Add("$([System.IO.Path]::GetFileName([string]$source)): $($_.Exception.Message)")
        }
    }

    if ($successCount -gt 0) {
        Load-Folders $script:CurrentFolder
        Load-Images $script:CurrentFolder
        Load-TextFiles $script:CurrentFolder
        if ($previousTextPath -and (Test-Path -LiteralPath $previousTextPath -PathType Leaf)) {
            Open-TextFileByPath $previousTextPath | Out-Null
        }
        if ($clip.IsCut -and $errors.Count -eq 0 -and $skipCount -eq 0) {
            try { [System.Windows.Clipboard]::Clear() } catch { }
        }
    }

    $actionWord = if ($clip.IsCut) { T 'Moved' } else { T 'Copied' }
    $renameInfo = if ($renamedCount -gt 0) { T 'AutoRenamed' @($renamedCount) } else { '' }
    $StatusText.Text = T 'PasteSummary' @($actionWord, $successCount, $skipCount, $renameInfo)

    if ($errors.Count -gt 0) {
        [System.Windows.MessageBox]::Show(
            "$(T 'PasteIncomplete')`r`n`r`n$($errors -join "`r`n")",
            (T 'PasteTitle'),
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Warning
        ) | Out-Null
    }
}


function Show-ModernFolderPicker {
    param(
        [string]$InitialPath,
        [string]$Title
    )

    [xml]$pickerXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Folder picker"
        Width="760" Height="560"
        MinWidth="620" MinHeight="440"
        WindowStartupLocation="CenterOwner"
        ResizeMode="CanResize"
        ShowInTaskbar="False"
        Background="#F4F6F8"
        FontFamily="Segoe UI">
    <Window.Resources>
$($script:StyleResourceFragment)
    </Window.Resources>
    <Grid Margin="16">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="12"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="12"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="14"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <TextBlock x:Name="PickerTitle" Grid.Row="0" FontSize="18" FontWeight="SemiBold" Foreground="#1B1F23"/>

        <Border Grid.Row="2" Style="{StaticResource ModernPopupCard}" Padding="12">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="8"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="10"/>
                    <ColumnDefinition Width="170"/>
                    <ColumnDefinition Width="10"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>

                <TextBlock x:Name="PathLabel" Grid.Row="0" Grid.Column="0" Style="{StaticResource ModernFieldLabel}"/>
                <TextBlock x:Name="DriveLabel" Grid.Row="0" Grid.Column="2" Style="{StaticResource ModernFieldLabel}"/>

                <TextBox x:Name="PathBox" Grid.Row="2" Grid.Column="0" Height="42" Style="{StaticResource ModernTextBox}"/>
                <ComboBox x:Name="DriveCombo" Grid.Row="2" Grid.Column="2" Height="42" Style="{StaticResource ModernComboBox}"/>
                <Button x:Name="UpButton" Grid.Row="2" Grid.Column="4" MinWidth="92" Height="42" Style="{StaticResource ToolbarButton}" Margin="0"/>
            </Grid>
        </Border>

        <Border Grid.Row="4" Background="White" BorderBrush="#E3E7EA" BorderThickness="1" CornerRadius="12" Padding="8">
            <Grid>
                <ListBox x:Name="FolderList" BorderThickness="0" Background="Transparent" ScrollViewer.HorizontalScrollBarVisibility="Disabled"/>
                <TextBlock x:Name="EmptyText" HorizontalAlignment="Center" VerticalAlignment="Center" Foreground="#7A838B" FontSize="13" Visibility="Collapsed"/>
            </Grid>
        </Border>

        <Grid Grid.Row="6">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <TextBlock x:Name="SelectionHint" Grid.Column="0" VerticalAlignment="Center" Foreground="#6D767E" FontSize="12" TextTrimming="CharacterEllipsis" Margin="2,0,12,0"/>
            <Button x:Name="CancelButton" Grid.Column="1" Style="{StaticResource ModernDialogSecondaryButton}" Margin="0,0,8,0"/>
            <Button x:Name="SelectButton" Grid.Column="2" Style="{StaticResource ModernDialogPrimaryButton}" IsDefault="True"/>
        </Grid>
    </Grid>
</Window>
"@

    $pickerReader = New-Object System.Xml.XmlNodeReader $pickerXaml
    $picker = [Windows.Markup.XamlReader]::Load($pickerReader)
    if ($window) { $picker.Owner = $window }
    $picker.Title = $Title

    $pickerTitle = $picker.FindName('PickerTitle')
    $pathLabel = $picker.FindName('PathLabel')
    $driveLabel = $picker.FindName('DriveLabel')
    $pathBox = $picker.FindName('PathBox')
    $driveCombo = $picker.FindName('DriveCombo')
    $upButton = $picker.FindName('UpButton')
    $folderList = $picker.FindName('FolderList')
    $emptyText = $picker.FindName('EmptyText')
    $selectionHint = $picker.FindName('SelectionHint')
    $cancelButton = $picker.FindName('CancelButton')
    $selectButton = $picker.FindName('SelectButton')

    $pickerTitle.Text = $Title
    $pathLabel.Text = T 'FolderPickerPath'
    $driveLabel.Text = T 'FolderPickerDrives'
    $upButton.Content = T 'FolderPickerUp'
    $emptyText.Text = T 'FolderPickerEmpty'
    $cancelButton.Content = T 'Cancel'
    $selectButton.Content = T 'FolderPickerSelect'

    $script:PickerCurrentPath = ''
    $script:PickerSelectedPath = ''
    $script:PickerUpdatingDrive = $false

    foreach ($drive in @(Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue | Sort-Object Name)) {
        if ([string]::IsNullOrWhiteSpace($drive.Root)) { continue }
        $item = New-Object System.Windows.Controls.ComboBoxItem
        $item.Content = if ([string]::IsNullOrWhiteSpace($drive.Name)) { $drive.Root } else { "$($drive.Name):\" }
        $item.Tag = $drive.Root
        [void]$driveCombo.Items.Add($item)
    }

    $refreshPicker = {
        param([string]$Path)
        try {
            if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Container)) { return $false }
            $resolved = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
            $script:PickerCurrentPath = $resolved
            $script:PickerSelectedPath = $resolved
            $pathBox.Text = $resolved
            $selectionHint.Text = $resolved
            $folderList.Items.Clear()

            $folders = @(Get-ChildItem -LiteralPath $resolved -Directory -ErrorAction SilentlyContinue | Sort-Object Name)
            foreach ($folder in $folders) {
                $item = New-Object System.Windows.Controls.ListBoxItem
                $item.Content = $folder.Name
                $item.Tag = $folder.FullName
                $item.Style = $window.FindResource('ModernExplorerItem')
                $item.ToolTip = $folder.FullName
                [void]$folderList.Items.Add($item)
            }
            $emptyText.Visibility = if ($folders.Count -eq 0) { 'Visible' } else { 'Collapsed' }

            $script:PickerUpdatingDrive = $true
            try {
                for ($i = 0; $i -lt $driveCombo.Items.Count; $i++) {
                    $root = [string]$driveCombo.Items[$i].Tag
                    if (-not [string]::IsNullOrWhiteSpace($root) -and $resolved.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
                        $driveCombo.SelectedIndex = $i
                        break
                    }
                }
            } finally {
                $script:PickerUpdatingDrive = $false
            }
            return $true
        } catch {
            Show-NoticeDialog -Title $Title -Message (T 'FolderPickerInvalid') -Kind 'Warning'
            return $false
        }
    }

    $folderList.Add_SelectionChanged({
        if ($null -ne $folderList.SelectedItem) {
            $script:PickerSelectedPath = [string]$folderList.SelectedItem.Tag
            $selectionHint.Text = $script:PickerSelectedPath
        } else {
            $script:PickerSelectedPath = $script:PickerCurrentPath
            $selectionHint.Text = $script:PickerCurrentPath
        }
    })

    $folderList.Add_MouseDoubleClick({
        if ($null -ne $folderList.SelectedItem) {
            & $refreshPicker ([string]$folderList.SelectedItem.Tag) | Out-Null
        }
    })

    $upButton.Add_Click({
        if ([string]::IsNullOrWhiteSpace($script:PickerCurrentPath)) { return }
        $parent = Split-Path -Parent $script:PickerCurrentPath
        if (-not [string]::IsNullOrWhiteSpace($parent) -and (Test-Path -LiteralPath $parent -PathType Container)) {
            & $refreshPicker $parent | Out-Null
        }
    })

    $driveCombo.Add_SelectionChanged({
        if ($script:PickerUpdatingDrive -or $null -eq $driveCombo.SelectedItem) { return }
        $root = [string]$driveCombo.SelectedItem.Tag
        if (-not [string]::IsNullOrWhiteSpace($root)) { & $refreshPicker $root | Out-Null }
    })

    $pathBox.Add_KeyDown({
        if ($_.Key -eq [System.Windows.Input.Key]::Enter) {
            & $refreshPicker $pathBox.Text.Trim() | Out-Null
            $_.Handled = $true
        }
    })

    $cancelButton.Add_Click({
        $picker.DialogResult = $false
        $picker.Close()
    })
    $selectButton.Add_Click({
        $candidate = if (-not [string]::IsNullOrWhiteSpace($script:PickerSelectedPath)) { $script:PickerSelectedPath } else { $script:PickerCurrentPath }
        if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath $candidate -PathType Container)) {
            $picker.Tag = (Resolve-Path -LiteralPath $candidate).Path
            $picker.DialogResult = $true
            $picker.Close()
        }
    })

    $startPath = $InitialPath
    if ([string]::IsNullOrWhiteSpace($startPath) -or -not (Test-Path -LiteralPath $startPath -PathType Container)) {
        $startPath = if ($script:CurrentFolder -and (Test-Path -LiteralPath $script:CurrentFolder -PathType Container)) { $script:CurrentFolder } elseif ($script:RootFolder -and (Test-Path -LiteralPath $script:RootFolder -PathType Container)) { $script:RootFolder } else { [Environment]::GetFolderPath('MyDocuments') }
    }
    & $refreshPicker $startPath | Out-Null

    $result = $picker.ShowDialog()
    if ($result -eq $true -and $picker.Tag) { return [string]$picker.Tag }
    return $null
}

function Select-MoveFolder {
    param(
        [System.Windows.Controls.TextBox]$TargetTextBox,
        [string]$DescriptionKey
    )
    $selected = Show-ModernFolderPicker -InitialPath $TargetTextBox.Text -Title (T $DescriptionKey)
    if (-not [string]::IsNullOrWhiteSpace($selected)) {
        $TargetTextBox.Text = $selected
        $TargetTextBox.CaretIndex = $TargetTextBox.Text.Length
        $TargetTextBox.ScrollToHorizontalOffset([double]::MaxValue)
    }
}

function Open-MoveImagesPopup {
    $source = if ($script:CurrentFolder -and (Test-Path -LiteralPath $script:CurrentFolder -PathType Container)) { $script:CurrentFolder } elseif ($script:RootFolder) { $script:RootFolder } else { '' }
    $MoveSourceTextBox.Text = $source
    $MoveDestinationTextBox.Text = $script:LastMoveDestination
    $MoveImagesPopup.IsOpen = $true
    $MoveDestinationTextBox.Focus() | Out-Null
}

function Move-ImagesBetweenFolders {
    $source = $MoveSourceTextBox.Text.Trim()
    $destination = $MoveDestinationTextBox.Text.Trim()

    if ([string]::IsNullOrWhiteSpace($source) -or -not (Test-Path -LiteralPath $source -PathType Container)) {
        Show-NoticeDialog -Title (T 'MoveImagesTitle') -Message (T 'MoveSourceMissing') -Kind 'Warning'
        return
    }
    if ([string]::IsNullOrWhiteSpace($destination)) {
        Show-NoticeDialog -Title (T 'MoveImagesTitle') -Message (T 'MoveDestinationRequired') -Kind 'Warning'
        return
    }

    $sourceFull = [System.IO.Path]::GetFullPath($source).TrimEnd('\')
    $destinationFull = [System.IO.Path]::GetFullPath($destination).TrimEnd('\')
    if ($sourceFull.Equals($destinationFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        Show-NoticeDialog -Title (T 'MoveImagesTitle') -Message (T 'MoveSameFolder') -Kind 'Warning'
        return
    }

    try {
        if (-not (Test-Path -LiteralPath $destinationFull -PathType Container)) {
            New-Item -ItemType Directory -Path $destinationFull -Force -ErrorAction Stop | Out-Null
        }

        $files = @(Get-ChildItem -LiteralPath $sourceFull -File -ErrorAction Stop | Where-Object {
            $script:ImageExtensions -contains $_.Extension.ToLowerInvariant()
        } | Sort-Object Name)

        if ($files.Count -eq 0) {
            $StatusText.Text = T 'MoveNoImages'
            $MoveImagesPopup.IsOpen = $false
            return
        }

        $moved = 0
        $renamed = 0
        foreach ($file in $files) {
            $desired = Join-Path $destinationFull $file.Name
            $target = Get-UniqueDestinationPath -Destination $desired -IsDirectory $false
            if (-not $target.Equals($desired, [System.StringComparison]::OrdinalIgnoreCase)) { $renamed++ }
            Move-Item -LiteralPath $file.FullName -Destination $target -ErrorAction Stop
            $moved++
        }

        if ($moved -gt 0) {
            $script:LastMoveDestination = $destinationFull
            Save-Settings
            if ($script:CurrentFolder -and ($script:CurrentFolder.Equals($sourceFull, [System.StringComparison]::OrdinalIgnoreCase) -or $script:CurrentFolder.Equals($destinationFull, [System.StringComparison]::OrdinalIgnoreCase))) {
                Load-Images $script:CurrentFolder
            }
        }

        $StatusText.Text = T 'MoveComplete' @($moved, $renamed)
        $MoveImagesPopup.IsOpen = $false
    } catch {
        Show-NoticeDialog -Title (T 'MoveImagesTitle') -Message "$(T 'MoveError')`r`n`r`n$($_.Exception.Message)" -Kind 'Error'
    }
}

function Save-Settings {
    try {
        if (-not (Test-Path -LiteralPath $script:SettingsFolder -PathType Container)) {
            New-Item -ItemType Directory -Path $script:SettingsFolder -Force | Out-Null
        }

        # Save the user-selected window size. If the window is maximized,
        # RestoreBounds contains the size it had before maximizing.
        if ($window.WindowState -eq [System.Windows.WindowState]::Maximized) {
            $savedWindowWidth = $window.RestoreBounds.Width
            $savedWindowHeight = $window.RestoreBounds.Height
            $savedWindowState = 'Maximized'
        } else {
            $savedWindowWidth = $window.ActualWidth
            $savedWindowHeight = $window.ActualHeight
            $savedWindowState = 'Normal'
        }

        $settings = [ordered]@{
            Version = $script:AppVersion
            RootFolder = $script:RootFolder
            CurrentFolder = $script:CurrentFolder
            History = @($script:History)
            WindowWidth = [math]::Round($savedWindowWidth, 2)
            WindowHeight = [math]::Round($savedWindowHeight, 2)
            WindowState = $savedWindowState
            ImageSortField = $script:ImageSortField
            ImageSortDescending = $script:ImageSortDescending
            Language = $script:Language
            LastMoveDestination = $script:LastMoveDestination
        }
        $settings | ConvertTo-Json | Set-Content -LiteralPath $script:SettingsPath -Encoding UTF8 -Force
    } catch {
        # Налаштування не повинні заважати основній роботі програми.
    }
}

function Load-Settings {
    try {
        if (-not (Test-Path -LiteralPath $script:SettingsPath -PathType Leaf)) { return $false }
        $raw = Get-Content -LiteralPath $script:SettingsPath -Raw -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($raw)) { return $false }
        $saved = $raw | ConvertFrom-Json -ErrorAction Stop

        $savedRoot = [string]$saved.RootFolder
        $savedCurrent = [string]$saved.CurrentFolder

        # Restore the last window size before the window is shown. Old settings
        # files without these fields remain fully compatible.
        try {
            $savedWidth = [double]$saved.WindowWidth
            if ($savedWidth -ge $window.MinWidth) { $window.Width = $savedWidth }
        } catch { }
        try {
            $savedHeight = [double]$saved.WindowHeight
            if ($savedHeight -ge $window.MinHeight) { $window.Height = $savedHeight }
        } catch { }
        if ([string]$saved.WindowState -eq 'Maximized') {
            $window.WindowState = [System.Windows.WindowState]::Maximized
        } else {
            $window.WindowState = [System.Windows.WindowState]::Normal
        }

        $savedSortField = [string]$saved.ImageSortField
        if ($savedSortField -in @('Name', 'Modified', 'Created', 'Size')) {
            $script:ImageSortField = $savedSortField
        }
        try { $script:ImageSortDescending = [System.Convert]::ToBoolean($saved.ImageSortDescending) } catch { }
        $savedLanguage = [string]$saved.Language
        if ($savedLanguage -in @('UA','EN')) { $script:Language = $savedLanguage }
        $savedMoveDestination = [string]$saved.LastMoveDestination
        if (-not [string]::IsNullOrWhiteSpace($savedMoveDestination)) { $script:LastMoveDestination = $savedMoveDestination }

        if ([string]::IsNullOrWhiteSpace($savedRoot) -or -not (Test-Path -LiteralPath $savedRoot -PathType Container)) {
            return $false
        }

        $script:RootFolder = (Resolve-Path -LiteralPath $savedRoot).Path

        # The last opened folder is restored even if the user navigated above the
        # original home/root folder. This makes the app behave more like Explorer.
        if (-not [string]::IsNullOrWhiteSpace($savedCurrent) -and (Test-Path -LiteralPath $savedCurrent -PathType Container)) {
            $script:CurrentFolder = (Resolve-Path -LiteralPath $savedCurrent).Path
        }

        if (-not $script:CurrentFolder) { $script:CurrentFolder = $script:RootFolder }

        # Restore navigation history so the Back button is usable immediately.
        $script:History.Clear()
        if ($null -ne $saved.History) {
            foreach ($historyPath in @($saved.History)) {
                $candidate = [string]$historyPath
                if (-not [string]::IsNullOrWhiteSpace($candidate) -and
                    (Test-Path -LiteralPath $candidate -PathType Container)) {
                    $resolvedCandidate = (Resolve-Path -LiteralPath $candidate).Path
                    if (-not $resolvedCandidate.Equals($script:CurrentFolder, [System.StringComparison]::OrdinalIgnoreCase)) {
                        $script:History.Add($resolvedCandidate)
                    }
                }
            }
        }
        return $true
    } catch {
        return $false
    }
}

function Get-TextFileData([string]$path) {
    $bytes = [System.IO.File]::ReadAllBytes($path)
    $encoding = $null
    $offset = 0

    if ($bytes.Length -ge 4 -and $bytes[0] -eq 0x00 -and $bytes[1] -eq 0x00 -and $bytes[2] -eq 0xFE -and $bytes[3] -eq 0xFF) {
        $encoding = [System.Text.UTF32Encoding]::new($true, $true)
        $offset = 4
    } elseif ($bytes.Length -ge 4 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE -and $bytes[2] -eq 0x00 -and $bytes[3] -eq 0x00) {
        $encoding = [System.Text.UTF32Encoding]::new($false, $true)
        $offset = 4
    } elseif ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        $encoding = [System.Text.UTF8Encoding]::new($true)
        $offset = 3
    } elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) {
        $encoding = [System.Text.Encoding]::BigEndianUnicode
        $offset = 2
    } elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
        $encoding = [System.Text.Encoding]::Unicode
        $offset = 2
    } else {
        try {
            $strictUtf8 = [System.Text.UTF8Encoding]::new($false, $true)
            [void]$strictUtf8.GetString($bytes)
            $encoding = [System.Text.UTF8Encoding]::new($false)
        } catch {
            $encoding = [System.Text.Encoding]::Default
        }
    }

    $length = $bytes.Length - $offset
    if ($length -lt 0) { $length = 0 }
    $text = $encoding.GetString($bytes, $offset, $length)
    return [pscustomobject]@{ Text = $text; Encoding = $encoding }
}

function Set-TextDirty([bool]$dirty) {
    $script:TextDirty = $dirty
    $hasFile = ($script:TextFiles.Count -gt 0 -and $script:TextIndex -ge 0 -and $script:TextIndex -lt $script:TextFiles.Count)
    $SaveTextButton.IsEnabled = ($dirty -and $hasFile)

    if ($hasFile) {
        $name = $script:TextFiles[$script:TextIndex].Name
        $TextFileName.Text = if ($dirty) { "$name  • $(T 'UnsavedMark')" } else { $name }
    } elseif ($PreviewContentBorder.Visibility -ne 'Visible') {
        $TextFileName.Text = ''
    }
}

function Save-CurrentTextFile {
    if ($script:TextFiles.Count -eq 0 -or $script:TextIndex -lt 0 -or $script:TextIndex -ge $script:TextFiles.Count) {
        return $false
    }

    $file = $script:TextFiles[$script:TextIndex]
    try {
        $encoding = $script:CurrentTextEncoding
        if ($null -eq $encoding) { $encoding = [System.Text.UTF8Encoding]::new($false) }
        [System.IO.File]::WriteAllText($file.FullName, $TextViewer.Text, $encoding)
        Set-TextDirty $false
        $StatusText.Text = T 'Saved' @($file.Name)
        return $true
    } catch {
        [System.Windows.MessageBox]::Show(
            "$(T 'SaveError')`r`n$($file.FullName)`r`n`r`n$($_.Exception.Message)",
            (T 'SaveErrorTitle'),
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        ) | Out-Null
        return $false
    }
}

function Confirm-PendingTextChanges {
    if (-not $script:TextDirty) { return $true }
    if ($script:TextFiles.Count -eq 0 -or $script:TextIndex -lt 0) { return $true }
    $file = $script:TextFiles[$script:TextIndex]
    $choice = Show-UnsavedChangesDialog -FileName $file.Name
    if ($choice -eq 'Save') { return (Save-CurrentTextFile) }
    if ($choice -eq 'Discard') { return $true }
    return $false
}

function Show-TextMode {
    if ($script:PreviewImagePath) {
        $script:LastSelectedImagePath = $script:PreviewImagePath
    }
    $TextContentBorder.Visibility = 'Visible'
    $PreviewContentBorder.Visibility = 'Collapsed'
    $TextNavigationPanel.Visibility = 'Visible'
    $ReturnToTextButton.Visibility = 'Collapsed'
    $SaveTextButton.Visibility = 'Visible'
    $SidePanelTitle.Text = T 'Text'
    $PreviewImage.Source = $null
    Reset-PreviewTransform
    $script:PreviewImagePath = $null
    $PreviewError.Visibility = 'Collapsed'
    Update-ImageTileSelection
    if ($script:TextFiles.Count -gt 0 -and $script:TextIndex -ge 0) {
        Set-TextDirty $script:TextDirty
        if ($script:IsCurrentMarkdown) {
            Set-MarkdownViewMode $script:MarkdownRendered
        } else {
            Set-MarkdownViewMode $false
        }
    } else {
        $TextFileName.Text = ''
        $script:IsCurrentMarkdown = $false
        Set-MarkdownViewMode $false
    }
}

function Update-TextNavigation {
    $count = $script:TextFiles.Count
    $script:IsLoadingText = $true
    try {
        if ($count -eq 0) {
            $TextViewer.IsReadOnly = $true
            $TextViewer.Text = T 'NoTextFiles'
            $script:IsCurrentMarkdown = $false
            Set-MarkdownViewMode $false
            $TextFileName.Text = ''
            $TextCounter.Text = '0 / 0'
Reset-PreviewTransform
            $PrevTextButton.IsEnabled = $false
            $NextTextButton.IsEnabled = $false
            $script:CurrentTextEncoding = [System.Text.UTF8Encoding]::new($false)
            Set-TextDirty $false
            return
        }

        if ($script:TextIndex -lt 0) { $script:TextIndex = 0 }
        if ($script:TextIndex -ge $count) { $script:TextIndex = $count - 1 }

        $file = $script:TextFiles[$script:TextIndex]
        $script:IsCurrentMarkdown = ($file.Extension -ieq '.md')
        try {
            $data = Get-TextFileData $file.FullName
            $TextViewer.Text = $data.Text
            $script:CurrentTextEncoding = $data.Encoding
            $TextViewer.IsReadOnly = $false
        } catch {
            $TextViewer.Text = "$(T 'ReadFileError')`r`n`r`n$($_.Exception.Message)"
            $TextViewer.IsReadOnly = $true
            $script:CurrentTextEncoding = [System.Text.UTF8Encoding]::new($false)
        }

        $TextCounter.Text = "{0} / {1}" -f ($script:TextIndex + 1), $count
        $PrevTextButton.IsEnabled = ($count -gt 1)
        $NextTextButton.IsEnabled = ($count -gt 1)
        if ($script:IsCurrentMarkdown) {
            Set-MarkdownViewMode $true
        } else {
            Set-MarkdownViewMode $false
        }
        Set-TextDirty $false
        Sync-ExplorerSelectionToCurrentText
    } finally {
        $script:IsLoadingText = $false
    }
}

function Load-TextFiles([string]$folder, [object[]]$entries = $null) {
    $script:TextFiles = @()
    $script:TextIndex = -1

    try {
        if ($null -eq $entries) { $entries = @(Get-ChildItem -LiteralPath $folder -ErrorAction Stop) }
        $files = @($entries | Where-Object {
            $_ -is [System.IO.FileInfo] -and ($_.Extension -ieq '.txt' -or $_.Extension -ieq '.md')
        })
        if ($files.Count -gt 0) {
            $folderName = Split-Path -Leaf $folder
            $preferredTxt = "$folderName`_текст.txt"
            $preferredMd = "$folderName`_текст.md"
            $script:TextFiles = @($files | Sort-Object @{ Expression = {
                if ($_.Name -ieq $preferredTxt) { 0 }
                elseif ($_.Name -ieq $preferredMd) { 1 }
                else { 2 }
            } }, @{ Expression = { Get-NaturalSortKey $_.Name } })
            $script:TextIndex = 0
        }
    } catch {
        $StatusText.Text = "$(T 'TextReadError'): $($_.Exception.Message)"
    }

    Update-TextNavigation
}

function Open-TextFileByPath([string]$path) {
    if ([string]::IsNullOrWhiteSpace($path) -or -not (Test-Path -LiteralPath $path -PathType Leaf)) { return $false }

    $targetIndex = -1
    for ($i = 0; $i -lt $script:TextFiles.Count; $i++) {
        if ($script:TextFiles[$i].FullName.Equals($path, [System.StringComparison]::OrdinalIgnoreCase)) {
            $targetIndex = $i
            break
        }
    }

    if ($targetIndex -lt 0) {
        Load-TextFiles $script:CurrentFolder
        for ($i = 0; $i -lt $script:TextFiles.Count; $i++) {
            if ($script:TextFiles[$i].FullName.Equals($path, [System.StringComparison]::OrdinalIgnoreCase)) {
                $targetIndex = $i
                break
            }
        }
    }

    if ($targetIndex -lt 0) { return $false }
    if ($targetIndex -ne $script:TextIndex -and -not (Confirm-PendingTextChanges)) { return $false }

    $script:TextIndex = $targetIndex
    Update-TextNavigation
    Show-TextMode
    $StatusText.Text = T 'OpenedText' @([System.IO.Path]::GetFileName($path))
    return $true
}

function New-ImageTileContextMenu([string]$path) {
    $menu = New-ModernContextMenu

    $cut = New-ModernMenuItem
    $cut.Header = T 'Cut'
    $cut.Tag = $path
    $cut.Add_Click($script:ImageCutHandler)
    [void]$menu.Items.Add($cut)

    $copy = New-ModernMenuItem
    $copy.Header = T 'Copy'
    $copy.Tag = $path
    $copy.Add_Click($script:ImageCopyHandler)
    [void]$menu.Items.Add($copy)

    [void]$menu.Items.Add((New-ModernSeparator))

    $rename = New-ModernMenuItem
    $rename.Header = T 'Rename'
    $rename.Tag = $path
    $rename.Add_Click($script:ImageRenameHandler)
    [void]$menu.Items.Add($rename)

    $delete = New-ModernMenuItem
    $delete.Header = T 'Delete'
    $delete.Tag = $path
    $delete.Add_Click($script:ImageDeleteHandler)
    [void]$menu.Items.Add($delete)

    return $menu
}

function Add-ImageTile([System.IO.FileInfo]$file) {
    $tile = New-Object System.Windows.Controls.Border
    $tile.Width = 190
    $tile.Height = 178
    $tile.Margin = '0,0,12,12'
    $tile.Background = $script:BrushTileNormalBg
    $tile.BorderBrush = $script:BrushTileNormalBorder
    $tile.BorderThickness = 1
    $tile.CornerRadius = 10
    $tile.Cursor = [System.Windows.Input.Cursors]::Hand
    $tile.ToolTip = $file.Name
    $tile.Tag = $file.FullName

    $grid = New-Object System.Windows.Controls.Grid
    $grid.Margin = 7
    $row1 = New-Object System.Windows.Controls.RowDefinition
    $row1.Height = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
    $grid.RowDefinitions.Add($row1)
    $row2 = New-Object System.Windows.Controls.RowDefinition
    $row2.Height = [System.Windows.GridLength]::Auto
    $grid.RowDefinitions.Add($row2)

    $imageBorder = New-Object System.Windows.Controls.Border
    $imageBorder.Background = $script:BrushImageWellBg
    $imageBorder.CornerRadius = 7
    $imageBorder.ClipToBounds = $true

    $img = New-Object System.Windows.Controls.Image
    $img.Stretch = 'Uniform'
    $img.HorizontalAlignment = 'Stretch'
    $img.VerticalAlignment = 'Stretch'

    # 240 px is already larger than the visible tile image area.  The previous
    # 420 px thumbnails consumed much more CPU and memory for no visible gain.
    $bitmap = New-BitmapImage $file.FullName $script:ImageThumbnailDecodeWidth
    if ($null -ne $bitmap) {
        $img.Source = $bitmap
    } else {
        $fallback = New-Object System.Windows.Controls.TextBlock
        $fallback.Text = if ($script:Language -eq 'EN') { "No`npreview" } else { "Немає`nпрев'ю" }
        $fallback.TextAlignment = 'Center'
        $fallback.HorizontalAlignment = 'Center'
        $fallback.VerticalAlignment = 'Center'
        $fallback.Foreground = $script:BrushMutedText
        $imageBorder.Child = $fallback
    }

    if ($null -eq $imageBorder.Child) { $imageBorder.Child = $img }
    [System.Windows.Controls.Grid]::SetRow($imageBorder, 0)
    $grid.Children.Add($imageBorder) | Out-Null

    $label = New-Object System.Windows.Controls.TextBlock
    $label.Text = $file.Name
    $label.Margin = '3,7,3,0'
    $label.FontSize = 12
    $label.Foreground = $script:BrushTileLabel
    $label.TextTrimming = 'CharacterEllipsis'
    $label.HorizontalAlignment = 'Stretch'
    [System.Windows.Controls.Grid]::SetRow($label, 1)
    $grid.Children.Add($label) | Out-Null

    $tile.Child = $grid
    $tile.Add_MouseLeftButtonUp($script:ImageTileClickHandler)
    # Context menus are expensive WPF object trees. Build one only if the user
    # actually right-clicks this tile instead of creating 1,000 of them upfront.
    $tile.Add_PreviewMouseRightButtonDown($script:ImageTileContextMenuHandler)

    $ImagePanel.Children.Add($tile) | Out-Null
    $script:ImageTiles[$file.FullName] = $tile
    Set-ImageTileVisualState -Tile $tile -Path $file.FullName
}

function Get-SortedImages([string]$folder, [object[]]$entries = $null) {
    if ($null -eq $entries) {
        $images = @(Get-ChildItem -LiteralPath $folder -File -ErrorAction Stop | Where-Object {
            $script:ImageExtensions -contains $_.Extension.ToLowerInvariant()
        })
    } else {
        $images = @($entries | Where-Object {
            $_ -is [System.IO.FileInfo] -and $script:ImageExtensions -contains $_.Extension.ToLowerInvariant()
        })
    }

    $descending = [bool]$script:ImageSortDescending
    switch ($script:ImageSortField) {
        'Modified' {
            return @($images | Sort-Object @{ Expression = { $_.LastWriteTime }; Descending = $descending }, @{ Expression = { Get-NaturalSortKey $_.Name }; Descending = $false })
        }
        'Created' {
            return @($images | Sort-Object @{ Expression = { $_.CreationTime }; Descending = $descending }, @{ Expression = { Get-NaturalSortKey $_.Name }; Descending = $false })
        }
        'Size' {
            return @($images | Sort-Object @{ Expression = { $_.Length }; Descending = $descending }, @{ Expression = { Get-NaturalSortKey $_.Name }; Descending = $false })
        }
        default {
            return @($images | Sort-Object @{ Expression = { Get-NaturalSortKey $_.Name }; Descending = $descending })
        }
    }
}

function Stop-ImageLoading {
    $script:ImageLoadGeneration++
    if ($null -ne $script:ImageLoadTimer) {
        try { $script:ImageLoadTimer.Stop() } catch { }
        $script:ImageLoadTimer = $null
    }
    $script:PendingImages = @()
    $script:PendingImageIndex = 0
}

$script:ImageLoadTickHandler = {
    if ($null -eq $script:ImageLoadTimer) { return }
    $total = $script:PendingImages.Count
    if ($total -le 0) {
        Stop-ImageLoading
        return
    }

    $target = [Math]::Min($total, $script:PendingImageIndex + $script:ImageLoadBatchSize)
    while ($script:PendingImageIndex -lt $target) {
        $file = $script:PendingImages[$script:PendingImageIndex]
        Add-ImageTile $file
        $script:PendingImageIndex++
    }

    if ($script:PendingImageIndex -ge $total) {
        $timer = $script:ImageLoadTimer
        if ($null -ne $timer) { $timer.Stop() }
        $script:ImageLoadTimer = $null
        $script:PendingImages = @()
        $script:PendingImageIndex = 0
        $ImageCountText.Text = if ($total -eq 1) { T 'FilesOne' } else { T 'FilesMany' @($total) }
        $elapsedText = ''
        if ($null -ne $script:ImageLoadStartedAt) {
            $seconds = ((Get-Date) - $script:ImageLoadStartedAt).TotalSeconds
            $elapsedText = T 'Seconds' @($seconds)
        }
        $StatusText.Text = T 'PreviewLoaded' @($total, $elapsedText)
        Update-ImageTileSelection
        Request-ImageScrollMarkerUpdate
    } else {
        # Keep the window interactive and report background-style progressive load.
        $StatusText.Text = T 'PreviewLoading' @($script:PendingImageIndex, $total)
        Request-ImageScrollMarkerUpdate
    }
}

function Load-Images([string]$folder, [object[]]$entries = $null) {
    Stop-ImageLoading
    $ImagePanel.Children.Clear()
    $script:ImageTiles = @{}
    $ImageScrollMarker.Visibility = 'Collapsed'

    try {
        $images = @(Get-SortedImages $folder $entries)
        $count = $images.Count
        $ImageCountText.Text = if ($count -eq 1) { T 'FilesOne' } else { T 'FilesMany' @($count) }

        if ($count -eq 0) {
            $empty = New-Object System.Windows.Controls.TextBlock
            $empty.Text = T 'NoImages'
            $empty.Margin = 8
            $empty.Foreground = $script:BrushMutedText
            $empty.FontSize = 14
            $ImagePanel.Children.Add($empty) | Out-Null
            return
        }

        $script:PendingImages = $images
        $script:PendingImageIndex = 0
        $script:ImageLoadStartedAt = Get-Date

        # Smaller batches for very large folders keep scrolling/text editing
        # responsive while thumbnails continue appearing progressively.
        if ($count -ge 800) { $script:ImageLoadBatchSize = 8 }
        elseif ($count -ge 400) { $script:ImageLoadBatchSize = 10 }
        elseif ($count -ge 150) { $script:ImageLoadBatchSize = 14 }
        else { $script:ImageLoadBatchSize = 24 }

        $script:ImageLoadTimer = New-Object System.Windows.Threading.DispatcherTimer
        $script:ImageLoadTimer.Interval = [TimeSpan]::FromMilliseconds(1)
        $script:ImageLoadTimer.Add_Tick($script:ImageLoadTickHandler)
        $script:ImageLoadTimer.Start()
        $StatusText.Text = T 'PreviewLoading' @(0, $count)
    } catch {
        $ImageCountText.Text = T 'NoFiles'
        $StatusText.Text = "$(T 'ImageReadError'): $($_.Exception.Message)"
    }
}

function Load-Folders([string]$folder, [object[]]$entries = $null) {
    $FolderList.Items.Clear()
    try {
        if ($null -eq $entries) { $entries = @(Get-ChildItem -LiteralPath $folder -ErrorAction Stop) }
        $dirs = @($entries | Where-Object { $_ -is [System.IO.DirectoryInfo] } | Sort-Object { Get-NaturalSortKey $_.Name })
        foreach ($dir in $dirs) {
            $item = New-Object System.Windows.Controls.ListBoxItem
            $item.Content = "📁  $($dir.Name)"
            $item.Tag = [pscustomobject]@{ Type = 'Folder'; Path = $dir.FullName }

            $menu = New-ModernContextMenu

            $openFolder = New-ModernMenuItem
            $openFolder.Header = T 'Open'
            $openFolder.Tag = $dir.FullName
            $openFolder.Add_Click($script:FolderOpenHandler)
            [void]$menu.Items.Add($openFolder)

            [void]$menu.Items.Add((New-ModernSeparator))

            $cutFolder = New-ModernMenuItem
            $cutFolder.Header = T 'Cut'
            $cutFolder.Tag = $dir.FullName
            $cutFolder.Add_Click($script:FolderCutHandler)
            [void]$menu.Items.Add($cutFolder)

            $copyFolder = New-ModernMenuItem
            $copyFolder.Header = T 'Copy'
            $copyFolder.Tag = $dir.FullName
            $copyFolder.Add_Click($script:FolderCopyHandler)
            [void]$menu.Items.Add($copyFolder)

            [void]$menu.Items.Add((New-ModernSeparator))

            $renameFolder = New-ModernMenuItem
            $renameFolder.Header = T 'Rename'
            $renameFolder.Tag = $dir.FullName
            $renameFolder.Add_Click($script:FolderRenameHandler)
            [void]$menu.Items.Add($renameFolder)

            $deleteFolder = New-ModernMenuItem
            $deleteFolder.Header = T 'Delete'
            $deleteFolder.Tag = $dir.FullName
            $deleteFolder.Add_Click($script:FolderDeleteHandler)
            [void]$menu.Items.Add($deleteFolder)

            $item.ContextMenu = $menu
            $FolderList.Items.Add($item) | Out-Null
        }

        $textFiles = @($entries | Where-Object {
            $_ -is [System.IO.FileInfo] -and ($_.Extension -ieq '.txt' -or $_.Extension -ieq '.md')
        } | Sort-Object { Get-NaturalSortKey $_.Name })

        foreach ($file in $textFiles) {
            $item = New-Object System.Windows.Controls.ListBoxItem
            $icon = if ($file.Extension -ieq '.md') { '📝' } else { '📄' }
            $item.Content = "$icon  $($file.Name)"
            $item.Tag = [pscustomobject]@{ Type = 'Text'; Path = $file.FullName }

            $menu = New-ModernContextMenu

            $open = New-ModernMenuItem
            $open.Header = T 'Open'
            $open.Tag = $file.FullName
            $open.Add_Click($script:TextOpenHandler)
            [void]$menu.Items.Add($open)

            [void]$menu.Items.Add((New-ModernSeparator))

            $cut = New-ModernMenuItem
            $cut.Header = T 'Cut'
            $cut.Tag = $file.FullName
            $cut.Add_Click($script:TextCutHandler)
            [void]$menu.Items.Add($cut)

            $copy = New-ModernMenuItem
            $copy.Header = T 'Copy'
            $copy.Tag = $file.FullName
            $copy.Add_Click($script:TextCopyHandler)
            [void]$menu.Items.Add($copy)

            [void]$menu.Items.Add((New-ModernSeparator))

            $rename = New-ModernMenuItem
            $rename.Header = T 'Rename'
            $rename.Tag = $file.FullName
            $rename.Add_Click($script:TextRenameHandler)
            [void]$menu.Items.Add($rename)

            $delete = New-ModernMenuItem
            $delete.Header = T 'Delete'
            $delete.Tag = $file.FullName
            $delete.Add_Click($script:TextDeleteHandler)
            [void]$menu.Items.Add($delete)

            $item.ContextMenu = $menu
            $FolderList.Items.Add($item) | Out-Null
        }
    } catch {
        $StatusText.Text = "$(T 'ExplorerReadError'): $($_.Exception.Message)"
    }
}

function Update-NavigationButtons {
    $BackButton.IsEnabled = ($script:History.Count -gt 0)
    $HomeButton.IsEnabled = [bool]$script:RootFolder

    if ($script:CurrentFolder) {
        $parent = Split-Path -Parent $script:CurrentFolder
        $UpButton.IsEnabled = (-not [string]::IsNullOrWhiteSpace($parent) -and
                               (Test-Path -LiteralPath $parent -PathType Container) -and
                               -not $parent.Equals($script:CurrentFolder, [System.StringComparison]::OrdinalIgnoreCase))
    } else {
        $UpButton.IsEnabled = $false
    }
}

function Ensure-StartupNavigationHistory {
    # A fresh app session has no in-memory navigation history. Seed Back with the
    # current folder's parent so the toolbar is useful immediately after restore.
    if ($script:History.Count -eq 0 -and $script:CurrentFolder) {
        $parent = Split-Path -Parent $script:CurrentFolder
        if (-not [string]::IsNullOrWhiteSpace($parent) -and
            (Test-Path -LiteralPath $parent -PathType Container) -and
            -not $parent.Equals($script:CurrentFolder, [System.StringComparison]::OrdinalIgnoreCase)) {
            $script:History.Add((Resolve-Path -LiteralPath $parent).Path)
        }
    }
    Update-NavigationButtons
}

function Navigate-To([string]$folder, [bool]$addHistory = $true, [bool]$skipUnsavedCheck = $false) {
    if ([string]::IsNullOrWhiteSpace($folder) -or -not (Test-Path -LiteralPath $folder -PathType Container)) { return $false }
    if (-not $skipUnsavedCheck -and -not (Confirm-PendingTextChanges)) { return $false }

    if ($addHistory -and $script:CurrentFolder -and $script:CurrentFolder -ne $folder) {
        $script:History.Add($script:CurrentFolder)
    }

    $resolvedTargetFolder = (Resolve-Path -LiteralPath $folder).Path
    if ($script:CurrentFolder -and -not $script:CurrentFolder.Equals($resolvedTargetFolder, [System.StringComparison]::OrdinalIgnoreCase)) {
        $script:LastSelectedImagePath = $null
    }
    $script:CurrentFolder = $resolvedTargetFolder
    $PathText.Text = $script:CurrentFolder
    $PathText.ToolTip = $script:CurrentFolder
    $StatusText.Text = T 'OpenedFolder' @($script:CurrentFolder)
    Show-TextMode

    Stop-ImageLoading
    $folderEntries = $null
    try {
        # One filesystem enumeration is shared by all three panels.  Previously
        # the same 1,000-file folder was scanned several times during navigation.
        $folderEntries = @(Get-ChildItem -LiteralPath $script:CurrentFolder -ErrorAction Stop)
    } catch {
        $StatusText.Text = "$(T 'FolderReadError'): $($_.Exception.Message)"
    }

    Load-Folders $script:CurrentFolder $folderEntries
    Load-Images $script:CurrentFolder $folderEntries
    Load-TextFiles $script:CurrentFolder $folderEntries

    Update-NavigationButtons
    Save-Settings
    return $true
}

function Choose-RootFolder {
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = T 'FolderDialog'
    $dialog.ShowNewFolderButton = $true
    if ($script:RootFolder -and (Test-Path -LiteralPath $script:RootFolder)) {
        $dialog.SelectedPath = $script:RootFolder
    }

    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        if (-not (Confirm-PendingTextChanges)) { return }
        $script:RootFolder = $dialog.SelectedPath
        $script:History.Clear()
        Navigate-To $script:RootFolder $false $true | Out-Null
    }
}

# ---- Shared UI handlers -----------------------------------------------------
# These handlers live in the main script scope (rather than per-tile closures),
# which keeps them reliable when the app is launched through the BAT wrapper.

$script:FolderOpenHandler = {
    param($sender, $e)
    Navigate-To ([string]$sender.Tag) | Out-Null
}

$script:FolderCutHandler = {
    param($sender, $e)
    $path = [string]$sender.Tag
    if (& $script:SetFileClipboardAction $path $true) {
        $StatusText.Text = T 'CutFolder' @([System.IO.Path]::GetFileName($path))
    }
}

$script:FolderCopyHandler = {
    param($sender, $e)
    $path = [string]$sender.Tag
    if (& $script:SetFileClipboardAction $path $false) {
        $StatusText.Text = T 'CopyFolder' @([System.IO.Path]::GetFileName($path))
    }
}

$script:FolderRenameHandler = {
    param($sender, $e)
    $path = [string]$sender.Tag
    if (-not (Test-Path -LiteralPath $path -PathType Container)) { return }

    $oldName = [System.IO.Path]::GetFileName($path.TrimEnd([System.IO.Path]::DirectorySeparatorChar))
    $newName = Show-TextInputDialog -Title (T 'RenameFolderTitle') -Prompt (T 'RenameFolderPrompt') -DefaultText $oldName
    if ([string]::IsNullOrWhiteSpace($newName) -or $newName -eq $oldName) { return }

    if ([System.IO.Path]::GetFileName($newName) -ne $newName -or $newName.IndexOfAny([System.IO.Path]::GetInvalidFileNameChars()) -ge 0) {
        [System.Windows.MessageBox]::Show((T 'InvalidFolderName'), (T 'InvalidNameTitle')) | Out-Null
        return
    }

    $parent = Split-Path -Parent $path
    $destination = Join-Path $parent $newName
    if (Test-Path -LiteralPath $destination) {
        [System.Windows.MessageBox]::Show((T 'FolderExists'), (T 'RenameTitle')) | Out-Null
        return
    }

    try {
        Move-Item -LiteralPath $path -Destination $destination -ErrorAction Stop
        for ($i = $script:History.Count - 1; $i -ge 0; $i--) {
            if ($script:History[$i].Equals($path, [System.StringComparison]::OrdinalIgnoreCase) -or
                $script:History[$i].StartsWith($path + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
                $script:History.RemoveAt($i)
            }
        }
        Load-Folders $script:CurrentFolder
        Update-NavigationButtons
        Save-Settings
        $StatusText.Text = T 'FolderRenamed' @($newName)
    } catch {
        [System.Windows.MessageBox]::Show("$(T 'RenameFolderError')`r`n`r`n$($_.Exception.Message)", (T 'ErrorTitle')) | Out-Null
    }
}

$script:FolderDeleteHandler = {
    param($sender, $e)
    $path = [string]$sender.Tag
    if (-not (Test-Path -LiteralPath $path -PathType Container)) { return }
    $name = [System.IO.Path]::GetFileName($path.TrimEnd([System.IO.Path]::DirectorySeparatorChar))

    if (-not (Show-ConfirmDialog -Title (T 'DeleteFolderTitle') -Message (T 'DeleteFolderMessage' @($name)) -ConfirmText (T 'Yes') -CancelText (T 'No'))) { return }

    if (& $script:SendFolderToRecycleBinAction $path) {
        for ($i = $script:History.Count - 1; $i -ge 0; $i--) {
            if ($script:History[$i].Equals($path, [System.StringComparison]::OrdinalIgnoreCase) -or
                $script:History[$i].StartsWith($path + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
                $script:History.RemoveAt($i)
            }
        }
        Load-Folders $script:CurrentFolder
        Update-NavigationButtons
        Save-Settings
        $StatusText.Text = T 'FolderRecycled' @($name)
    }
}

$script:ImageTileContextMenuHandler = {
    param($sender, $e)
    if ($null -eq $sender.ContextMenu) {
        $sender.ContextMenu = New-ImageTileContextMenu ([string]$sender.Tag)
    }
}

$script:ImageTileClickHandler = {
    param($sender, $e)
    $imagePath = [string]$sender.Tag
    if ([string]::IsNullOrWhiteSpace($imagePath) -or -not (Test-Path -LiteralPath $imagePath -PathType Leaf)) { return }

    try {
        $bitmapPreview = New-Object System.Windows.Media.Imaging.BitmapImage
        $bitmapPreview.BeginInit()
        $bitmapPreview.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $bitmapPreview.CreateOptions = [System.Windows.Media.Imaging.BitmapCreateOptions]::IgnoreImageCache
        $bitmapPreview.DecodePixelWidth = 1800
        $bitmapPreview.UriSource = New-Object System.Uri($imagePath, [System.UriKind]::Absolute)
        $bitmapPreview.EndInit()
        $bitmapPreview.Freeze()

        $PreviewImage.Source = $bitmapPreview
        $PreviewError.Visibility = 'Collapsed'
    } catch {
        $PreviewImage.Source = $null
        $PreviewError.Visibility = 'Visible'
    }

    $script:PreviewImagePath = $imagePath
    $script:LastSelectedImagePath = $imagePath
    Reset-PreviewTransform

    $TextContentBorder.Visibility = 'Collapsed'
    $PreviewContentBorder.Visibility = 'Visible'
    $TextNavigationPanel.Visibility = 'Collapsed'
    $ReturnToTextButton.Visibility = 'Visible'
    $SaveTextButton.Visibility = 'Collapsed'
    $MarkdownModeButton.Visibility = 'Collapsed'
    $SidePanelTitle.Text = T 'Preview'
    $TextFileName.Text = [System.IO.Path]::GetFileName($imagePath)
    Update-ImageTileSelection
    $StatusText.Text = T 'PreviewZoomHint'
    $e.Handled = $true
}

$script:ImageCutHandler = {
    param($sender, $e)
    $path = [string]$sender.Tag
    if (& $script:SetFileClipboardAction $path $true) {
        $StatusText.Text = T 'CutClipboard' @([System.IO.Path]::GetFileName($path))
    }
}

$script:ImageCopyHandler = {
    param($sender, $e)
    $path = [string]$sender.Tag
    if (& $script:SetFileClipboardAction $path $false) {
        $StatusText.Text = T 'CopyClipboard' @([System.IO.Path]::GetFileName($path))
    }
}

$script:ImageRenameHandler = {
    param($sender, $e)
    $path = [string]$sender.Tag
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return }

    $oldName = [System.IO.Path]::GetFileName($path)
    $newName = Show-TextInputDialog -Title (T 'RenameImageTitle') -Prompt (T 'RenamePrompt') -DefaultText $oldName
    if ([string]::IsNullOrWhiteSpace($newName) -or $newName -eq $oldName) { return }

    if ([System.IO.Path]::GetFileName($newName) -ne $newName -or $newName.IndexOfAny([System.IO.Path]::GetInvalidFileNameChars()) -ge 0) {
        [System.Windows.MessageBox]::Show((T 'InvalidFileName'), (T 'InvalidNameTitle')) | Out-Null
        return
    }

    $destination = Join-Path ([System.IO.Path]::GetDirectoryName($path)) $newName
    if (Test-Path -LiteralPath $destination) {
        [System.Windows.MessageBox]::Show((T 'FileExists'), (T 'RenameTitle')) | Out-Null
        return
    }

    try {
        Move-Item -LiteralPath $path -Destination $destination -ErrorAction Stop
        if ($script:PreviewImagePath -and $script:PreviewImagePath.Equals($path, [System.StringComparison]::OrdinalIgnoreCase)) {
            $script:PreviewImagePath = $destination
            $TextFileName.Text = $newName
        }
        if ($script:LastSelectedImagePath -and $script:LastSelectedImagePath.Equals($path, [System.StringComparison]::OrdinalIgnoreCase)) {
            $script:LastSelectedImagePath = $destination
        }
        Load-Images $script:CurrentFolder
        $StatusText.Text = T 'Renamed' @($newName)
    } catch {
        [System.Windows.MessageBox]::Show("$(T 'RenameFileError')`r`n`r`n$($_.Exception.Message)", (T 'ErrorTitle')) | Out-Null
    }
}

$script:ImageDeleteHandler = {
    param($sender, $e)
    $path = [string]$sender.Tag
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return }
    $name = [System.IO.Path]::GetFileName($path)

    if (-not (Show-ConfirmDialog -Title (T 'DeleteImageTitle') -Message (T 'DeleteFileMessage' @($name)) -ConfirmText (T 'Yes') -CancelText (T 'No'))) { return }

    if (& $script:SendFileToRecycleBinAction $path) {
        if ($script:PreviewImagePath -and $script:PreviewImagePath.Equals($path, [System.StringComparison]::OrdinalIgnoreCase)) {
            Show-TextMode
        }
        if ($script:LastSelectedImagePath -and $script:LastSelectedImagePath.Equals($path, [System.StringComparison]::OrdinalIgnoreCase)) {
            $script:LastSelectedImagePath = $null
        }
        Load-Images $script:CurrentFolder
        $StatusText.Text = T 'Recycled' @($name)
    }
}

$script:TextOpenHandler = {
    param($sender, $e)
    Open-TextFileByPath ([string]$sender.Tag) | Out-Null
}

$script:TextCutHandler = {
    param($sender, $e)
    $path = [string]$sender.Tag
    if (& $script:SetFileClipboardAction $path $true) {
        $StatusText.Text = T 'CutClipboard' @([System.IO.Path]::GetFileName($path))
    }
}

$script:TextCopyHandler = {
    param($sender, $e)
    $path = [string]$sender.Tag
    if (& $script:SetFileClipboardAction $path $false) {
        $StatusText.Text = T 'CopyClipboard' @([System.IO.Path]::GetFileName($path))
    }
}

$script:TextRenameHandler = {
    param($sender, $e)
    $path = [string]$sender.Tag
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return }
    if (-not (Confirm-PendingTextChanges)) { return }

    $oldName = [System.IO.Path]::GetFileName($path)
    $newName = Show-TextInputDialog -Title (T 'RenameTextTitle') -Prompt (T 'RenamePrompt') -DefaultText $oldName
    if ([string]::IsNullOrWhiteSpace($newName) -or $newName -eq $oldName) { return }

    if ([System.IO.Path]::GetFileName($newName) -ne $newName -or $newName.IndexOfAny([System.IO.Path]::GetInvalidFileNameChars()) -ge 0) {
        [System.Windows.MessageBox]::Show((T 'InvalidFileName'), (T 'InvalidNameTitle')) | Out-Null
        return
    }

    $destination = Join-Path ([System.IO.Path]::GetDirectoryName($path)) $newName
    if (Test-Path -LiteralPath $destination) {
        [System.Windows.MessageBox]::Show((T 'FileExists'), (T 'RenameTitle')) | Out-Null
        return
    }

    try {
        Move-Item -LiteralPath $path -Destination $destination -ErrorAction Stop
        Load-Folders $script:CurrentFolder
        Load-TextFiles $script:CurrentFolder
        if ([System.IO.Path]::GetExtension($destination) -ieq '.txt' -or [System.IO.Path]::GetExtension($destination) -ieq '.md') {
            Open-TextFileByPath $destination | Out-Null
        }
        $StatusText.Text = T 'Renamed' @($newName)
    } catch {
        [System.Windows.MessageBox]::Show("$(T 'RenameFileError')`r`n`r`n$($_.Exception.Message)", (T 'ErrorTitle')) | Out-Null
    }
}

$script:TextDeleteHandler = {
    param($sender, $e)
    $path = [string]$sender.Tag
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return }
    if (-not (Confirm-PendingTextChanges)) { return }
    $name = [System.IO.Path]::GetFileName($path)

    if (-not (Show-ConfirmDialog -Title (T 'DeleteTextTitle') -Message (T 'DeleteFileMessage' @($name)) -ConfirmText (T 'Yes') -CancelText (T 'No'))) { return }

    if (& $script:SendFileToRecycleBinAction $path) {
        Load-Folders $script:CurrentFolder
        Load-TextFiles $script:CurrentFolder
        Show-TextMode
        $StatusText.Text = T 'Recycled' @($name)
    }
}

$script:CreateFolderHandler = {
    param($sender, $e)
    if (-not $script:CurrentFolder) { return }
    if (-not (Confirm-PendingTextChanges)) { return }

    $name = Show-TextInputDialog -Title (T 'CreateFolderTitle') -Prompt (T 'CreateFolderPrompt') -DefaultText (T 'NewFolder')
    if ([string]::IsNullOrWhiteSpace($name)) { return }
    if ([System.IO.Path]::GetFileName($name) -ne $name -or $name.IndexOfAny([System.IO.Path]::GetInvalidFileNameChars()) -ge 0) {
        [System.Windows.MessageBox]::Show((T 'InvalidFolderName'), (T 'InvalidNameTitle')) | Out-Null
        return
    }

    $path = Join-Path $script:CurrentFolder $name
    if (Test-Path -LiteralPath $path) {
        [System.Windows.MessageBox]::Show((T 'FolderExists'), (T 'CreateFolderExistsTitle')) | Out-Null
        return
    }

    try {
        New-Item -ItemType Directory -Path $path -ErrorAction Stop | Out-Null
        Load-Folders $script:CurrentFolder
        $StatusText.Text = T 'FolderCreated' @($name)
    } catch {
        [System.Windows.MessageBox]::Show("$(T 'CreateFolderError')`r`n`r`n$($_.Exception.Message)", (T 'ErrorTitle')) | Out-Null
    }
}

$script:CreateTxtHandler = {
    param($sender, $e)
    if (-not $script:CurrentFolder) { return }
    if (-not (Confirm-PendingTextChanges)) { return }

    $name = Show-TextInputDialog -Title (T 'CreateTxtTitle') -Prompt (T 'CreateTxtPrompt') -DefaultText (T 'NewTxt')
    if ([string]::IsNullOrWhiteSpace($name)) { return }
    if (-not $name.EndsWith('.txt', [System.StringComparison]::OrdinalIgnoreCase)) { $name += '.txt' }

    if ([System.IO.Path]::GetFileName($name) -ne $name -or $name.IndexOfAny([System.IO.Path]::GetInvalidFileNameChars()) -ge 0) {
        [System.Windows.MessageBox]::Show((T 'InvalidFileName'), (T 'InvalidNameTitle')) | Out-Null
        return
    }

    $path = Join-Path $script:CurrentFolder $name
    if (Test-Path -LiteralPath $path) {
        [System.Windows.MessageBox]::Show((T 'FileExists'), (T 'CreateFileExistsTitle')) | Out-Null
        return
    }

    try {
        [System.IO.File]::WriteAllText($path, '', [System.Text.UTF8Encoding]::new($false))
        Load-Folders $script:CurrentFolder
        Load-TextFiles $script:CurrentFolder
        Open-TextFileByPath $path | Out-Null
        $StatusText.Text = T 'FileCreated' @($name)
    } catch {
        [System.Windows.MessageBox]::Show("$(T 'CreateFileError')`r`n`r`n$($_.Exception.Message)", (T 'ErrorTitle')) | Out-Null
    }
}

$script:CreateMdHandler = {
    param($sender, $e)
    if (-not $script:CurrentFolder) { return }
    if (-not (Confirm-PendingTextChanges)) { return }

    $name = Show-TextInputDialog -Title (T 'CreateMdTitle') -Prompt (T 'CreateMdPrompt') -DefaultText (T 'NewMd')
    if ([string]::IsNullOrWhiteSpace($name)) { return }
    if (-not $name.EndsWith('.md', [System.StringComparison]::OrdinalIgnoreCase)) { $name += '.md' }

    if ([System.IO.Path]::GetFileName($name) -ne $name -or $name.IndexOfAny([System.IO.Path]::GetInvalidFileNameChars()) -ge 0) {
        [System.Windows.MessageBox]::Show((T 'InvalidFileName'), (T 'InvalidNameTitle')) | Out-Null
        return
    }

    $path = Join-Path $script:CurrentFolder $name
    if (Test-Path -LiteralPath $path) {
        [System.Windows.MessageBox]::Show((T 'FileExists'), (T 'CreateFileExistsTitle')) | Out-Null
        return
    }

    try {
        [System.IO.File]::WriteAllText($path, '', [System.Text.UTF8Encoding]::new($false))
        Load-Folders $script:CurrentFolder
        Load-TextFiles $script:CurrentFolder
        Open-TextFileByPath $path | Out-Null
        $StatusText.Text = T 'FileCreated' @($name)
    } catch {
        [System.Windows.MessageBox]::Show("$(T 'CreateFileError')`r`n`r`n$($_.Exception.Message)", (T 'ErrorTitle')) | Out-Null
    }
}


# Styled text-edit context menu (replaces the default Windows English menu).
$script:TextEditMenu = New-ModernContextMenu
$script:TextCutMenuItem = New-ModernMenuItem
$script:TextCutMenuItem.Add_Click({ if (-not $TextViewer.IsReadOnly) { $TextViewer.Cut() } })
[void]$script:TextEditMenu.Items.Add($script:TextCutMenuItem)
$script:TextCopyMenuItem = New-ModernMenuItem
$script:TextCopyMenuItem.Add_Click({ $TextViewer.Copy() })
[void]$script:TextEditMenu.Items.Add($script:TextCopyMenuItem)
$script:TextPasteMenuItem = New-ModernMenuItem
$script:TextPasteMenuItem.Add_Click({ if (-not $TextViewer.IsReadOnly) { $TextViewer.Paste() } })
[void]$script:TextEditMenu.Items.Add($script:TextPasteMenuItem)
[void]$script:TextEditMenu.Items.Add((New-ModernSeparator))
$script:TextSelectAllMenuItem = New-ModernMenuItem
$script:TextSelectAllMenuItem.Add_Click({ $TextViewer.SelectAll() })
[void]$script:TextEditMenu.Items.Add($script:TextSelectAllMenuItem)
$script:TextEditMenu.Add_Opened({ Update-TextContextMenuState })
$TextViewer.ContextMenu = $script:TextEditMenu

# Context menu for the current location in the left "Провідник" panel.
$script:CreateTextMenu = New-ModernContextMenu
$pasteMenuItem = New-ModernMenuItem
$pasteMenuItem.Header = T 'Paste'
$pasteMenuItem.Add_Click({ Paste-ClipboardItems })
[void]$script:CreateTextMenu.Items.Add($pasteMenuItem)
[void]$script:CreateTextMenu.Items.Add((New-ModernSeparator))

$script:CreateTextMenu.Add_Opened({
    $clip = Get-ClipboardFileDropInfo
    $pasteMenuItem.IsEnabled = $clip.HasFiles
    $pasteMenuItem.Visibility = if ($clip.HasFiles) { 'Visible' } else { 'Collapsed' }
})

$createFolderMenuItem = New-ModernMenuItem
$createFolderMenuItem.Header = T 'CreateFolder'
$createFolderMenuItem.Add_Click($script:CreateFolderHandler)
[void]$script:CreateTextMenu.Items.Add($createFolderMenuItem)
[void]$script:CreateTextMenu.Items.Add((New-ModernSeparator))

$createTxtMenuItem = New-ModernMenuItem
$createTxtMenuItem.Header = T 'CreateTxt'
$createTxtMenuItem.Add_Click($script:CreateTxtHandler)
[void]$script:CreateTextMenu.Items.Add($createTxtMenuItem)

$createMdMenuItem = New-ModernMenuItem
$createMdMenuItem.Header = T 'CreateMd'
$createMdMenuItem.Add_Click($script:CreateMdHandler)
[void]$script:CreateTextMenu.Items.Add($createMdMenuItem)


$script:CreateImageMenu = New-ModernContextMenu
$imagePasteMenuItem = New-ModernMenuItem
$imagePasteMenuItem.Header = T 'Paste'
$imagePasteMenuItem.Add_Click({ Paste-ClipboardItems })
[void]$script:CreateImageMenu.Items.Add($imagePasteMenuItem)

$script:CreateImageMenu.Add_Opened({
    $clip = Get-ClipboardFileDropInfo
    $imagePasteMenuItem.IsEnabled = $clip.HasFiles
    $imagePasteMenuItem.Visibility = if ($clip.HasFiles) { 'Visible' } else { 'Collapsed' }
})

$ImageSortFieldCombo.Add_SelectionChanged({
    if ($script:InitializingSortControls) { return }
    if ($null -eq $ImageSortFieldCombo.SelectedItem) { return }
    $tag = [string]$ImageSortFieldCombo.SelectedItem.Tag
    if ($tag -in @('Name', 'Modified', 'Created', 'Size')) {
        $script:ImageSortField = $tag
        if ($script:CurrentFolder) { Load-Images $script:CurrentFolder }
        Save-Settings
    }
})

$ImageSortDirectionCombo.Add_SelectionChanged({
    if ($script:InitializingSortControls) { return }
    if ($null -eq $ImageSortDirectionCombo.SelectedItem) { return }
    $script:ImageSortDescending = ([string]$ImageSortDirectionCombo.SelectedItem.Tag -eq 'Descending')
    if ($script:CurrentFolder) { Load-Images $script:CurrentFolder }
    Save-Settings
})

$LanguageCombo.Add_SelectionChanged({
    if ($script:InitializingLanguageControl -or $null -eq $LanguageCombo.SelectedItem) { return }
    $newLanguage = [string]$LanguageCombo.SelectedItem.Tag
    if ($newLanguage -notin @('UA','EN') -or $newLanguage -eq $script:Language) { return }
    $script:Language = $newLanguage
    Apply-Language
    Save-Settings
})

$ChooseRootButton.Add_Click({ Choose-RootFolder })
$MoveImagesButton.Add_Click({ Open-MoveImagesPopup })
$MoveSourceBrowseButton.Add_Click({ Select-MoveFolder -TargetTextBox $MoveSourceTextBox -DescriptionKey 'MoveSelectSource' })
$MoveDestinationBrowseButton.Add_Click({ Select-MoveFolder -TargetTextBox $MoveDestinationTextBox -DescriptionKey 'MoveSelectDestination' })
$MoveCancelButton.Add_Click({ $MoveImagesPopup.IsOpen = $false })
$MoveStartButton.Add_Click({ Move-ImagesBetweenFolders })
$ReturnToTextButton.Add_Click({ Show-TextMode })
$MarkdownModeButton.Add_Click({
    if ($script:IsCurrentMarkdown) { Set-MarkdownViewMode (-not $script:MarkdownRendered) }
})
$SaveTextButton.Add_Click({ Save-CurrentTextFile | Out-Null })

$TextViewer.Add_TextChanged({
    if (-not $script:IsLoadingText -and -not $TextViewer.IsReadOnly -and $script:TextFiles.Count -gt 0) {
        Set-TextDirty $true
        $StatusText.Text = T 'UnsavedStatus'
    }
})

$FolderList.Add_SelectionChanged({
    if ($script:SyncingExplorerSelection) { return }
    if (-not $FolderList.SelectedItem -or -not $FolderList.SelectedItem.Tag) { return }
    $tag = $FolderList.SelectedItem.Tag
    if ($tag.Type -eq 'Text') {
        Open-TextFileByPath ([string]$tag.Path) | Out-Null
    }
})

$FolderList.Add_MouseDoubleClick({
    if (-not $FolderList.SelectedItem -or -not $FolderList.SelectedItem.Tag) { return }
    $tag = $FolderList.SelectedItem.Tag
    if ($tag.Type -eq 'Folder') {
        Navigate-To ([string]$tag.Path)
    }
})

$FolderList.Add_PreviewMouseRightButtonUp({
    param($sender, $e)
    try {
        $source = $e.OriginalSource -as [System.Windows.DependencyObject]
        $container = $null
        if ($null -ne $source) {
            $container = [System.Windows.Controls.ItemsControl]::ContainerFromElement($FolderList, $source)
        }
        if ($null -eq $container) {
            $script:CreateTextMenu.PlacementTarget = $FolderList
            $script:CreateTextMenu.IsOpen = $true
            $e.Handled = $true
        }
    } catch {
        # A click on a scrollbar or other chrome should simply do nothing.
    }
})


$ImageScrollViewer.Add_PreviewMouseRightButtonUp({
    param($sender, $e)
    try {
        $source = $e.OriginalSource -as [System.Windows.DependencyObject]
        $tileBorder = $null
        while ($null -ne $source) {
            if ($source -is [System.Windows.Controls.Border] -and $source.Tag) {
                $tileBorder = $source
                break
            }
            $source = [System.Windows.Media.VisualTreeHelper]::GetParent($source)
        }
        if ($null -eq $tileBorder) {
            $script:CreateImageMenu.PlacementTarget = $ImageScrollViewer
            $script:CreateImageMenu.IsOpen = $true
            $e.Handled = $true
        }
    } catch {
        # ignore
    }
})


$ImagePanel.Add_SizeChanged({
    Request-ImageScrollMarkerUpdate
})

$ImageScrollViewer.Add_SizeChanged({
    Request-ImageScrollMarkerUpdate
})

$PreviewImage.Add_PreviewMouseLeftButtonDown({
    param($sender, $e)
    if ($PreviewContentBorder.Visibility -ne 'Visible' -or $null -eq $PreviewImage.Source) { return }
    if (-not $script:PreviewZoomed) { return }

    $script:PreviewDragging = $true
    $script:PreviewDragMoved = $false
    $script:PreviewDragStart = $e.GetPosition($PreviewContentBorder)
    $script:PreviewDragOriginX = $script:PreviewTranslateTransform.X
    $script:PreviewDragOriginY = $script:PreviewTranslateTransform.Y
    [void]$PreviewImage.CaptureMouse()
    $e.Handled = $true
})

$PreviewImage.Add_PreviewMouseMove({
    param($sender, $e)
    if (-not $script:PreviewDragging -or -not $script:PreviewZoomed) { return }
    if ($e.LeftButton -ne [System.Windows.Input.MouseButtonState]::Pressed) { return }

    $position = $e.GetPosition($PreviewContentBorder)
    $dx = $position.X - $script:PreviewDragStart.X
    $dy = $position.Y - $script:PreviewDragStart.Y
    if ([Math]::Abs($dx) -gt 2 -or [Math]::Abs($dy) -gt 2) {
        $script:PreviewDragMoved = $true
    }

    $script:PreviewTranslateTransform.X = $script:PreviewDragOriginX + $dx
    $script:PreviewTranslateTransform.Y = $script:PreviewDragOriginY + $dy
    $e.Handled = $true
})

$PreviewImage.Add_PreviewMouseLeftButtonUp({
    param($sender, $e)
    if ($PreviewContentBorder.Visibility -ne 'Visible' -or $null -eq $PreviewImage.Source) { return }

    if ($script:PreviewZoomed) {
        if ($script:PreviewDragging) {
            $PreviewImage.ReleaseMouseCapture()
            $script:PreviewDragging = $false
        }

        if ($script:PreviewDragMoved) {
            $script:PreviewDragMoved = $false
            $StatusText.Text = T 'ZoomDragDone'
        } else {
            Set-PreviewZoom $false
            $StatusText.Text = T 'ZoomNormal'
        }
    } else {
        Set-PreviewZoom $true
        $StatusText.Text = T 'Zoom300'
    }
    $e.Handled = $true
})

$BackButton.Add_Click({
    if ($script:History.Count -gt 0) {
        $lastIndex = $script:History.Count - 1
        $target = $script:History[$lastIndex]
        if (Navigate-To $target $false) {
            $script:History.RemoveAt($script:History.Count - 1)
            Update-NavigationButtons
            Save-Settings
        }
    }
})

$HomeButton.Add_Click({
    if ($script:RootFolder) { Navigate-To $script:RootFolder }
})

$UpButton.Add_Click({
    if (-not $script:CurrentFolder) { return }
    $parent = Split-Path -Parent $script:CurrentFolder
    if (-not [string]::IsNullOrWhiteSpace($parent) -and (Test-Path -LiteralPath $parent -PathType Container)) {
        Navigate-To $parent
    }
})

$PrevTextButton.Add_Click({
    if ($script:TextFiles.Count -le 1) { return }
    if (-not (Confirm-PendingTextChanges)) { return }
    $script:TextIndex--
    if ($script:TextIndex -lt 0) { $script:TextIndex = $script:TextFiles.Count - 1 }
    Update-TextNavigation
})

$NextTextButton.Add_Click({
    if ($script:TextFiles.Count -le 1) { return }
    if (-not (Confirm-PendingTextChanges)) { return }
    $script:TextIndex++
    if ($script:TextIndex -ge $script:TextFiles.Count) { $script:TextIndex = 0 }
    Update-TextNavigation
})

$window.Add_KeyDown({
    param($sender, $e)
    if (($e.KeyboardDevice.Modifiers -band [System.Windows.Input.ModifierKeys]::Control) -and $e.Key -eq [System.Windows.Input.Key]::S) {
        if ($script:TextDirty) { Save-CurrentTextFile | Out-Null }
        $e.Handled = $true
    } elseif (($e.KeyboardDevice.Modifiers -band [System.Windows.Input.ModifierKeys]::Control) -and $e.Key -eq [System.Windows.Input.Key]::V -and $script:CurrentFolder) {
        Paste-ClipboardItems
        $e.Handled = $true
    } elseif ($e.Key -eq [System.Windows.Input.Key]::F5 -and $script:CurrentFolder) {
        Navigate-To $script:CurrentFolder $false
        $e.Handled = $true
    } elseif ($e.Key -eq [System.Windows.Input.Key]::Escape -and $PreviewContentBorder.Visibility -eq 'Visible') {
        Show-TextMode
        $e.Handled = $true
    }
})

$BackButton.IsEnabled = $false
$UpButton.IsEnabled = $false
$HomeButton.IsEnabled = $false
$PrevTextButton.IsEnabled = $false
$NextTextButton.IsEnabled = $false
$TextViewer.Text = T 'SelectRoot'
$TextCounter.Text = '0 / 0'

# Load settings before ShowDialog so the saved size is applied before the
# window becomes visible, without a visible resize after startup.
$script:StartupSettingsLoaded = Load-Settings

# Apply saved/default interface language before the window is shown.
$LanguageCombo.SelectedIndex = if ($script:Language -eq 'EN') { 1 } else { 0 }
$script:InitializingLanguageControl = $false
Apply-Language

# Reflect the saved image-sort options in the toolbar.
switch ($script:ImageSortField) {
    'Modified' { $ImageSortFieldCombo.SelectedIndex = 1 }
    'Created'  { $ImageSortFieldCombo.SelectedIndex = 2 }
    'Size'     { $ImageSortFieldCombo.SelectedIndex = 3 }
    default    { $ImageSortFieldCombo.SelectedIndex = 0 }
}
$ImageSortDirectionCombo.SelectedIndex = if ($script:ImageSortDescending) { 1 } else { 0 }
$script:InitializingSortControls = $false

$window.Add_ContentRendered({
    if ($script:StartupSettingsLoaded) {
        $savedFolder = $script:CurrentFolder
        $script:CurrentFolder = $null
        Navigate-To $savedFolder $false
        Ensure-StartupNavigationHistory
        Save-Settings
    } else {
        Choose-RootFolder
    }
})

$window.Add_Closing({
    param($sender, $e)
    if (-not (Confirm-PendingTextChanges)) {
        $e.Cancel = $true
        return
    }
    Stop-ImageLoading
    if ($null -ne $script:MarkerUpdateTimer) { try { $script:MarkerUpdateTimer.Stop() } catch { } }
    Save-Settings
})
$window.Add_Closed({ Save-Settings })
$window.ShowDialog() | Out-Null
