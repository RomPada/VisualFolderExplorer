using System.Windows;
using System.Windows.Media;

namespace VisualFolderExplorer.Windows;

public enum NoticeKind { Info, Warning, Error }

public partial class NoticeWindow : Window
{
    public NoticeWindow(string title, string message, string okText, NoticeKind kind = NoticeKind.Info)
    {
        InitializeComponent();
        Title = title;
        MessageText.Text = message;
        OkButton.Content = okText;
        if (kind == NoticeKind.Warning)
        {
            IconCircle.Background = new SolidColorBrush(Color.FromRgb(255, 243, 217));
            IconText.Foreground = new SolidColorBrush(Color.FromRgb(154, 106, 20));
            IconText.Text = "!";
        }
        else if (kind == NoticeKind.Error)
        {
            IconCircle.Background = new SolidColorBrush(Color.FromRgb(253, 232, 232));
            IconText.Foreground = new SolidColorBrush(Color.FromRgb(176, 68, 68));
            IconText.Text = "!";
        }
    }

    private void OkButton_Click(object sender, RoutedEventArgs e) => DialogResult = true;
}
