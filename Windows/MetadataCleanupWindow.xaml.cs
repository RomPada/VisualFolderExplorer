using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Windows;
using System.Windows.Controls;
using VisualFolderExplorer.Models;
using VisualFolderExplorer.Services;

namespace VisualFolderExplorer.Windows;

public partial class MetadataCleanupWindow : Window
{
    private readonly LocalizationService _loc;
    private readonly string _folder;
    private readonly HashSet<string> _initialSelectedPaths;
    private readonly ObservableCollection<MetadataCleanupRow> _rows = [];
    private bool _busy;
    private bool _updatingSelectAll;
    public bool AppliedChanges { get; private set; }

    public MetadataCleanupWindow(LocalizationService loc, string folder, IReadOnlyList<string> selectedImages)
    {
        InitializeComponent();
        _loc = loc;
        _folder = folder;
        _initialSelectedPaths = selectedImages.Where(MetadataCleanupService.SupportsFile)
            .Select(Path.GetFullPath).ToHashSet(StringComparer.OrdinalIgnoreCase);
        FilesGrid.ItemsSource = _rows;
        ApplyLabels();
        SummaryText.Text = _loc.T("MetaScanHint");
        UpdateSelectionHeader();
    }

    private void ApplyLabels()
    {
        Title = _loc.T("MetadataClean");
        HeadingText.Text = _loc.T("MetadataClean");
        ScanButton.Content = _loc.T("MetaScan");
        FieldsLabel.Text = _loc.T("MetaFields");
        TitleCheck.Content = _loc.T("MetaTitle");
        SubjectCheck.Content = _loc.T("MetaSubject");
        CommentsCheck.Content = _loc.T("MetaComments");
        AuthorsCheck.Content = _loc.T("MetaAuthors");
        PreviewTitle.Text = _loc.T("MetaPreview");
        SelectAllCheck.Content = _loc.T("MetaSelectAll");
        UseCol.Header = _loc.T("MetaPick");
        FileCol.Header = _loc.T("Name");
        TypeCol.Header = _loc.T("MetaFormat");
        TitleCol.Header = _loc.T("MetaTitle");
        SubjectCol.Header = _loc.T("MetaSubject");
        CommentsCol.Header = _loc.T("MetaComments");
        AuthorsCol.Header = _loc.T("MetaAuthors");
        StatusCol.Header = _loc.T("MetaStatus");
        CloseButton.Content = _loc.T("Close");
        ApplyButton.Content = _loc.T("MetaApply");
    }

    private async void Window_Loaded(object sender, RoutedEventArgs e) => await ScanAsync();
    private async void ScanButton_Click(object sender, RoutedEventArgs e) => await ScanAsync();

    private async Task ScanAsync()
    {
        if (_busy) return;
        _busy = true;
        SetBusy(true);
        foreach (var old in _rows) old.PropertyChanged -= Row_PropertyChanged;
        _rows.Clear();
        PreviewFields.Text = string.Empty;
        try
        {
            var paths = await Task.Run(() => Directory.EnumerateFiles(_folder)
                .Where(MetadataCleanupService.SupportsFile)
                .OrderBy(Path.GetFileName).ToList());
            var progress = new Progress<(int Done, int Total)>(v =>
            {
                SummaryText.Text = _loc.T("MetaScanning", v.Done, v.Total);
                Progress.Value = v.Total == 0 ? 0 : 100.0 * v.Done / v.Total;
            });
            var found = await MetadataCleanupService.ScanAsync(paths, progress, CancellationToken.None);
            foreach (var row in found)
            {
                row.Selected = row.CanClean && (_initialSelectedPaths.Count == 0 || _initialSelectedPaths.Contains(Path.GetFullPath(row.Path)));
                row.Status = string.IsNullOrWhiteSpace(row.ScanError)
                    ? row.HasValues ? _loc.T("MetaReady") : _loc.T("MetaEmpty")
                    : row.ScanError;
                row.PropertyChanged += Row_PropertyChanged;
                _rows.Add(row);
            }
            SummaryText.Text = _loc.T("MetaScanned", _rows.Count, _rows.Count(r => r.CanClean));
            if (_rows.Count > 0) FilesGrid.SelectedIndex = 0;
        }
        catch (Exception ex) { ShowError(ex.Message); }
        finally { _busy = false; SetBusy(false); UpdateSelectionHeader(); RefreshPreview(); }
    }

    private MetadataFields ChosenFields()
    {
        var result = MetadataFields.None;
        if (TitleCheck.IsChecked == true) result |= MetadataFields.Title;
        if (SubjectCheck.IsChecked == true) result |= MetadataFields.Subject;
        if (CommentsCheck.IsChecked == true) result |= MetadataFields.Comments;
        if (AuthorsCheck.IsChecked == true) result |= MetadataFields.Authors;
        return result;
    }

