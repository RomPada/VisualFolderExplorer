using System.Collections.ObjectModel;
using System.Windows;
using System.Windows.Controls;
using VisualFolderExplorer.Models;
using VisualFolderExplorer.Services;

namespace VisualFolderExplorer.Windows;

public partial class MetadataCleanupWindow : Window
{
    private readonly LocalizationService _loc;
    private readonly string _folder;
    private readonly IReadOnlyList<string> _selectedImages;
    private readonly ObservableCollection<MetadataCleanupRow> _rows = [];
    private readonly string _session = DateTime.Now.ToString("yyyyMMdd_HHmmss") + "_" + Guid.NewGuid().ToString("N")[..6];
    private bool _busy;
    public bool AppliedChanges { get; private set; }

    public MetadataCleanupWindow(LocalizationService loc, string folder, IReadOnlyList<string> selectedImages)
    {
        InitializeComponent();
        _loc = loc;
        _folder = folder;
        _selectedImages = selectedImages.Where(MetadataCleanupService.SupportsFile).Where(File.Exists).ToList();
        FilesGrid.ItemsSource = _rows;
        ApplyLabels();
        ScopeCombo.SelectedIndex = _selectedImages.Count > 0 ? 0 : 1;
        ((ComboBoxItem)ScopeCombo.Items[0]).IsEnabled = _selectedImages.Count > 0;
        BackupPathText.Text = BackupFolder;
        SummaryText.Text = _loc.T("MetaScanHint");
    }

    private string BackupFolder => Path.Combine(_folder, "_VFE_MetadataBackups", _session);

    private void ApplyLabels()
    {
        Title = _loc.T("MetadataClean");
        HeadingText.Text = _loc.T("MetadataClean");
        ScopeLabel.Text = _loc.T("MetaScope");
        ((ComboBoxItem)ScopeCombo.Items[0]).Content = _loc.T("MetaSelectedScope", _selectedImages.Count);
        ((ComboBoxItem)ScopeCombo.Items[1]).Content = _loc.T("MetaAllScope");
        FormatLabel.Text = _loc.T("MetaFormats");
        ScanButton.Content = _loc.T("MetaScan");
        FieldsLabel.Text = _loc.T("MetaFields");
        TitleCheck.Content = _loc.T("MetaTitle");
        SubjectCheck.Content = _loc.T("MetaSubject");
        CommentsCheck.Content = _loc.T("MetaComments");
        AuthorsCheck.Content = _loc.T("MetaAuthors");
        PreviewTitle.Text = _loc.T("MetaPreview");
        BackupLabel.Text = _loc.T("MetaBackup");
        OpenBackupButton.Content = _loc.T("MetaOpenBackup");
        SafetyHint.Text = _loc.T("MetaSafety");
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
        _rows.Clear();
        PreviewFields.Text = "";
        try
        {
            var paths = (ScopeCombo.SelectedIndex == 0 && _selectedImages.Count > 0
                ? _selectedImages.ToList()
                : Directory.EnumerateFiles(_folder).Where(MetadataCleanupService.SupportsFile).OrderBy(Path.GetFileName).ToList());
            var progress = new Progress<(int Done, int Total)>(p =>
            {
                SummaryText.Text = _loc.T("MetaScanning", p.Done, p.Total);
                Progress.Value = p.Total == 0 ? 0 : (100.0 * p.Done / p.Total);
            });
            var found = await MetadataCleanupService.ScanAsync(paths, progress, CancellationToken.None);
            foreach (var row in found)
            {
                row.Selected = row.HasValues && string.IsNullOrWhiteSpace(row.ScanError);
                row.Status = string.IsNullOrWhiteSpace(row.ScanError)
                    ? row.HasValues ? _loc.T("MetaReady") : _loc.T("MetaEmpty")
                    : row.ScanError;
                _rows.Add(row);
            }
            SummaryText.Text = _loc.T("MetaScanned", _rows.Count, _rows.Count(r => r.HasValues && string.IsNullOrWhiteSpace(r.ScanError)));
            if (_rows.Count > 0) FilesGrid.SelectedIndex = 0;
        }
        catch (Exception ex) { ShowError(ex.Message); }
        finally { _busy = false; SetBusy(false); RefreshPreview(); }
    }

    private MetadataFields ChosenFields()
    {
        MetadataFields result = MetadataFields.None;
        if (TitleCheck.IsChecked == true) result |= MetadataFields.Title;
        if (SubjectCheck.IsChecked == true) result |= MetadataFields.Subject;
        if (CommentsCheck.IsChecked == true) result |= MetadataFields.Comments;
        if (AuthorsCheck.IsChecked == true) result |= MetadataFields.Authors;
        return result;
    }

