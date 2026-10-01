using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using VisualFolderExplorer.Services;

namespace VisualFolderExplorer.Windows;

public partial class FolderPickerWindow : Window
{
    private readonly LocalizationService _loc;
    private string _currentPath = string.Empty;
    public string? SelectedPath { get; private set; }

    public FolderPickerWindow(LocalizationService loc, string? initialPath = null)
    {
        InitializeComponent();
        _loc = loc;
        ApplyLanguage();
        var start = Directory.Exists(initialPath) ? initialPath! : Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments);
        Navigate(start);
    }

    private void ApplyLanguage()
    {
        Title = _loc.T("FolderPicker"); TitleText.Text = _loc.T("FolderPicker"); PathLabel.Text = _loc.T("CurrentFolder");
        BrowseAddressButton.Content = _loc.T("BrowseAddress"); UpButton.Content = _loc.T("Up"); EmptyText.Text = _loc.T("NoSubfolders"); CancelButton.Content = _loc.T("Cancel"); SelectButton.Content = _loc.T("SelectThisFolder");
    }


    private bool Navigate(string path)
    {
        try
        {
            if (!Directory.Exists(path)) return false;
            _currentPath = Path.GetFullPath(path);
            SelectedPath = _currentPath;
            PathBox.Text = _currentPath;
            SelectionHint.Text = _currentPath;
            FolderList.ItemsSource = new DirectoryInfo(_currentPath).EnumerateDirectories().OrderBy(d => d.Name, NaturalStringComparer.Instance).ToList();
            EmptyText.Visibility = FolderList.Items.Count == 0 ? Visibility.Visible : Visibility.Collapsed;

            return true;
        }
        catch { return false; }
    }

    private void FolderList_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        SelectedPath = FolderList.SelectedItem is DirectoryInfo info ? info.FullName : _currentPath;
        SelectionHint.Text = SelectedPath;
    }

    private void FolderList_MouseDoubleClick(object sender, MouseButtonEventArgs e)
    {
        if (FolderList.SelectedItem is DirectoryInfo info) Navigate(info.FullName);
    }

    private void UpButton_Click(object sender, RoutedEventArgs e)
    {
        var parent = Directory.GetParent(_currentPath)?.FullName;
        if (!string.IsNullOrWhiteSpace(parent)) Navigate(parent);
    }


    private void BrowseAddressButton_Click(object sender, RoutedEventArgs e)
    {
        using var dialog = new System.Windows.Forms.FolderBrowserDialog
        {
            Description = _loc.T("FolderPicker"),
            ShowNewFolderButton = true,
            SelectedPath = Directory.Exists(_currentPath) ? _currentPath : string.Empty
        };

        if (dialog.ShowDialog() == System.Windows.Forms.DialogResult.OK && Directory.Exists(dialog.SelectedPath))
            Navigate(dialog.SelectedPath);
    }

    private void PathBox_KeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.Enter) { Navigate(PathBox.Text.Trim()); e.Handled = true; }
    }

    private void SelectButton_Click(object sender, RoutedEventArgs e)
    {
        if (SelectedPath is not null && Directory.Exists(SelectedPath)) DialogResult = true;
    }

    private void CancelButton_Click(object sender, RoutedEventArgs e) => DialogResult = false;
}
