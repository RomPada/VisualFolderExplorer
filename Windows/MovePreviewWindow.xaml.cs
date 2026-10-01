using System.Windows;
using VisualFolderExplorer.Models;
using VisualFolderExplorer.Services;

namespace VisualFolderExplorer.Windows;

public partial class MovePreviewWindow : Window
{
    public MovePreviewWindow(LocalizationService loc, IReadOnlyList<MovePlanItem> plan, string destination)
    {
        InitializeComponent();
        Title = loc.T("MovePreviewTitle");
        TitleText.Text = loc.T("MovePreviewTitle");
        DestinationText.Text = loc.T("MovePreviewDestination", destination);
        CountText.Text = loc.T("MovePreviewCount", plan.Count);
        ConflictText.Text = loc.T("MovePreviewConflicts", plan.Count(x => x.AutoRenamed));
        SourceColumn.Header = loc.T("CurrentName");
        DestinationColumn.Header = loc.T("NewName");
        CancelButton.Content = loc.T("Cancel");
        ConfirmButton.Content = loc.T("ContinueMove");
        PreviewGrid.ItemsSource = plan;
    }

    private void ConfirmButton_Click(object sender, RoutedEventArgs e) => DialogResult = true;
    private void CancelButton_Click(object sender, RoutedEventArgs e) => DialogResult = false;
}
