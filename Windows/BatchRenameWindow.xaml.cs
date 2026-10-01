using System.Windows;
using System.Windows.Controls;
using VisualFolderExplorer.Models;
using VisualFolderExplorer.Services;

namespace VisualFolderExplorer.Windows;

public partial class BatchRenameWindow : Window
{
    private readonly LocalizationService _loc;
    private readonly IReadOnlyList<string> _paths;
    private bool _ready;
    public IReadOnlyList<BatchRenamePlanItem> Plan { get; private set; } = [];

    public BatchRenameWindow(LocalizationService loc, IReadOnlyList<string> paths)
    {
        InitializeComponent();
        _loc = loc;
        _paths = paths;
        ApplyLanguage();
        PrefixBox.Text = "image";
        SequenceRadio.IsChecked = true;
        _ready = true;
        RefreshPreview();
    }

    private void ApplyLanguage()
    {
        Title = _loc.T("BatchRenameTitle");
        TitleText.Text = _loc.T("BatchRenameTitle");
        SequenceRadio.Content = _loc.T("RenameSequence");
        FindReplaceRadio.Content = _loc.T("RenameFindReplace");
        PrefixLabel.Text = _loc.T("Prefix");
        StartLabel.Text = _loc.T("StartNumber");
        DigitsLabel.Text = _loc.T("Digits");
        FindLabel.Text = _loc.T("Find");
        ReplaceLabel.Text = _loc.T("Replace");
        OldColumn.Header = _loc.T("CurrentName");
        NewColumn.Header = _loc.T("NewName");
        ConflictColumn.Header = _loc.T("NameConflict");
        ConflictHelpText.Text = _loc.T("ConflictHelp");
        CancelButton.Content = _loc.T("Cancel");
        ApplyButton.Content = _loc.T("ApplyRename");
    }

    private void ModeChanged(object sender, RoutedEventArgs e)
    {
        if (!_ready) return;
        SequencePanel.Visibility = SequenceRadio.IsChecked == true ? Visibility.Visible : Visibility.Collapsed;
        FindReplacePanel.Visibility = FindReplaceRadio.IsChecked == true ? Visibility.Visible : Visibility.Collapsed;
        RefreshPreview();
    }

    private void InputChanged(object sender, TextChangedEventArgs e)
    {
        if (_ready) RefreshPreview();
    }

    private void RefreshPreview()
    {
        if (SequenceRadio.IsChecked == true)
        {
            _ = int.TryParse(StartBox.Text, out var start);
            if (start < 0) start = 0;
            _ = int.TryParse(DigitsBox.Text, out var digits);
            if (digits <= 0) digits = 3;
            Plan = BatchRenameService.BuildSequentialPlan(_paths, PrefixBox.Text, start, digits);
        }
        else
        {
            Plan = BatchRenameService.BuildFindReplacePlan(_paths, FindBox.Text, ReplaceBox.Text);
        }

        PreviewGrid.ItemsSource = Plan;
        var changed = Plan.Count(p => p.IsChanged);
        var conflicts = Plan.Count(p => p.HasConflict);
        SummaryText.Text = _loc.T("BatchRenameSummary", _paths.Count, changed, conflicts);
        ApplyButton.IsEnabled = changed > 0 && conflicts == 0;
    }

    private void ApplyButton_Click(object sender, RoutedEventArgs e)
    {
        RefreshPreview();
        if (!Plan.Any(p => p.IsChanged) || Plan.Any(p => p.HasConflict)) return;
        DialogResult = true;
    }

    private void CancelButton_Click(object sender, RoutedEventArgs e) => DialogResult = false;
}
