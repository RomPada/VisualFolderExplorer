using System.Collections.ObjectModel;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Threading;
using VisualFolderExplorer.Models;
using VisualFolderExplorer.Services;
using VisualFolderExplorer.Windows;

namespace VisualFolderExplorer;

public partial class MainWindow : Window
{
    private readonly SettingsService _settingsService = new();
    private readonly LocalizationService _loc = new();
    private readonly ThumbnailService _thumbnailService = new();
    private readonly ObservableCollection<ExplorerItem> _explorerItems = [];
    private readonly ObservableCollection<ImageItem> _images = [];
    private readonly List<FileInfo> _textFiles = [];
    private readonly List<string> _history = [];

    private AppSettings _settings = new();
    private CancellationTokenSource? _imageLoadCts;
    private string? _rootFolder;
    private string? _currentFolder;
    private int _textIndex = -1;
    private bool _textDirty;
    private bool _loadingText;
    private bool _markdownRendered;
    private bool _initializingControls = true;
    private bool _suppressExplorerSelection;
    private string? _previewImagePath;
    private string? _lastSelectedImagePath;

    private readonly ScaleTransform _previewScale = new(1, 1);
    private readonly TranslateTransform _previewTranslate = new(0, 0);
    private bool _previewDragging;
    private bool _previewDragMoved;
    private Point _previewDragStart;
    private double _previewOriginX;
    private double _previewOriginY;

    public MainWindow()
    {
        InitializeComponent();
        ExplorerList.ItemsSource = _explorerItems;
        ImageList.ItemsSource = _images;
        var group = new TransformGroup();
        group.Children.Add(_previewScale);
        group.Children.Add(_previewTranslate);
        PreviewImage.RenderTransform = group;
        _loc.LanguageChanged += (_, _) => ApplyLanguage();
    }

    private async void Window_Loaded(object sender, RoutedEventArgs e)
    {
        _settings = _settingsService.Load();
        _rootFolder = Directory.Exists(_settings.RootFolder) ? _settings.RootFolder : null;
        _currentFolder = Directory.Exists(_settings.CurrentFolder) ? _settings.CurrentFolder : null;
        _history.AddRange(_settings.History.Where(Directory.Exists));
        _lastSelectedImagePath = _settings.LastSelectedImagePath;

        if (_settings.WindowWidth >= MinWidth) Width = _settings.WindowWidth;
        if (_settings.WindowHeight >= MinHeight) Height = _settings.WindowHeight;
        if (_settings.WindowState.Equals("Maximized", StringComparison.OrdinalIgnoreCase)) WindowState = System.Windows.WindowState.Maximized;

        _loc.SetLanguage(_settings.Language);
        LanguageCombo.SelectedIndex = _loc.Language == "EN" ? 1 : 0;
        SortFieldCombo.SelectedIndex = _settings.ImageSortField switch { "Modified" => 1, "Created" => 2, "Size" => 3, _ => 0 };
        SortDirectionCombo.SelectedIndex = _settings.ImageSortDescending ? 1 : 0;
        _initializingControls = false;
        ApplyLanguage();

        if (_currentFolder is not null)
            await NavigateToAsync(_currentFolder, addHistory: false, confirmChanges: false);
        else
            ChooseRootFolder();
    }

    private void Window_Closing(object? sender, System.ComponentModel.CancelEventArgs e)
    {
        if (!ConfirmPendingTextChanges()) { e.Cancel = true; return; }
        SaveSettings();
        _imageLoadCts?.Cancel();
    }

    private void SaveSettings()
    {
        var bounds = WindowState == System.Windows.WindowState.Maximized ? RestoreBounds : new Rect(Left, Top, ActualWidth, ActualHeight);
        _settings.RootFolder = _rootFolder;
        _settings.CurrentFolder = _currentFolder;
        _settings.History = [.. _history];
        _settings.WindowWidth = Math.Max(MinWidth, bounds.Width);
        _settings.WindowHeight = Math.Max(MinHeight, bounds.Height);
        _settings.WindowState = WindowState == System.Windows.WindowState.Maximized ? "Maximized" : "Normal";
        _settings.Language = _loc.Language;
        _settings.ImageSortField = SelectedSortField();
        _settings.ImageSortDescending = SortDirectionCombo.SelectedIndex == 1;
        _settings.LastSelectedImagePath = _lastSelectedImagePath;
        _settingsService.Save(_settings);
    }

    private string SelectedSortField() => SortFieldCombo.SelectedItem is ComboBoxItem item ? item.Tag?.ToString() ?? "Name" : "Name";