    private void FilesGrid_SelectionChanged(object sender, SelectionChangedEventArgs e) => RefreshPreview();
    private void FieldChoice_Changed(object sender, RoutedEventArgs e)
    {
        if (FilesGrid is not null) RefreshPreview();
    }

    private void OpenBackupButton_Click(object sender, RoutedEventArgs e)
    {
        if (!Directory.Exists(BackupFolder)) return;
        System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo("explorer.exe", $"\"{BackupFolder}\"")
        { UseShellExecute = true });
    }

    private void RefreshPreview()
    {
        if (FilesGrid.SelectedItem is not MetadataCleanupRow row)
        {
            PreviewFile.Text = "";
            PreviewFields.Text = _loc.T("MetaPreviewHint");
            return;
        }
        PreviewFile.Text = row.FileName;
        var fields = ChosenFields();
        string Field(string label, string value, MetadataFields flag)
        {
            var before = string.IsNullOrEmpty(value) ? "—" : value;
            var after = (fields & flag) != 0 && !string.IsNullOrEmpty(value) ? "  →  [—]" : "";
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
        ScopeCombo.IsEnabled = !busy;
        TitleCheck.IsEnabled = SubjectCheck.IsEnabled = CommentsCheck.IsEnabled = AuthorsCheck.IsEnabled = !busy;
        FilesGrid.IsEnabled = !busy;
        ApplyButton.IsEnabled = !busy;
        Progress.Visibility = busy ? Visibility.Visible : Visibility.Collapsed;
        CloseButton.IsEnabled = !busy;
    }

    private async void ApplyButton_Click(object sender, RoutedEventArgs e)
    {
        if (_busy) return;
        FilesGrid.CommitEdit(DataGridEditingUnit.Cell, true);
        FilesGrid.CommitEdit(DataGridEditingUnit.Row, true);
        var fields = ChosenFields();
        if (fields == MetadataFields.None) { ShowError(_loc.T("MetaSelectFields")); return; }
        var selected = _rows.Where(r => r.Selected && string.IsNullOrWhiteSpace(r.ScanError) &&
            (MetadataCleanupService.GetPopulatedFlags(r) & fields) != 0).ToList();
        if (selected.Count == 0) { ShowError(_loc.T("MetaNothing")); return; }

        var confirmation = new ConfirmWindow(_loc.T("MetadataClean"), _loc.T("MetaConfirm", selected.Count, BackupFolder),
            _loc.T("MetaApply"), "", _loc.T("Cancel"), false) { Owner = this };
        confirmation.ShowDialog();
        if (confirmation.Choice != ConfirmChoice.Primary) return;

        _busy = true;
        SetBusy(true);
        try
        {
            var progress = new Progress<(int Done, int Total)>(p =>
            {
                Progress.Value = p.Total == 0 ? 0 : 100.0 * p.Done / p.Total;
                SummaryText.Text = _loc.T("MetaProcessing", p.Done, p.Total);
            });
            var results = await MetadataCleanupService.CleanAsync(selected, fields, BackupFolder, progress, CancellationToken.None);
            var ok = results.Count(r => r.Succeeded);
            var fail = results.Count - ok;
            AppliedChanges |= results.Any(r => r.Succeeded && r.BackupPath is not null);
            for (int i = 0; i < selected.Count && i < results.Count; i++)
                selected[i].Status = results[i].Succeeded ? _loc.T("MetaDone") : _loc.T("MetaFailed") + ": " + results[i].Message;

            // Refresh successful rows from disk so the preview shows current values,
            // not the old fields that were just removed.
            var successRows = selected.Where((row, i) => results[i].Succeeded && results[i].BackupPath is not null).ToList();
            if (successRows.Count > 0)
            {
                var refreshed = await MetadataCleanupService.ScanAsync(successRows.Select(r => r.Path).ToList(), null, CancellationToken.None);
                for (var i = 0; i < refreshed.Count; i++)
                {
                    var position = _rows.IndexOf(successRows[i]);
                    if (position < 0) continue;
                    refreshed[i].Status = _loc.T("MetaDone");
                    refreshed[i].Selected = false;
                    _rows[position] = refreshed[i];
                }
            }
            SummaryText.Text = _loc.T("MetaFinished", ok, fail);
            BackupPathText.Text = BackupFolder;
            OpenBackupButton.IsEnabled = Directory.Exists(BackupFolder);
            var notice = new NoticeWindow(_loc.T("MetadataClean"), SummaryText.Text + "\n" +
                _loc.T("MetaBackupLocation", BackupFolder), "OK", fail > 0 ? NoticeKind.Warning : NoticeKind.Info) { Owner = this };
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
