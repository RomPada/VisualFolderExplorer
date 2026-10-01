using System.ComponentModel;
using System.Runtime.CompilerServices;
using System.Windows.Media;

namespace VisualFolderExplorer.Models;

public sealed class ImageItem : INotifyPropertyChanged
{
    private ImageSource? _thumbnail;

    public required string Name { get; init; }
    public required string FullPath { get; init; }
    public long Length { get; init; }
    public DateTime CreationTime { get; init; }
    public DateTime LastWriteTime { get; init; }

    public ImageSource? Thumbnail
    {
        get => _thumbnail;
        set
        {
            if (ReferenceEquals(_thumbnail, value)) return;
            _thumbnail = value;
            OnPropertyChanged();
        }
    }

    public event PropertyChangedEventHandler? PropertyChanged;
    private void OnPropertyChanged([CallerMemberName] string? propertyName = null) =>
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
}
