using System.Collections.ObjectModel;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media.Imaging;
using VisualFolderExplorer.Models;
using VisualFolderExplorer.Services;

namespace VisualFolderExplorer.Windows;

public partial class DuplicateResultsWindow : Window
{
    private readonly LocalizationService _loc;
    private readonly ThumbnailService _thumbnailService = new();
    private readonly ObservableCollection<DuplicateRow> _rows = [];
    public IReadOnlyList<string> PathsToSelect { get; private set; } = [];
    public bool DeletedAny { get; private set; }

    public DuplicateResultsWindow(LocalizationService loc, IReadOnlyList<DuplicateGroup> groups)
    {
        InitializeComponent();
        _loc = loc;
        foreach (var group in groups)
        {
            foreach (var path in group.Files)
            {
                _rows.Add(new DuplicateRow
                {
                    GroupNumber = group.GroupNumber,
                    FullPath = path,
                    Name = Path.GetFileName(path),
                    Size = group.Size,
                    SizeText = FormatBytes(group.Size)
                });
            }
        }

        Title = loc.T("DuplicatesTitle");
        TitleText.Text = loc.T("DuplicatesTitle");
        GroupColumn.Header = loc.T("DuplicateGroup");
        NameColumn.Header = loc.T("Name");
        SizeColumn.Header = loc.T("Size");
        PathColumn.Header = loc.T("Path");
        PreviewTitle.Text = loc.T("DuplicatePreview");
        PreviewPlaceholder.Text = loc.T("DuplicatePreview");
        CloseButton.Content = loc.T("Close");
        SelectButton.Content = loc.T("SelectDuplicateCopies");
        DeleteButton.Content = loc.T("DeleteSelected");
        ResultsGrid.ItemsSource = _rows;
        UpdateSummary();
        UpdateButtons();
        if (_rows.Count > 0) ResultsGrid.SelectedIndex = 0;
    }

    private async void ResultsGrid_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        UpdateButtons();
        if (ResultsGrid.SelectedItem is not DuplicateRow row || !File.Exists(row.FullPath))
        {
            PreviewImage.Source = null;
            PreviewName.Text = string.Empty;
            PreviewMeta.Text = string.Empty;
            PreviewPlaceholder.Visibility = Visibility.Visible;
            return;
        }

        PreviewName.Text = row.Name;
        PreviewMeta.Text = row.SizeText;
        PreviewPlaceholder.Visibility = Visibility.Visible;
        PreviewImage.Source = null;
        var previewPath = row.FullPath;
        var bitmap = await _thumbnailService.GetPreviewAsync(previewPath, 900);
        if (bitmap is null || ResultsGrid.SelectedItem is not DuplicateRow current || !current.FullPath.Equals(previewPath, StringComparison.OrdinalIgnoreCase)) return;
        PreviewImage.Source = bitmap;
        PreviewPlaceholder.Visibility = Visibility.Collapsed;
        PreviewMeta.Text = $"{bitmap.PixelWidth} × {bitmap.PixelHeight}  •  {row.SizeText}";
    }

    private void UpdateButtons() => DeleteButton.IsEnabled = ResultsGrid.SelectedItems.Count > 0;

    private void UpdateSummary()
    {
        var duplicateGroups = _rows.GroupBy(r => r.GroupNumber).Count(g => g.Count() > 1);
        var duplicateFiles = _rows.GroupBy(r => r.GroupNumber).Where(g => g.Count() > 1).Sum(g => g.Count());
        SummaryText.Text = _loc.T("DuplicatesSummary", duplicateGroups, duplicateFiles);
    }

    private void SelectButton_Click(object sender, RoutedEventArgs e)
    {
        PathsToSelect = _rows
            .GroupBy(r => r.GroupNumber)
            .Where(g => g.Count() > 1)
            .SelectMany(g => g.Skip(1).Select(r => r.FullPath))
            .ToList();
        DialogResult = true;
    }

    private void DeleteButton_Click(object sender, RoutedEventArgs e)
    {
        var selected = ResultsGrid.SelectedItems.Cast<DuplicateRow>().Where(r => File.Exists(r.FullPath)).ToList();
        if (selected.Count == 0) return;
        var confirm = new ConfirmWindow(_loc.T("Delete"), _loc.T("DeleteDuplicatesQuestion", selected.Count), _loc.T("Yes"), string.Empty, _loc.T("No"), false) { Owner = this };
        confirm.ShowDialog();
        if (confirm.Choice != ConfirmChoice.Primary) return;

        var deleted = 0;
        foreach (var row in selected)
        {
            try
            {
                FileService.SendToRecycleBin(row.FullPath);
                _rows.Remove(row);
                deleted++;
            }
            catch { }
        }

        // A group with only one remaining file is no longer a duplicate group.
        var orphanRows = _rows.GroupBy(r => r.GroupNumber).Where(g => g.Count() < 2).SelectMany(g => g).ToList();
        foreach (var row in orphanRows) _rows.Remove(row);

        DeletedAny |= deleted > 0;
        UpdateSummary();
        PreviewImage.Source = null;
        PreviewName.Text = string.Empty;
        PreviewMeta.Text = deleted > 0 ? _loc.T("DuplicateDeleted", deleted) : string.Empty;
        PreviewPlaceholder.Visibility = Visibility.Visible;
        UpdateButtons();
    }

    private void CloseButton_Click(object sender, RoutedEventArgs e) => DialogResult = false;

    private static string FormatBytes(long bytes)
    {
        string[] units = ["B", "KB", "MB", "GB"];
        double value = bytes;
        var unit = 0;
        while (value >= 1024 && unit < units.Length - 1) { value /= 1024; unit++; }
        return $"{value:0.##} {units[unit]}";
    }

    private sealed class DuplicateRow
    {
        public int GroupNumber { get; init; }
        public required string Name { get; init; }
        public required string FullPath { get; init; }
        public long Size { get; init; }
        public required string SizeText { get; init; }
    }
}