    private void ApplyLanguage()
    {
        ChooseFolderButton.Content = _loc.T("ChooseFolder");
        MoveImagesButton.Content = _loc.T("MoveImages");
        ExplorerTitle.Text = _loc.T("Explorer");
        ImagesTitle.Text = _loc.T("Images");
        SideTitle.Text = PreviewPanel.Visibility == Visibility.Visible ? _loc.T("Preview") : _loc.T("Text");
        SaveTextButton.Content = _loc.T("Save");
        BackToTextButton.Content = _loc.T("BackToText");
        MarkdownModeButton.Content = _markdownRendered ? _loc.T("Edit") : _loc.T("Preview");
        BackButton.ToolTip = _loc.T("Back"); HomeButton.ToolTip = _loc.T("Home"); UpButton.ToolTip = _loc.T("FolderUp");
        StatusText.Text = string.IsNullOrWhiteSpace(StatusText.Text) ? _loc.T("Ready") : StatusText.Text;

        if (SortFieldCombo.Items.Count >= 4)
        {
            ((ComboBoxItem)SortFieldCombo.Items[0]).Content = _loc.T("SortName");
            ((ComboBoxItem)SortFieldCombo.Items[1]).Content = _loc.T("SortModified");
            ((ComboBoxItem)SortFieldCombo.Items[2]).Content = _loc.T("SortCreated");
            ((ComboBoxItem)SortFieldCombo.Items[3]).Content = _loc.T("SortSize");
        }
        if (SortDirectionCombo.Items.Count >= 2)
        {
            ((ComboBoxItem)SortDirectionCombo.Items[0]).Content = _loc.T("Ascending");
            ((ComboBoxItem)SortDirectionCombo.Items[1]).Content = _loc.T("Descending");
        }
        UpdateTextFileName();
        UpdateImageCount();
    }

