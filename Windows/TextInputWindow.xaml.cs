using System.Windows;

namespace VisualFolderExplorer.Windows;

public partial class TextInputWindow : Window
{
    public string Value => ValueBox.Text;

    public TextInputWindow(string title, string prompt, string defaultValue, string ok, string cancel, bool selectStemOnly = false)
    {
        InitializeComponent();
        Title = title;
        PromptText.Text = prompt;
        ValueBox.Text = defaultValue;
        OkButton.Content = ok;
        CancelButton.Content = cancel;
        Loaded += (_, _) =>
        {
            ValueBox.Focus();
            // On rename, keep the extension unselected: "text.txt" selects "text".
            // Creation dialogs still select the whole proposed name.
            if (selectStemOnly)
            {
                var length = System.IO.Path.GetFileNameWithoutExtension(defaultValue).Length;
                ValueBox.Select(0, length > 0 ? length : defaultValue.Length);
            }
            else ValueBox.SelectAll();
        };
    }

    private void OkButton_Click(object sender, RoutedEventArgs e) => DialogResult = true;
    private void CancelButton_Click(object sender, RoutedEventArgs e) => DialogResult = false;
}
