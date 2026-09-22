using System.Windows;
using VisualFolderExplorer.Services;

namespace VisualFolderExplorer.Windows;

public partial class MoveImagesWindow : Window
{
    private readonly LocalizationService _loc;
    public int MovedCount { get; private set; }
    public int RenamedCount { get; private set; }
    public string? DestinationPath { get; private set; }

    public MoveImagesWindow(LocalizationService loc, string? source, string? lastDestination)
    {
        InitializeComponent();
        _loc = loc;
        SourceBox.Text = source ?? string.Empty;
        DestinationBox.Text = lastDestination ?? string.Empty;
        ApplyLanguage();
    }

    private void ApplyLanguage()
    {
        Title = _loc.T("MoveTitle"); TitleText.Text = _loc.T("MoveTitle"); SourceLabel.Text = _loc.T("From"); DestinationLabel.Text = _loc.T("To");
        SourceBrowseButton.Content = _loc.T("Browse"); DestinationBrowseButton.Content = _loc.T("Browse"); HintText.Text = _loc.T("MoveHint");
        CancelButton.Content = _loc.T("Cancel"); MoveButton.Content = _loc.T("Move");
    }

    private void SourceBrowseButton_Click(object sender, RoutedEventArgs e)
    {
        var picker = new FolderPickerWindow(_loc, SourceBox.Text) { Owner = this };
        if (picker.ShowDialog() == true) SourceBox.Text = picker.SelectedPath ?? SourceBox.Text;
    }

    private void DestinationBrowseButton_Click(object sender, RoutedEventArgs e)
    {
        var picker = new FolderPickerWindow(_loc, DestinationBox.Text) { Owner = this };
        if (picker.ShowDialog() == true) DestinationBox.Text = picker.SelectedPath ?? DestinationBox.Text;
    }

    private async void MoveButton_Click(object sender, RoutedEventArgs e)
    {
        var source = SourceBox.Text.Trim();
        var destination = DestinationBox.Text.Trim();
        if (!Directory.Exists(source)) { ShowNotice(_loc.T("MoveSourceMissing"), NoticeKind.Warning); return; }
        if (string.IsNullOrWhiteSpace(destination)) { ShowNotice(_loc.T("MoveDestinationRequired"), NoticeKind.Warning); return; }
        if (Path.GetFullPath(source).TrimEnd('\\').Equals(Path.GetFullPath(destination).TrimEnd('\\'), StringComparison.OrdinalIgnoreCase)) { ShowNotice(_loc.T("MoveSameFolder"), NoticeKind.Warning); return; }

        try
        {
            Directory.CreateDirectory(destination);
            var files = Directory.GetFiles(source).Where(FileService.IsImage).OrderBy(p => Path.GetFileName(p), NaturalStringComparer.Instance).ToList();
            if (files.Count == 0) { ShowNotice(_loc.T("NoImages"), NoticeKind.Info); return; }

            MoveButton.IsEnabled = false;
            foreach (var file in files)
            {
                var desired = Path.Combine(destination, Path.GetFileName(file));
                var final = FileService.GetUniqueDestinationPath(desired);
                if (!final.Equals(desired, StringComparison.OrdinalIgnoreCase)) RenamedCount++;
                await Task.Run(() => FileService.MoveFileSafe(file, final));
                MovedCount++;
            }
            DestinationPath = destination;
            DialogResult = true;
        }
        catch (Exception ex)
        {
            ShowNotice(ex.Message, NoticeKind.Error);
            MoveButton.IsEnabled = true;
        }
    }

    private void CancelButton_Click(object sender, RoutedEventArgs e) => DialogResult = false;
    private void ShowNotice(string message, NoticeKind kind)
    {
        var title = kind == NoticeKind.Error ? _loc.T("Error") : kind == NoticeKind.Warning ? _loc.T("Warning") : _loc.T("MoveTitle");
        var dialog = new NoticeWindow(title, message, "OK", kind) { Owner = this };
        dialog.ShowDialog();
    }

}
