using System.Windows;

namespace VisualFolderExplorer.Windows;

public enum ConfirmChoice { Cancel, Secondary, Primary }

public partial class ConfirmWindow : Window
{
    public ConfirmChoice Choice { get; private set; } = ConfirmChoice.Cancel;

    public ConfirmWindow(string title, string message, string primaryText, string secondaryText, string cancelText, bool showSecondary = true)
    {
        InitializeComponent();
        Title = title;
        MessageText.Text = message;
        PrimaryButton.Content = primaryText;
        SecondaryButton.Content = secondaryText;
        SecondaryButton.Visibility = showSecondary ? Visibility.Visible : Visibility.Collapsed;
        CancelButton.Content = cancelText;
    }

    private void PrimaryButton_Click(object sender, RoutedEventArgs e) { Choice = ConfirmChoice.Primary; DialogResult = true; }
    private void SecondaryButton_Click(object sender, RoutedEventArgs e) { Choice = ConfirmChoice.Secondary; DialogResult = true; }
    private void CancelButton_Click(object sender, RoutedEventArgs e) { Choice = ConfirmChoice.Cancel; DialogResult = false; }
}
