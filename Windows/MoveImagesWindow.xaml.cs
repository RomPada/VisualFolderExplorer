using System.Windows;
using VisualFolderExplorer.Models;
using VisualFolderExplorer.Services;

namespace VisualFolderExplorer.Windows;

public partial class MoveImagesWindow : Window
{
    private readonly LocalizationService _loc;
    private readonly IReadOnlyList<string> _selectedImages;
    public int MovedCount { get; private set; }
    public int RenamedCount { get; private set; }
    public string? DestinationPath { get; private set; }

    public MoveImagesWindow(LocalizationService loc, string? source, string? lastDestination, IReadOnlyList<string>? selectedImages = null)
    {
        InitializeComponent();
        _loc = loc;
        _selectedImages = selectedImages?.Where(File.Exists).Where(FileService.IsImage).Distinct(StringComparer.OrdinalIgnoreCase).ToList() ?? [];
        SourceBox.Text = source ?? string.Empty;
        DestinationBox.Text = lastDestination ?? string.Empty;
        ApplyLanguage();
        SelectedImagesRadio.IsEnabled = _selectedImages.Count > 0;
        if (_selectedImages.Count > 0) SelectedImagesRadio.IsChecked = true;
        else AllImagesRadio.IsChecked = true;
        UpdateModeUi();
    }

    private void ApplyLanguage()
    {
        Title = _loc.T("MoveTitle");
        TitleText.Text = _loc.T("MoveTitle");
        ModeLabel.Text = _loc.T("MoveMode");
        AllImagesRadio.Content = _loc.T("MoveAllImages");
        SelectedImagesRadio.Content = _loc.T("MoveSelectedImages", _selectedImages.Count);
        SourceLabel.Text = _loc.T("From");
        DestinationLabel.Text = _loc.T("To");
        SourceBrowseButton.Content = _loc.T("Browse");
        DestinationBrowseButton.Content = _loc.T("Browse");
        HintText.Text = _loc.T("MoveHint");
        CancelButton.Content = _loc.T("Cancel");
        MoveButton.Content = _loc.T("PreviewMove");
    }

    private void MoveModeChanged(object sender, RoutedEventArgs e) => UpdateModeUi();

    private void UpdateModeUi()
    {
        var selectedMode = SelectedImagesRadio.IsChecked == true && _selectedImages.Count > 0;
        SourceBox.IsEnabled = !selectedMode;
        SourceBrowseButton.IsEnabled = !selectedMode;
        if (selectedMode)
        {
            var folder = _selectedImages.Select(Path.GetDirectoryName).FirstOrDefault(x => !string.IsNullOrWhiteSpace(x));
            if (!string.IsNullOrWhiteSpace(folder)) SourceBox.Text = folder;
            HintText.Text = _loc.T("MoveSelectedHint", _selectedImages.Count);
        }
        else
        {
            HintText.Text = _loc.T("MoveHint");
        }
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
        var selectedMode = SelectedImagesRadio.IsChecked == true && _selectedImages.Count > 0;

        if (!selectedMode && !Directory.Exists(source)) { ShowNotice(_loc.T("MoveSourceMissing"), NoticeKind.Warning); return; }
        if (string.IsNullOrWhiteSpace(destination)) { ShowNotice(_loc.T("MoveDestinationRequired"), NoticeKind.Warning); return; }
        var normalizedDestination = Path.GetFullPath(destination).TrimEnd('\\');
        if (!selectedMode && Path.GetFullPath(source).TrimEnd('\\').Equals(normalizedDestination, StringComparison.OrdinalIgnoreCase)) { ShowNotice(_loc.T("MoveSameFolder"), NoticeKind.Warning); return; }
        if (selectedMode)
        {
            var selectedSourceFolder = _selectedImages.Select(Path.GetDirectoryName).FirstOrDefault(x => !string.IsNullOrWhiteSpace(x));
            if (!string.IsNullOrWhiteSpace(selectedSourceFolder) && Path.GetFullPath(selectedSourceFolder).TrimEnd('\\').Equals(normalizedDestination, StringComparison.OrdinalIgnoreCase))
            {
                ShowNotice(_loc.T("MoveSameFolder"), NoticeKind.Warning);
                return;
            }
        }

        try
        {
            Directory.CreateDirectory(destination);
            var files = selectedMode
                ? _selectedImages.Where(File.Exists).ToList()
                : Directory.GetFiles(source).Where(FileService.IsImage).OrderBy(p => Path.GetFileName(p), NaturalStringComparer.Instance).ToList();

            if (files.Count == 0) { ShowNotice(_loc.T("NoImages"), NoticeKind.Info); return; }
            var plan = FileService.BuildMovePlan(files, destination);
            var preview = new MovePreviewWindow(_loc, plan, destination) { Owner = this };
            if (preview.ShowDialog() != true) return;

            MoveButton.IsEnabled = false;
            await FileService.ExecuteMovePlanAsync(plan);
            MovedCount = plan.Count;
            RenamedCount = plan.Count(x => x.AutoRenamed);
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
