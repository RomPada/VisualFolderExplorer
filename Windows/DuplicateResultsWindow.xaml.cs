using System.Windows;
using VisualFolderExplorer.Models;
using VisualFolderExplorer.Services;

namespace VisualFolderExplorer.Windows;

public partial class DuplicateResultsWindow : Window
{
    private readonly IReadOnlyList<DuplicateGroup> _groups;
    public IReadOnlyList<string> PathsToSelect { get; private set; } = [];

    public DuplicateResultsWindow(LocalizationService loc, IReadOnlyList<DuplicateGroup> groups)
    {
        InitializeComponent();
        _groups = groups;
        var rows = groups.SelectMany(g => g.Files.Select(path => new DuplicateRow
        {
            GroupNumber = g.GroupNumber,
            FullPath = path,
            Name = Path.GetFileName(path),
            SizeText = FormatBytes(g.Size)
        })).ToList();

        Title = loc.T("DuplicatesTitle");
        TitleText.Text = loc.T("DuplicatesTitle");
        SummaryText.Text = loc.T("DuplicatesSummary", groups.Count, rows.Count);
        GroupColumn.Header = loc.T("DuplicateGroup");
        NameColumn.Header = loc.T("Name");
        SizeColumn.Header = loc.T("Size");
        PathColumn.Header = loc.T("Path");
        CloseButton.Content = loc.T("Close");
        SelectButton.Content = loc.T("SelectDuplicateCopies");
        ResultsGrid.ItemsSource = rows;
    }

    private void SelectButton_Click(object sender, RoutedEventArgs e)
    {
        PathsToSelect = _groups.SelectMany(g => g.Files.Skip(1)).ToList();
        DialogResult = true;
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
        public required string SizeText { get; init; }
    }
}