    private void Row_PropertyChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName == nameof(MetadataCleanupRow.Selected)) UpdateSelectionHeader();
    }

    private void SelectAllCheck_Changed(object sender, RoutedEventArgs e)
    {
        if (_updatingSelectAll || _busy) return;
        var check = SelectAllCheck.IsChecked == true;
        _updatingSelectAll = true;
        try
        {
            foreach (var row in _rows.Where(r => r.CanClean)) row.Selected = check;
        }
        finally { _updatingSelectAll = false; }
        UpdateSelectionHeader();
    }

    private void UpdateSelectionHeader()
    {
        if (SelectAllCheck is null || FileSelectionSummary is null) return;
        var eligible = _rows.Count(r => r.CanClean);
        var selected = _rows.Count(r => r.Selected && r.CanClean);
        FileSelectionSummary.Text = _loc.T("MetaSelectedSummary", selected, eligible);
        _updatingSelectAll = true;
        try
        {
            SelectAllCheck.IsChecked = eligible > 0 && selected == eligible;
            SelectAllCheck.IsEnabled = !_busy && eligible > 0;
        }
        finally { _updatingSelectAll = false; }
        if (ApplyButton is not null) ApplyButton.IsEnabled = !_busy && selected > 0 && ChosenFields() != MetadataFields.None;
    }

    private void FilesGrid_SelectionChanged(object sender, SelectionChangedEventArgs e) => RefreshPreview();
    private void FieldChoice_Changed(object sender, RoutedEventArgs e)
    {
        if (FilesGrid is not null) { RefreshPreview(); UpdateSelectionHeader(); }
    }

    private void RefreshPreview()
    {
        if (FilesGrid.SelectedItem is not MetadataCleanupRow row)
        {
            PreviewFile.Text = string.Empty;
            PreviewFields.Text = _loc.T("MetaPreviewHint");
            return;
        }
        PreviewFile.Text = row.FileName;
        var fields = ChosenFields();
        string Field(string label, string value, MetadataFields flag)
        {
            var before = string.IsNullOrEmpty(value) ? "—" : value;
            var after = (fields & flag) != 0 && !string.IsNullOrEmpty(value) ? "  →  [—]" : string.Empty;
            return $"{label}: {before}{after}";
        }
        PreviewFields.Text = string.Join("\n\n",
            Field(_loc.T("MetaTitle"), row.Title, MetadataFields.Title),
            Field(_loc.T("MetaSubject"), row.Subject, MetadataFields.Subject),
            Field(_loc.T("MetaComments"), row.Comments, MetadataFields.Comments),
            Field(_loc.T("MetaAuthors"), row.Authors, MetadataFields.Authors));
        if (!string.IsNullOrWhiteSpace(row.ScanError)) PreviewFields.Text += "\n\n" + row.ScanError;
    }

    private void SetBusy(bool busy)
    {
        ScanButton.IsEnabled = !busy;
        TitleCheck.IsEnabled = SubjectCheck.IsEnabled = CommentsCheck.IsEnabled = AuthorsCheck.IsEnabled = !busy;
        FilesGrid.IsEnabled = !busy;
        Progress.Visibility = busy ? Visibility.Visible : Visibility.Collapsed;
        CloseButton.IsEnabled = !busy;
        UpdateSelectionHeader();
    }

    private async void ApplyButton_Click(object sender, RoutedEventArgs e)
    {
        if (_busy) return;
        var fields = ChosenFields();
        if (fields == MetadataFields.None) { ShowError(_loc.T("MetaSelectFields")); return; }
        var selected = _rows.Where(r => r.Selected && r.CanClean &&
            (MetadataCleanupService.GetPopulatedFlags(r) & fields) != 0).ToList();
        if (selected.Count == 0) { ShowError(_loc.T("MetaNothing")); return; }

        var confirmation = new ConfirmWindow(_loc.T("MetadataClean"), _loc.T("MetaConfirm", selected.Count),
            _loc.T("MetaApply"), string.Empty, _loc.T("Cancel"), false) { Owner = this };
        confirmation.ShowDialog();
        if (confirmation.Choice != ConfirmChoice.Primary) return;

        _busy = true;
        SetBusy(true);
        try
        {
            var progress = new Progress<(int Done, int Total)>(v =>
            {
                Progress.Value = v.Total == 0 ? 0 : 100.0 * v.Done / v.Total;
                SummaryText.Text = _loc.T("MetaProcessing", v.Done, v.Total);
            });
            var results = await MetadataCleanupService.CleanAsync(selected, fields, progress, CancellationToken.None);
            var ok = results.Count(r => r.Succeeded);
            var fail = results.Count - ok;
            AppliedChanges |= results.Any(r => r.Succeeded);
            for (var i = 0; i < selected.Count && i < results.Count; i++)
                selected[i].Status = results[i].Succeeded ? _loc.T("MetaDone") : _loc.T("MetaFailed") + ": " + results[i].Message;

            var successRows = selected.Where((row, i) => results[i].Succeeded).ToList();
            if (successRows.Count > 0)
            {
                var refreshed = await MetadataCleanupService.ScanAsync(successRows.Select(r => r.Path).ToList(), null, CancellationToken.None);
                for (var i = 0; i < refreshed.Count; i++)
                {
                    var position = _rows.IndexOf(successRows[i]);
                    if (position < 0) continue;
                    successRows[i].PropertyChanged -= Row_PropertyChanged;
                    refreshed[i].Status = _loc.T("MetaDone");
                    refreshed[i].Selected = false;
                    refreshed[i].PropertyChanged += Row_PropertyChanged;
                    _rows[position] = refreshed[i];
                }
            }
            SummaryText.Text = _loc.T("MetaFinished", ok, fail);
            var notice = new NoticeWindow(_loc.T("MetadataClean"), SummaryText.Text, "OK",
                fail > 0 ? NoticeKind.Warning : NoticeKind.Info) { Owner = this };
            notice.ShowDialog();
        }
        catch (Exception ex) { ShowError(ex.Message); }
        finally { _busy = false; SetBusy(false); RefreshPreview(); }
    }

    private void ShowError(string message)
    {
        var notice = new NoticeWindow(_loc.T("Warning"), message, "OK", NoticeKind.Warning) { Owner = this };
        notice.ShowDialog();
    }

    private void CloseButton_Click(object sender, RoutedEventArgs e) => Close();
}
