using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Threading;
using VisualFolderExplorer.Models;
using VisualFolderExplorer.Services;
using VisualFolderExplorer.Windows;

namespace VisualFolderExplorer;

public partial class MainWindow
{
    private const string InternalImageDragFormat = "VisualFolderExplorer.InternalImageDrag";
    private FileSystemWatcher? _folderWatcher;
    private DispatcherTimer? _watcherDebounceTimer;
    private bool _watcherReloading;
    private Point _imageDragStartPoint;
    private bool _imageDragArmed;
    private bool _suppressImageAutoPreview;

    private void ApplySavedLayout()
    {
        ExplorerColumn.Width = new GridLength(Math.Clamp(_settings.ExplorerPaneWidth, 180, 520));
        PreviewColumn.Width = new GridLength(Math.Clamp(_settings.PreviewPaneWidth, 300, 760));
    }

    private void CaptureLayoutSettings()
    {
        _settings.ExplorerPaneWidth = Math.Clamp(ExplorerColumn.ActualWidth, 180, 520);
        _settings.PreviewPaneWidth = Math.Clamp(PreviewColumn.ActualWidth, 300, 760);
    }

    private void BuildBreadcrumb(string path)
    {
        BreadcrumbPanel.Children.Clear();
        if (string.IsNullOrWhiteSpace(path)) return;

        var fullPath = Path.GetFullPath(path);
        var root = Path.GetPathRoot(fullPath) ?? fullPath;
        AddBreadcrumbSegment(root, root.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar));

        var remainder = fullPath.Length > root.Length ? fullPath[root.Length..] : string.Empty;
        var parts = remainder.Split([Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar], StringSplitOptions.RemoveEmptyEntries);
        var current = root;
        foreach (var part in parts)
        {
            BreadcrumbPanel.Children.Add(new TextBlock
            {
                Text = "›",
                Foreground = (Brush)FindResource("MutedTextBrush"),
                VerticalAlignment = VerticalAlignment.Center,
                Margin = new Thickness(1, 0, 1, 0)
            });
            current = Path.Combine(current, part);
            AddBreadcrumbSegment(current, part);
        }

