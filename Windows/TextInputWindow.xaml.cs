using System.Windows;

namespace VisualFolderExplorer.Windows;

public partial class TextInputWindow : Window
{
    public string Value => ValueBox.Text;

    public TextInputWindow(string title, string prompt, string defaultValue, string ok, string cancel)
    {
        InitializeComponent();
        Title = title;
        PromptText.Text = prompt;
        ValueBox.Text = defaultValue;
        OkButton.Content = ok;
        CancelButton.Content = cancel;
        Loaded += (_, _) => { ValueBox.Focus(); ValueBox.SelectAll(); };
    }

    private void OkButton_Click(object sender, RoutedEventArgs e) => DialogResult = true;
    private void CancelButton_Click(object sender, RoutedEventArgs e) => DialogResult = false;
}