    private void LanguageCombo_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_initializingControls || LanguageCombo.SelectedItem is not ComboBoxItem item) return;
        _loc.SetLanguage(item.Tag?.ToString() ?? "UA");
        SaveSettings();
    }

    private void ChooseFolderButton_Click(object sender, RoutedEventArgs e) => ChooseRootFolder();

    private void ChooseRootFolder()
    {
        var picker = new FolderPickerWindow(_loc, _currentFolder ?? _rootFolder) { Owner = this };
        if (picker.ShowDialog() != true || string.IsNullOrWhiteSpace(picker.SelectedPath)) return;
        _rootFolder = picker.SelectedPath;
        _history.Clear();
        _ = NavigateToAsync(_rootFolder, addHistory: false);
    }

    private async void MoveImagesButton_Click(object sender, RoutedEventArgs e)
    {
        var dialog = new MoveImagesWindow(_loc, _currentFolder, _settings.LastMoveDestination) { Owner = this };
        if (dialog.ShowDialog() == true)
        {
            _settings.LastMoveDestination = dialog.DestinationPath;
            SaveSettings();
            StatusText.Text = _loc.T("MoveDone", dialog.MovedCount, dialog.RenamedCount);
            if (_currentFolder is not null) await ReloadCurrentFolderAsync();
        }
    }

    private async Task NavigateToAsync(string folder, bool addHistory = true, bool confirmChanges = true)
    {
        if (!Directory.Exists(folder)) return;
        if (confirmChanges && !ConfirmPendingTextChanges()) return;

        var resolved = Path.GetFullPath(folder);
        if (addHistory && _currentFolder is not null && !_currentFolder.Equals(resolved, StringComparison.OrdinalIgnoreCase))
            _history.Add(_currentFolder);

        _currentFolder = resolved;
        PathBox.Text = resolved;
        StatusText.Text = _loc.T("OpenFolder", resolved);
        UpdateNavigationButtons();
        ShowTextMode();

        List<FileSystemInfo> entries;
        try
        {
            entries = await Task.Run(() => new DirectoryInfo(resolved).EnumerateFileSystemInfos().ToList());
        }
        catch (Exception ex)
        {
            StatusText.Text = ex.Message;
            return;
        }

        LoadExplorer(entries);
        var imageTask = LoadImagesAsync(entries.OfType<FileInfo>().Where(f => FileService.IsImage(f.FullName)).ToList());
        await LoadTextFilesAsync(entries.OfType<FileInfo>().Where(f => FileService.IsText(f.FullName)).ToList());
        await imageTask;
        SaveSettings();
    }

    private async Task ReloadCurrentFolderAsync()
    {
        if (_currentFolder is null) return;
        await NavigateToAsync(_currentFolder, addHistory: false, confirmChanges: false);
    }

    private void LoadExplorer(IEnumerable<FileSystemInfo> entries)
    {
        _explorerItems.Clear();
        foreach (var directory in entries.OfType<DirectoryInfo>().OrderBy(d => d.Name, NaturalStringComparer.Instance))
            _explorerItems.Add(new ExplorerItem { Name = directory.Name, FullPath = directory.FullName, Type = ExplorerItemType.Folder });
        foreach (var file in entries.OfType<FileInfo>().Where(f => FileService.IsText(f.FullName)).OrderBy(f => f.Name, NaturalStringComparer.Instance))
            _explorerItems.Add(new ExplorerItem { Name = file.Name, FullPath = file.FullName, Type = ExplorerItemType.TextFile });
    }

    private IEnumerable<FileInfo> SortImages(IEnumerable<FileInfo> files)
    {
        var descending = SortDirectionCombo.SelectedIndex == 1;
        IOrderedEnumerable<FileInfo> ordered = SelectedSortField() switch
        {
            "Modified" => descending ? files.OrderByDescending(f => f.LastWriteTime) : files.OrderBy(f => f.LastWriteTime),
            "Created" => descending ? files.OrderByDescending(f => f.CreationTime) : files.OrderBy(f => f.CreationTime),
            "Size" => descending ? files.OrderByDescending(f => f.Length) : files.OrderBy(f => f.Length),
            _ => descending ? files.OrderByDescending(f => f.Name, NaturalStringComparer.Instance) : files.OrderBy(f => f.Name, NaturalStringComparer.Instance)
        };
        return ordered.ThenBy(f => f.Name, NaturalStringComparer.Instance);
    }

    private async Task LoadImagesAsync(List<FileInfo> files)
    {
        _imageLoadCts?.Cancel();
        _imageLoadCts = new CancellationTokenSource();
        var token = _imageLoadCts.Token;
        _images.Clear();
        ImageScrollMarker.Visibility = Visibility.Collapsed;
        var sorted = SortImages(files).ToList();
        UpdateImageCount(sorted.Count);

        var semaphore = new SemaphoreSlim(6);
        var thumbnailTasks = new List<Task>();
        const int batchSize = 24;

        try
        {
            for (var i = 0; i < sorted.Count; i++)
            {
                token.ThrowIfCancellationRequested();
                var file = sorted[i];
                var item = new ImageItem { Name = file.Name, FullPath = file.FullName, Length = file.Length, CreationTime = file.CreationTime, LastWriteTime = file.LastWriteTime };
                _images.Add(item);
                var localItem = item;
                thumbnailTasks.Add(Task.Run(async () =>
                {
                    await semaphore.WaitAsync(token);
                    try
                    {
                        var thumb = await _thumbnailService.GetThumbnailAsync(localItem.FullPath, 240, token);
                        if (thumb is not null)
                            await Dispatcher.InvokeAsync(() => localItem.Thumbnail = thumb, DispatcherPriority.Background, token);
                    }
                    finally { semaphore.Release(); }
                }, token));

                if ((i + 1) % batchSize == 0)
                {
                    StatusText.Text = _loc.T("Loading", i + 1, sorted.Count);
                    await System.Windows.Threading.Dispatcher.Yield(DispatcherPriority.Background);
                }
            }

            await Task.WhenAll(thumbnailTasks);
            StatusText.Text = _loc.T("Loaded", sorted.Count);
            RestoreLastImageSelection();
        }
        catch (OperationCanceledException)
        {
            // Expected when the user changes folders/sorting before the previous load completes.
        }
    }

    private void UpdateImageCount(int? count = null)
    {
        var value = count ?? _images.Count;
        ImageCountText.Text = value == 1 ? _loc.T("OneFile") : _loc.T("FilesCount", value);
    }

    private async Task LoadTextFilesAsync(List<FileInfo> files)
    {
        var currentPath = _textIndex >= 0 && _textIndex < _textFiles.Count ? _textFiles[_textIndex].FullName : null;
        _textFiles.Clear();
        _textFiles.AddRange(files.OrderBy(f => f.Name, NaturalStringComparer.Instance));
        if (_textFiles.Count == 0)
        {
            _textIndex = -1;
            _loadingText = true;
            TextEditor.Text = _loc.T("NoText");
            _loadingText = false;
            TextFileName.Text = string.Empty;
            TextCounter.Text = "0 / 0";
            SaveTextButton.IsEnabled = false;
            MarkdownModeButton.Visibility = Visibility.Collapsed;
            return;
        }

        var index = currentPath is null ? 0 : _textFiles.FindIndex(f => f.FullName.Equals(currentPath, StringComparison.OrdinalIgnoreCase));
        await OpenTextByIndexAsync(index >= 0 ? index : 0, confirmChanges: false);
    }

    private async Task OpenTextByIndexAsync(int index, bool confirmChanges = true)
    {
        if (_textFiles.Count == 0) return;
        if (index < 0) index = _textFiles.Count - 1;
        if (index >= _textFiles.Count) index = 0;
        if (confirmChanges && index != _textIndex && !ConfirmPendingTextChanges()) return;

        _textIndex = index;
        var file = _textFiles[index];
        _loadingText = true;
        try
        {
            TextEditor.Text = await File.ReadAllTextAsync(file.FullName);
            _textDirty = false;
            _markdownRendered = file.Extension.Equals(".md", StringComparison.OrdinalIgnoreCase);
            ShowTextMode();
            if (_markdownRendered)
            {
                MarkdownViewer.Document = MarkdownService.Render(TextEditor.Text);
                MarkdownViewer.Visibility = Visibility.Visible;
                TextEditor.Visibility = Visibility.Collapsed;
                MarkdownModeButton.Visibility = Visibility.Visible;
            }
            else
            {
                MarkdownViewer.Visibility = Visibility.Collapsed;
                TextEditor.Visibility = Visibility.Visible;
                MarkdownModeButton.Visibility = Visibility.Collapsed;
            }
        }
        catch (Exception ex)
        {
            TextEditor.Text = ex.Message;
        }
        finally
        {
            _loadingText = false;
            UpdateTextFileName();
            UpdateTextNavigation();
            SyncExplorerSelectionToText();
        }
    }

    private void ShowTextMode()
    {
        PreviewPanel.Visibility = Visibility.Collapsed;
        BackToTextButton.Visibility = Visibility.Collapsed;
        SideTitle.Text = _loc.T("Text");
        SaveTextButton.Visibility = Visibility.Visible;
        if (_textIndex >= 0 && _textIndex < _textFiles.Count && _textFiles[_textIndex].Extension.Equals(".md", StringComparison.OrdinalIgnoreCase))
        {
            MarkdownModeButton.Visibility = Visibility.Visible;
            if (_markdownRendered)
            {
                MarkdownViewer.Document = MarkdownService.Render(TextEditor.Text);
                MarkdownViewer.Visibility = Visibility.Visible;
                TextEditor.Visibility = Visibility.Collapsed;
            }
            else
            {
                MarkdownViewer.Visibility = Visibility.Collapsed;
                TextEditor.Visibility = Visibility.Visible;
            }
        }
        else
        {
            MarkdownModeButton.Visibility = Visibility.Collapsed;
            MarkdownViewer.Visibility = Visibility.Collapsed;
            TextEditor.Visibility = Visibility.Visible;
        }
        _previewImagePath = null;
        ResetPreviewTransform();
        UpdateImageMarker();
        ApplyImageSelectionVisuals();
    }

    private async Task ShowPreviewAsync(ImageItem item)
    {
        if (!ConfirmPendingTextChanges()) return;
        _previewImagePath = item.FullPath;
        _lastSelectedImagePath = item.FullPath;
        PreviewPanel.Visibility = Visibility.Visible;
        TextEditor.Visibility = Visibility.Collapsed;
        MarkdownViewer.Visibility = Visibility.Collapsed;
        BackToTextButton.Visibility = Visibility.Visible;
        BackToTextButton.Content = _loc.T("BackToText");
        SideTitle.Text = _loc.T("Preview");
        SaveTextButton.Visibility = Visibility.Collapsed;
        MarkdownModeButton.Visibility = Visibility.Collapsed;
        TextFileName.Text = item.Name;
        PreviewError.Visibility = Visibility.Collapsed;
        PreviewImage.Source = null;
        ResetPreviewTransform();

        var source = await _thumbnailService.GetPreviewAsync(item.FullPath, 1800);
        if (source is null)
        {
            PreviewError.Text = _loc.T("Error");
            PreviewError.Visibility = Visibility.Visible;
        }
        else
        {
            PreviewImage.Source = source;
        }
        UpdateImageMarker();
        ApplyImageSelectionVisuals();
    }

    private bool SaveCurrentTextFile()
    {
        if (_textIndex < 0 || _textIndex >= _textFiles.Count) return false;
        try
        {
            File.WriteAllText(_textFiles[_textIndex].FullName, TextEditor.Text);
            _textDirty = false;
            UpdateTextFileName();
            SaveTextButton.IsEnabled = false;
            StatusText.Text = _loc.T("Saved", _textFiles[_textIndex].Name);
            if (_textFiles[_textIndex].Extension.Equals(".md", StringComparison.OrdinalIgnoreCase) && _markdownRendered)
                MarkdownViewer.Document = MarkdownService.Render(TextEditor.Text);
            return true;
        }
        catch (Exception ex)
        {
            ShowNotice(ex.Message, NoticeKind.Error);
            return false;
        }
    }

    private bool ConfirmPendingTextChanges()
    {
        if (!_textDirty || _textIndex < 0 || _textIndex >= _textFiles.Count) return true;
        var file = _textFiles[_textIndex];
        var dialog = new ConfirmWindow(_loc.T("UnsavedTitle"), _loc.T("UnsavedMessage", file.Name), _loc.T("SaveChanges"), _loc.T("DiscardChanges"), _loc.T("Cancel")) { Owner = this };
        dialog.ShowDialog();
        return dialog.Choice switch
        {
            ConfirmChoice.Primary => SaveCurrentTextFile(),
            ConfirmChoice.Secondary => DiscardCurrentTextChanges(),
            _ => false
        };
    }

    private bool DiscardCurrentTextChanges()
    {
        if (_textIndex < 0 || _textIndex >= _textFiles.Count) return true;
        try
        {
            _loadingText = true;
            TextEditor.Text = File.ReadAllText(_textFiles[_textIndex].FullName);
            _textDirty = false;
            SaveTextButton.IsEnabled = false;
            if (_textFiles[_textIndex].Extension.Equals(".md", StringComparison.OrdinalIgnoreCase) && _markdownRendered)
                MarkdownViewer.Document = MarkdownService.Render(TextEditor.Text);
            UpdateTextFileName();
            return true;
        }
        catch
        {
            return true;
        }
        finally
        {
            _loadingText = false;
        }
    }

    private void UpdateTextFileName()
    {
        if (_textIndex < 0 || _textIndex >= _textFiles.Count) { TextFileName.Text = string.Empty; return; }
        var name = _textFiles[_textIndex].Name;
        TextFileName.Text = _textDirty ? $"{name}  • {_loc.T("UnsavedMark")}" : name;
    }

    private void UpdateTextNavigation()
    {
        TextCounter.Text = _textFiles.Count == 0 ? "0 / 0" : $"{_textIndex + 1} / {_textFiles.Count}";
        PreviousTextButton.IsEnabled = _textFiles.Count > 1;
        NextTextButton.IsEnabled = _textFiles.Count > 1;
    }

    private void SyncExplorerSelectionToText()
    {
        if (_textIndex < 0 || _textIndex >= _textFiles.Count) return;
        var path = _textFiles[_textIndex].FullName;
        var item = _explorerItems.FirstOrDefault(x => x.Type == ExplorerItemType.TextFile && x.FullPath.Equals(path, StringComparison.OrdinalIgnoreCase));
        if (item is null) return;
        _suppressExplorerSelection = true;
        ExplorerList.SelectedItem = item;
        ExplorerList.ScrollIntoView(item);
        _suppressExplorerSelection = false;
    }

    private void RestoreLastImageSelection()
    {
        if (string.IsNullOrWhiteSpace(_lastSelectedImagePath)) return;
        var item = _images.FirstOrDefault(i => i.FullPath.Equals(_lastSelectedImagePath, StringComparison.OrdinalIgnoreCase));
        if (item is null) return;
        ImageList.SelectedItem = item;
        ImageList.ScrollIntoView(item);
        UpdateImageMarker();
        Dispatcher.BeginInvoke(new Action(ApplyImageSelectionVisuals), DispatcherPriority.Loaded);
    }

    private void ApplyImageSelectionVisuals()
    {
        foreach (var item in _images)
        {
            if (ImageList.ItemContainerGenerator.ContainerFromItem(item) is not ListBoxItem container) continue;
            var active = PreviewPanel.Visibility == Visibility.Visible && _previewImagePath?.Equals(item.FullPath, StringComparison.OrdinalIgnoreCase) == true;
            var last = _lastSelectedImagePath?.Equals(item.FullPath, StringComparison.OrdinalIgnoreCase) == true;
            if (active)
            {
                container.Background = new SolidColorBrush(Color.FromRgb(220, 238, 255));
                container.BorderBrush = new SolidColorBrush(Color.FromRgb(43, 124, 211));
                container.BorderThickness = new Thickness(2);
            }
            else if (last)
            {
                container.Background = new SolidColorBrush(Color.FromRgb(238, 245, 250));
                container.BorderBrush = new SolidColorBrush(Color.FromRgb(168, 200, 227));
                container.BorderThickness = new Thickness(1);
            }
            else
            {
                container.ClearValue(Control.BackgroundProperty);
                container.ClearValue(Control.BorderBrushProperty);
                container.ClearValue(Control.BorderThicknessProperty);
            }
        }
    }

    private void UpdateImageMarker()
    {
        if (string.IsNullOrWhiteSpace(_lastSelectedImagePath) || _images.Count == 0)
        {
            ImageScrollMarker.Visibility = Visibility.Collapsed;
            return;
        }
        var index = _images.ToList().FindIndex(i => i.FullPath.Equals(_lastSelectedImagePath, StringComparison.OrdinalIgnoreCase));
        if (index < 0 || ImageMarkerLayer.ActualHeight <= 0)
        {
            ImageScrollMarker.Visibility = Visibility.Collapsed;
            return;
        }
        var ratio = _images.Count <= 1 ? 0 : (double)index / (_images.Count - 1);
        var available = Math.Max(0, ImageMarkerLayer.ActualHeight - 4);
        Canvas.SetTop(ImageScrollMarker, ratio * available);
        ImageScrollMarker.Visibility = Visibility.Visible;
    }

    private void UpdateNavigationButtons()
    {
        BackButton.IsEnabled = _history.Count > 0;
        HomeButton.IsEnabled = _rootFolder is not null && _currentFolder is not null && !_currentFolder.Equals(_rootFolder, StringComparison.OrdinalIgnoreCase);
        UpButton.IsEnabled = _currentFolder is not null && Directory.GetParent(_currentFolder) is not null;
    }

    private async void Window_PreviewKeyDown(object sender, KeyEventArgs e)
    {
        if ((Keyboard.Modifiers & ModifierKeys.Control) != 0 && e.Key == Key.S)
        {
            if (_textDirty) SaveCurrentTextFile();
            e.Handled = true;
            return;
        }
        if ((Keyboard.Modifiers & ModifierKeys.Control) != 0 && e.Key == Key.V && !TextEditor.IsKeyboardFocusWithin)
        {
            await PasteClipboardAsync();
            e.Handled = true;
            return;
        }
        if (e.Key == Key.F5 && _currentFolder is not null)
        {
            await ReloadCurrentFolderAsync();
            e.Handled = true;
            return;
        }
        if (e.Key == Key.Escape && PreviewPanel.Visibility == Visibility.Visible)
        {
            ShowTextMode();
            e.Handled = true;
        }
    }

    private async void BackButton_Click(object sender, RoutedEventArgs e)
    {
        if (_history.Count == 0 || !ConfirmPendingTextChanges()) return;
        var target = _history[^1];
        _history.RemoveAt(_history.Count - 1);
        await NavigateToAsync(target, addHistory: false, confirmChanges: false);
    }

    private async void UpButton_Click(object sender, RoutedEventArgs e)
    {
        if (_currentFolder is null) return;
        var parent = Directory.GetParent(_currentFolder)?.FullName;
        if (parent is not null) await NavigateToAsync(parent);
    }

    private async void HomeButton_Click(object sender, RoutedEventArgs e)
    {
        if (_rootFolder is not null) await NavigateToAsync(_rootFolder);
    }

    private async void SortCombo_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_initializingControls || _currentFolder is null) return;
        var files = await Task.Run(() => Directory.GetFiles(_currentFolder).Where(FileService.IsImage).Select(p => new FileInfo(p)).ToList());
        await LoadImagesAsync(files);
        SaveSettings();
    }

    private async void ExplorerList_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_suppressExplorerSelection || ExplorerList.SelectedItem is not ExplorerItem item) return;
        if (item.Type == ExplorerItemType.TextFile)
        {
            var index = _textFiles.FindIndex(f => f.FullName.Equals(item.FullPath, StringComparison.OrdinalIgnoreCase));
            if (index >= 0) await OpenTextByIndexAsync(index);
        }
    }

    private async void ExplorerList_MouseDoubleClick(object sender, MouseButtonEventArgs e)
    {
        if (ExplorerList.SelectedItem is ExplorerItem { Type: ExplorerItemType.Folder } item)
            await NavigateToAsync(item.FullPath);
    }

    private async void ImageList_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (ImageList.SelectedItem is not ImageItem item) return;
        _lastSelectedImagePath = item.FullPath;
        UpdateImageMarker();
        ApplyImageSelectionVisuals();
        if (ImageList.SelectedItems.Count == 1) await ShowPreviewAsync(item);
    }

    private void BackToTextButton_Click(object sender, RoutedEventArgs e) => ShowTextMode();

    private void SaveTextButton_Click(object sender, RoutedEventArgs e) => SaveCurrentTextFile();

    private void MarkdownModeButton_Click(object sender, RoutedEventArgs e)
    {
        if (_textIndex < 0 || !_textFiles[_textIndex].Extension.Equals(".md", StringComparison.OrdinalIgnoreCase)) return;
        _markdownRendered = !_markdownRendered;
        if (_markdownRendered)
        {
            MarkdownViewer.Document = MarkdownService.Render(TextEditor.Text);
            MarkdownViewer.Visibility = Visibility.Visible;
            TextEditor.Visibility = Visibility.Collapsed;
        }
        else
        {
            MarkdownViewer.Visibility = Visibility.Collapsed;
            TextEditor.Visibility = Visibility.Visible;
            TextEditor.Focus();
        }
        MarkdownModeButton.Content = _markdownRendered ? _loc.T("Edit") : _loc.T("Preview");
    }

    private void TextEditor_TextChanged(object sender, TextChangedEventArgs e)
    {
        if (_loadingText || _textIndex < 0) return;
        _textDirty = true;
        SaveTextButton.IsEnabled = true;
        UpdateTextFileName();
    }

    private async void PreviousTextButton_Click(object sender, RoutedEventArgs e) => await OpenTextByIndexAsync(_textIndex - 1);
    private async void NextTextButton_Click(object sender, RoutedEventArgs e) => await OpenTextByIndexAsync(_textIndex + 1);

    private void ResetPreviewTransform()
    {
        _previewScale.ScaleX = _previewScale.ScaleY = 1;
        _previewTranslate.X = _previewTranslate.Y = 0;
        _previewDragging = false;
        _previewDragMoved = false;
        PreviewPanel.Cursor = Cursors.Hand;
    }

    private void PreviewPanel_MouseLeftButtonDown(object sender, MouseButtonEventArgs e)
    {
        if (PreviewImage.Source is null) return;
        if (_previewScale.ScaleX <= 1)
        {
            _previewScale.ScaleX = _previewScale.ScaleY = 3;
            _previewTranslate.X = _previewTranslate.Y = 0;
            PreviewPanel.Cursor = Cursors.SizeAll;
            e.Handled = true;
            return;
        }
        _previewDragging = true;
        _previewDragMoved = false;
        _previewDragStart = e.GetPosition(PreviewPanel);
        _previewOriginX = _previewTranslate.X;
        _previewOriginY = _previewTranslate.Y;
        PreviewPanel.CaptureMouse();
        e.Handled = true;
    }

    private void PreviewPanel_MouseMove(object sender, MouseEventArgs e)
    {
        if (!_previewDragging || e.LeftButton != MouseButtonState.Pressed) return;
        var point = e.GetPosition(PreviewPanel);
        var dx = point.X - _previewDragStart.X;
        var dy = point.Y - _previewDragStart.Y;
        if (Math.Abs(dx) > 2 || Math.Abs(dy) > 2) _previewDragMoved = true;
        _previewTranslate.X = _previewOriginX + dx;
        _previewTranslate.Y = _previewOriginY + dy;
    }

    private void PreviewPanel_MouseLeftButtonUp(object sender, MouseButtonEventArgs e)
    {
        if (!_previewDragging) return;
        PreviewPanel.ReleaseMouseCapture();
        _previewDragging = false;
        if (!_previewDragMoved) ResetPreviewTransform();
    }

    private void TextEditor_PreviewMouseRightButtonUp(object sender, MouseButtonEventArgs e)
    {
        var menu = new ContextMenu();
        AddMenuItem(menu, _loc.T("Cut"), () => TextEditor.Cut(), !TextEditor.IsReadOnly && TextEditor.SelectionLength > 0);
        AddMenuItem(menu, _loc.T("Copy"), () => TextEditor.Copy(), TextEditor.SelectionLength > 0);
        AddMenuItem(menu, _loc.T("Paste"), () => TextEditor.Paste(), !TextEditor.IsReadOnly && Clipboard.ContainsText());
        menu.Items.Add(new Separator());
        AddMenuItem(menu, _loc.T("SelectAll"), () => TextEditor.SelectAll(), TextEditor.Text.Length > 0);
        TextEditor.ContextMenu = menu;
        menu.IsOpen = true;
        e.Handled = true;
    }

    private void ExplorerList_PreviewMouseRightButtonUp(object sender, MouseButtonEventArgs e)
    {
        var container = FindAncestor<ListBoxItem>(e.OriginalSource as DependencyObject);
        var menu = new ContextMenu();
        if (container?.DataContext is ExplorerItem item)
        {
            ExplorerList.SelectedItem = item;
            if (item.Type == ExplorerItemType.Folder)
            {
                AddMenuItem(menu, _loc.T("Open"), () => _ = NavigateToAsync(item.FullPath));
                menu.Items.Add(new Separator());
                AddMenuItem(menu, _loc.T("Cut"), () => FileService.PutFilesOnClipboard([item.FullPath], true));
                AddMenuItem(menu, _loc.T("Copy"), () => FileService.PutFilesOnClipboard([item.FullPath], false));
                menu.Items.Add(new Separator());
                AddMenuItem(menu, _loc.T("Rename"), () => RenameExplorerItem(item));
                AddMenuItem(menu, _loc.T("Delete"), () => DeleteExplorerItem(item));
            }
            else
            {
                AddMenuItem(menu, _loc.T("Open"), () => _ = OpenTextPathAsync(item.FullPath));
                menu.Items.Add(new Separator());
                AddMenuItem(menu, _loc.T("Cut"), () => FileService.PutFilesOnClipboard([item.FullPath], true));
                AddMenuItem(menu, _loc.T("Copy"), () => FileService.PutFilesOnClipboard([item.FullPath], false));
                menu.Items.Add(new Separator());
                AddMenuItem(menu, _loc.T("Rename"), () => RenameExplorerItem(item));
                AddMenuItem(menu, _loc.T("Delete"), () => DeleteExplorerItem(item));
            }
        }
        else
        {
            var clip = FileService.ReadClipboardFiles();
            AddMenuItem(menu, _loc.T("Paste"), () => _ = PasteClipboardAsync(), clip.Paths.Count > 0);
            menu.Items.Add(new Separator());
            AddMenuItem(menu, _loc.T("CreateFolder"), CreateFolder);
            AddMenuItem(menu, _loc.T("CreateTxt"), () => CreateTextFile(".txt"));
            AddMenuItem(menu, _loc.T("CreateMd"), () => CreateTextFile(".md"));
        }
        ExplorerList.ContextMenu = menu;
        menu.IsOpen = true;
        e.Handled = true;
    }

    private void ImageList_PreviewMouseRightButtonUp(object sender, MouseButtonEventArgs e)
    {
        var container = FindAncestor<ListBoxItem>(e.OriginalSource as DependencyObject);
        var menu = new ContextMenu();
        if (container?.DataContext is ImageItem item)
        {
            if (!ImageList.SelectedItems.Contains(item)) ImageList.SelectedItem = item;
            var selected = ImageList.SelectedItems.Cast<ImageItem>().Select(i => i.FullPath).ToList();
            AddMenuItem(menu, _loc.T("Cut"), () => FileService.PutFilesOnClipboard(selected, true));
            AddMenuItem(menu, _loc.T("Copy"), () => FileService.PutFilesOnClipboard(selected, false));
            menu.Items.Add(new Separator());
            AddMenuItem(menu, _loc.T("Rename"), () => RenameImage(item), selected.Count == 1);
            AddMenuItem(menu, _loc.T("Delete"), () => DeleteImage(item), selected.Count == 1);
        }
        else
        {
            var clip = FileService.ReadClipboardFiles();
            AddMenuItem(menu, _loc.T("Paste"), () => _ = PasteClipboardAsync(), clip.Paths.Count > 0);
        }
        ImageList.ContextMenu = menu;
        menu.IsOpen = true;
        e.Handled = true;
    }

    private static T? FindAncestor<T>(DependencyObject? child) where T : DependencyObject
    {
        while (child is not null)
        {
            if (child is T typed) return typed;
            child = VisualTreeHelper.GetParent(child);
        }
        return null;
    }

    private static void AddMenuItem(ContextMenu menu, string header, Action action, bool enabled = true)
    {
        var item = new MenuItem { Header = header, IsEnabled = enabled };
        item.Click += (_, _) => action();
        menu.Items.Add(item);
    }

    private async Task OpenTextPathAsync(string path)
    {
        var index = _textFiles.FindIndex(f => f.FullName.Equals(path, StringComparison.OrdinalIgnoreCase));
        if (index >= 0) await OpenTextByIndexAsync(index);
    }

    private void RenameExplorerItem(ExplorerItem item)
    {
        if (!ConfirmPendingTextChanges()) return;
        var dialog = new TextInputWindow(_loc.T("Rename"), _loc.T("RenamePrompt"), item.Name, _loc.T("Yes"), _loc.T("Cancel")) { Owner = this };
        if (dialog.ShowDialog() != true || string.IsNullOrWhiteSpace(dialog.Value) || dialog.Value == item.Name) return;
        var name = dialog.Value.Trim();
        if (name.IndexOfAny(Path.GetInvalidFileNameChars()) >= 0 || Path.GetFileName(name) != name) return;
        var destination = Path.Combine(Path.GetDirectoryName(item.FullPath)!, name);
        if (File.Exists(destination) || Directory.Exists(destination)) return;
        try
        {
            if (item.Type == ExplorerItemType.Folder) Directory.Move(item.FullPath, destination);
            else File.Move(item.FullPath, destination);
            _ = ReloadCurrentFolderAsync();
        }
        catch (Exception ex) { ShowNotice(ex.Message, NoticeKind.Error); }
    }

    private void DeleteExplorerItem(ExplorerItem item)
    {
        if (!ConfirmPendingTextChanges()) return;
        var message = item.Type == ExplorerItemType.Folder ? _loc.T("DeleteFolderQuestion", item.Name) : _loc.T("DeleteFileQuestion", item.Name);
        var dialog = new ConfirmWindow(_loc.T("Delete"), message, _loc.T("Yes"), string.Empty, _loc.T("No"), showSecondary: false) { Owner = this };
        dialog.ShowDialog();
        if (dialog.Choice != ConfirmChoice.Primary) return;
        try { FileService.SendToRecycleBin(item.FullPath); _ = ReloadCurrentFolderAsync(); }
        catch (Exception ex) { ShowNotice(ex.Message, NoticeKind.Error); }
    }

    private void RenameImage(ImageItem item)
    {
        var dialog = new TextInputWindow(_loc.T("Rename"), _loc.T("RenamePrompt"), item.Name, _loc.T("Yes"), _loc.T("Cancel")) { Owner = this };
        if (dialog.ShowDialog() != true || string.IsNullOrWhiteSpace(dialog.Value) || dialog.Value == item.Name) return;
        var name = dialog.Value.Trim();
        if (name.IndexOfAny(Path.GetInvalidFileNameChars()) >= 0 || Path.GetFileName(name) != name) return;
        var destination = Path.Combine(Path.GetDirectoryName(item.FullPath)!, name);
        if (File.Exists(destination)) return;
        try
        {
            File.Move(item.FullPath, destination);
            if (_lastSelectedImagePath?.Equals(item.FullPath, StringComparison.OrdinalIgnoreCase) == true) _lastSelectedImagePath = destination;
            _ = ReloadCurrentFolderAsync();
        }
        catch (Exception ex) { ShowNotice(ex.Message, NoticeKind.Error); }
    }

    private void DeleteImage(ImageItem item)
    {
        var dialog = new ConfirmWindow(_loc.T("Delete"), _loc.T("DeleteFileQuestion", item.Name), _loc.T("Yes"), string.Empty, _loc.T("No"), false) { Owner = this };
        dialog.ShowDialog();
        if (dialog.Choice != ConfirmChoice.Primary) return;
        try
        {
            FileService.SendToRecycleBin(item.FullPath);
            if (_lastSelectedImagePath?.Equals(item.FullPath, StringComparison.OrdinalIgnoreCase) == true) _lastSelectedImagePath = null;
            if (_previewImagePath?.Equals(item.FullPath, StringComparison.OrdinalIgnoreCase) == true) ShowTextMode();
            _ = ReloadCurrentFolderAsync();
        }
        catch (Exception ex) { ShowNotice(ex.Message, NoticeKind.Error); }
    }

    private void CreateFolder()
    {
        if (_currentFolder is null) return;
        var dialog = new TextInputWindow(_loc.T("CreateFolder"), _loc.T("Name"), _loc.T("NewFolder"), _loc.T("Yes"), _loc.T("Cancel")) { Owner = this };
        if (dialog.ShowDialog() != true || string.IsNullOrWhiteSpace(dialog.Value)) return;
        var path = Path.Combine(_currentFolder, dialog.Value.Trim());
        if (Directory.Exists(path) || File.Exists(path)) return;
        try { Directory.CreateDirectory(path); _ = ReloadCurrentFolderAsync(); }
        catch (Exception ex) { ShowNotice(ex.Message, NoticeKind.Error); }
    }

    private void CreateTextFile(string extension)
    {
        if (_currentFolder is null) return;
        var defaultName = extension.Equals(".md", StringComparison.OrdinalIgnoreCase) ? _loc.T("NewMarkdown") : _loc.T("NewFile");
        var dialog = new TextInputWindow(extension == ".md" ? _loc.T("CreateMd") : _loc.T("CreateTxt"), _loc.T("Name"), defaultName, _loc.T("Yes"), _loc.T("Cancel")) { Owner = this };
        if (dialog.ShowDialog() != true || string.IsNullOrWhiteSpace(dialog.Value)) return;
        var name = dialog.Value.Trim();
        if (!name.EndsWith(extension, StringComparison.OrdinalIgnoreCase)) name += extension;
        var path = Path.Combine(_currentFolder, name);
        if (File.Exists(path) || Directory.Exists(path)) return;
        try
        {
            File.WriteAllText(path, string.Empty);
            _ = ReloadCurrentFolderAndOpenTextAsync(path);
        }
        catch (Exception ex) { ShowNotice(ex.Message, NoticeKind.Error); }
    }

    private async Task ReloadCurrentFolderAndOpenTextAsync(string path)
    {
        await ReloadCurrentFolderAsync();
        await OpenTextPathAsync(path);
    }

    private async Task PasteClipboardAsync()
    {
        if (_currentFolder is null) return;
        var clip = FileService.ReadClipboardFiles();
        if (clip.Paths.Count == 0) { StatusText.Text = _loc.T("ClipboardEmpty"); return; }
        try
        {
            await FileService.MoveOrCopyAsync(clip.Paths, _currentFolder, clip.IsCut);
            if (clip.IsCut) Clipboard.Clear();
            await ReloadCurrentFolderAsync();
        }
        catch (Exception ex) { ShowNotice(ex.Message, NoticeKind.Error); }
    }
    private void ImageMarkerLayer_SizeChanged(object sender, SizeChangedEventArgs e) => UpdateImageMarker();

    private void ShowNotice(string message, NoticeKind kind = NoticeKind.Info)
    {
        var title = kind == NoticeKind.Error ? _loc.T("Error") : kind == NoticeKind.Warning ? _loc.T("Warning") : "Visual Folder Explorer";
        var dialog = new NoticeWindow(title, message, "OK", kind) { Owner = this };
        dialog.ShowDialog();
    }

}