        Dispatcher.BeginInvoke(new Action(() => BreadcrumbScroll.ScrollToHorizontalOffset(double.MaxValue)), DispatcherPriority.Loaded);
    }

    private void AddBreadcrumbSegment(string targetPath, string label)
    {
        if (string.IsNullOrWhiteSpace(label)) label = targetPath;
        var button = new Button
        {
            Content = label,
            Tag = targetPath,
            Style = (Style)FindResource("BreadcrumbButton"),
            ToolTip = targetPath,
            Margin = new Thickness(0)
        };
        button.Click += async (_, _) =>
        {
            if (button.Tag is string target && Directory.Exists(target)) await NavigateToAsync(target);
        };
        BreadcrumbPanel.Children.Add(button);
    }


    private void UpdateSortDirectionLabels()
    {
        if (SortDirectionCombo.Items.Count < 2) return;
        var field = SelectedSortField();
        string ascKey;
        string descKey;
        switch (field)
        {
            case "Size":
                ascKey = "SortSizeAsc"; descKey = "SortSizeDesc"; break;
            case "Created":
            case "Modified":
                ascKey = "SortDateAsc"; descKey = "SortDateDesc"; break;
            default:
                ascKey = "SortNameAsc"; descKey = "SortNameDesc"; break;
        }
        ((ComboBoxItem)SortDirectionCombo.Items[0]).Content = _loc.T(ascKey);
        ((ComboBoxItem)SortDirectionCombo.Items[1]).Content = _loc.T(descKey);
    }

    private ScrollViewer? GetImageScrollViewer() => FindVisualDescendant<ScrollViewer>(ImageList);

    private System.Windows.Controls.Primitives.ScrollBar? GetImageVerticalScrollBar()
    {
        return FindVisualDescendantWhere<System.Windows.Controls.Primitives.ScrollBar>(ImageList,
            bar => bar.Orientation == Orientation.Vertical);
    }

    private static T? FindVisualDescendantWhere<T>(DependencyObject root, Func<T, bool> predicate) where T : DependencyObject
    {
        for (var i = 0; i < VisualTreeHelper.GetChildrenCount(root); i++)
        {
            var child = VisualTreeHelper.GetChild(root, i);
            if (child is T typed && predicate(typed)) return typed;
            var nested = FindVisualDescendantWhere(child, predicate);
            if (nested is not null) return nested;
        }
        return null;
    }

    private static T? FindVisualDescendant<T>(DependencyObject root) where T : DependencyObject
    {
        for (var i = 0; i < VisualTreeHelper.GetChildrenCount(root); i++)
        {
            var child = VisualTreeHelper.GetChild(root, i);
            if (child is T typed) return typed;
            var nested = FindVisualDescendant<T>(child);
            if (nested is not null) return nested;
        }
        return null;
    }

    private void CaptureCurrentFolderViewState()
    {
        if (string.IsNullOrWhiteSpace(_currentFolder)) return;
        var key = Path.GetFullPath(_currentFolder);
        var viewer = GetImageScrollViewer();
        if (viewer is not null) _settings.FolderScrollOffsets[key] = viewer.VerticalOffset;
        if (!string.IsNullOrWhiteSpace(_lastSelectedImagePath) &&
            string.Equals(Path.GetDirectoryName(_lastSelectedImagePath), key, StringComparison.OrdinalIgnoreCase))
            _settings.FolderLastSelectedImages[key] = _lastSelectedImagePath;
    }

    private void RestoreFolderViewState()
    {
        if (string.IsNullOrWhiteSpace(_currentFolder)) return;
        var folder = Path.GetFullPath(_currentFolder);
        var savedPath = _settings.FolderLastSelectedImages.TryGetValue(folder, out var perFolder) ? perFolder : _lastSelectedImagePath;
        if (!string.IsNullOrWhiteSpace(savedPath))
        {
            var item = _images.FirstOrDefault(i => i.FullPath.Equals(savedPath, StringComparison.OrdinalIgnoreCase));
            if (item is not null)
            {
                _lastSelectedImagePath = item.FullPath;
                _suppressImageAutoPreview = true;
                try { ImageList.SelectedItem = item; }
                finally { _suppressImageAutoPreview = false; }
            }
        }

        var hasOffset = _settings.FolderScrollOffsets.TryGetValue(folder, out var offset);
        Dispatcher.BeginInvoke(new Action(() =>
        {
            var viewer = GetImageScrollViewer();
            if (viewer is not null && hasOffset) viewer.ScrollToVerticalOffset(Math.Max(0, offset));
            else if (ImageList.SelectedItem is ImageItem selected) ImageList.ScrollIntoView(selected);
            UpdateImageMarker();
            ApplyImageSelectionVisuals();
        }), DispatcherPriority.Loaded);
    }

    private void UpdatePreviewMetadata(ImageItem item, BitmapSource? source)
    {
        var (pixelWidth, pixelHeight) = ReadOriginalPixelSize(item.FullPath);
        var dimensions = pixelWidth > 0 && pixelHeight > 0 ? $"{pixelWidth} × {pixelHeight}px" : source is null ? "—" : $"{source.PixelWidth} × {source.PixelHeight}px";
        PreviewMetadataInline.Text = $"{_loc.T("Dimensions")}: {dimensions}  •  {_loc.T("FileSize")}: {FormatBytes(item.Length)}  •  {_loc.T("Created")}: {item.CreationTime:g}  •  {_loc.T("Modified")}: {item.LastWriteTime:g}";
    }

    private static (int Width, int Height) ReadOriginalPixelSize(string path)
    {
        try
        {
            using var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete);
            var decoder = BitmapDecoder.Create(stream, BitmapCreateOptions.PreservePixelFormat | BitmapCreateOptions.DelayCreation, BitmapCacheOption.None);
            var frame = decoder.Frames.FirstOrDefault();
            return frame is null ? (0, 0) : (frame.PixelWidth, frame.PixelHeight);
        }
        catch { return (0, 0); }
    }

    private void RefreshPreviewMetadataLanguage()
    {
        if (_previewImagePath is null) return;
        var item = _images.FirstOrDefault(i => i.FullPath.Equals(_previewImagePath, StringComparison.OrdinalIgnoreCase));
        if (item is not null) UpdatePreviewMetadata(item, PreviewImage.Source as BitmapSource);
    }

    private static string FormatBytes(long bytes)
    {
        string[] units = ["B", "KB", "MB", "GB", "TB"];
        double value = bytes;
        var unit = 0;
        while (value >= 1024 && unit < units.Length - 1) { value /= 1024; unit++; }
        return $"{value:0.##} {units[unit]}";
    }

    private void ConfigureFolderWatcher(string folder)
    {
        if (_folderWatcher is not null && string.Equals(_folderWatcher.Path, folder, StringComparison.OrdinalIgnoreCase)) return;
        DisposeFolderWatcher();
        try
        {
            _folderWatcher = new FileSystemWatcher(folder)
            {
                IncludeSubdirectories = false,
                NotifyFilter = NotifyFilters.FileName | NotifyFilters.DirectoryName | NotifyFilters.LastWrite | NotifyFilters.Size | NotifyFilters.CreationTime,
                EnableRaisingEvents = true
            };
            _folderWatcher.Created += FolderWatcher_Changed;
            _folderWatcher.Deleted += FolderWatcher_Changed;
            _folderWatcher.Changed += FolderWatcher_Changed;
            _folderWatcher.Renamed += FolderWatcher_Renamed;

            _watcherDebounceTimer ??= new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(550) };
            _watcherDebounceTimer.Tick -= WatcherDebounceTimer_Tick;
            _watcherDebounceTimer.Tick += WatcherDebounceTimer_Tick;
        }
        catch
        {
            DisposeFolderWatcher();
        }
    }

    private void FolderWatcher_Renamed(object sender, RenamedEventArgs e) => FolderWatcher_Changed(sender, e);

    private void FolderWatcher_Changed(object sender, FileSystemEventArgs e)
    {
        Dispatcher.BeginInvoke(new Action(() =>
        {
            if (_watcherDebounceTimer is null) return;
            _watcherDebounceTimer.Stop();
            _watcherDebounceTimer.Start();
        }));
    }

    private async void WatcherDebounceTimer_Tick(object? sender, EventArgs e)
    {
        _watcherDebounceTimer?.Stop();
        if (_watcherReloading || _currentFolder is null) return;
        if (_textDirty)
        {
            StatusText.Text = _loc.T("WatcherPending");
            if (_watcherDebounceTimer is not null)
            {
                _watcherDebounceTimer.Interval = TimeSpan.FromSeconds(1);
                _watcherDebounceTimer.Start();
            }
            return;
        }

        _watcherReloading = true;
        try { await ReloadCurrentFolderAsync(); }
        finally
        {
            _watcherReloading = false;
            if (_watcherDebounceTimer is not null) _watcherDebounceTimer.Interval = TimeSpan.FromMilliseconds(550);
        }
    }

    private void DisposeFolderWatcher()
    {
        if (_folderWatcher is not null)
        {
            _folderWatcher.EnableRaisingEvents = false;
            _folderWatcher.Created -= FolderWatcher_Changed;
            _folderWatcher.Deleted -= FolderWatcher_Changed;
            _folderWatcher.Changed -= FolderWatcher_Changed;
            _folderWatcher.Renamed -= FolderWatcher_Renamed;
            _folderWatcher.Dispose();
            _folderWatcher = null;
        }
        _watcherDebounceTimer?.Stop();
    }

    private void ImageList_PreviewMouseLeftButtonDown(object sender, MouseButtonEventArgs e)
    {
        _imageDragStartPoint = e.GetPosition(ImageList);
        // Arm file Drag & Drop only when the mouse press started on an image tile.
        // ScrollBar/Thumb are inside the ListBox visual tree too, so without this
        // guard dragging the scrollbar was incorrectly converted into a file drag.
        _imageDragArmed = FindAncestor<ListBoxItem>(e.OriginalSource as DependencyObject) is not null;
    }

    private void ImageList_PreviewMouseMove(object sender, MouseEventArgs e)
    {
        if (e.LeftButton != MouseButtonState.Pressed)
        {
            _imageDragArmed = false;
            return;
        }
        if (!_imageDragArmed || ImageList.SelectedItems.Count == 0) return;

        var current = e.GetPosition(ImageList);
        if (Math.Abs(current.X - _imageDragStartPoint.X) < SystemParameters.MinimumHorizontalDragDistance &&
            Math.Abs(current.Y - _imageDragStartPoint.Y) < SystemParameters.MinimumVerticalDragDistance) return;

        var paths = GetSelectedImagePathsInVisualOrder().Where(File.Exists).ToArray();
        if (paths.Length == 0) return;
        _imageDragArmed = false;
        var data = new DataObject();
        data.SetData(DataFormats.FileDrop, paths);
        data.SetData(InternalImageDragFormat, true);
        DragDrop.DoDragDrop(ImageList, data, DragDropEffects.Move | DragDropEffects.Copy);
    }

    private void ExplorerList_DragOver(object sender, DragEventArgs e)
    {
        if (!e.Data.GetDataPresent(DataFormats.FileDrop) || _currentFolder is null) { e.Effects = DragDropEffects.None; return; }
        e.Effects = e.Data.GetDataPresent(InternalImageDragFormat) ? DragDropEffects.Move : DragDropEffects.Copy;
        e.Handled = true;
    }

    private async void ExplorerList_Drop(object sender, DragEventArgs e)
    {
        if (_currentFolder is null || e.Data.GetData(DataFormats.FileDrop) is not string[] paths) return;
        var container = FindAncestor<ListBoxItem>(e.OriginalSource as DependencyObject);
        var target = container?.DataContext is ExplorerItem explorerTarget &&
                     explorerTarget.Type is ExplorerItemType.Folder or ExplorerItemType.ParentFolder
            ? explorerTarget.FullPath
            : _currentFolder;
        var move = e.Data.GetDataPresent(InternalImageDragFormat);
        try
        {
            await FileService.MoveOrCopyAsync(paths, target, move);
            StatusText.Text = _loc.T("DropDone", paths.Length);
            await ReloadCurrentFolderAsync();
        }
        catch (Exception ex) { ShowNotice(ex.Message, NoticeKind.Error); }
        e.Handled = true;
    }

    private void ImageList_DragOver(object sender, DragEventArgs e)
    {
        if (_currentFolder is null || !e.Data.GetDataPresent(DataFormats.FileDrop)) { e.Effects = DragDropEffects.None; return; }
        e.Effects = e.Data.GetDataPresent(InternalImageDragFormat) ? DragDropEffects.None : DragDropEffects.Copy;
        e.Handled = true;
    }

    private async void ImageList_Drop(object sender, DragEventArgs e)
    {
        if (_currentFolder is null || e.Data.GetDataPresent(InternalImageDragFormat) || e.Data.GetData(DataFormats.FileDrop) is not string[] paths) return;
        try
        {
            await FileService.MoveOrCopyAsync(paths, _currentFolder, false);
            StatusText.Text = _loc.T("DropDone", paths.Length);
            await ReloadCurrentFolderAsync();
        }
        catch (Exception ex) { ShowNotice(ex.Message, NoticeKind.Error); }
        e.Handled = true;
    }
}
