using System.ComponentModel;
using System.Runtime.CompilerServices;
using System.Windows.Media.Imaging;

namespace VisualFolderExplorer.Models;

public sealed class SimilarityItem : INotifyPropertyChanged
{
    private BitmapSource? _thumbnail;
    private bool _isIncluded = true;

    public required string FullPath { get; init; }
    public required ulong Hash { get; init; }
    public string Name => Path.GetFileName(FullPath);

    public BitmapSource? Thumbnail
    {
        get => _thumbnail;
        set { if (ReferenceEquals(_thumbnail, value)) return; _thumbnail = value; OnPropertyChanged(); }
    }

    public bool IsIncluded
    {
        get => _isIncluded;
        set { if (_isIncluded == value) return; _isIncluded = value; OnPropertyChanged(); }
    }

    public event PropertyChangedEventHandler? PropertyChanged;
    private void OnPropertyChanged([CallerMemberName] string? name = null) => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
}
