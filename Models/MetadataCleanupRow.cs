using System.ComponentModel;
using System.Runtime.CompilerServices;

namespace VisualFolderExplorer.Models;

public sealed class MetadataCleanupRow : INotifyPropertyChanged
{
    private bool _selected;
    private string _status = "";
    public string Path { get; init; } = "";
    public string FileName => System.IO.Path.GetFileName(Path);
    public string Format => System.IO.Path.GetExtension(Path).TrimStart('.').ToUpperInvariant();
    public long OriginalLength { get; init; }
    public DateTime CreationUtc { get; init; }
    public DateTime LastWriteUtc { get; init; }
    public string Title { get; init; } = "";
    public string Subject { get; init; } = "";
    public string Comments { get; init; } = "";
    public string Authors { get; init; } = "";
    public string ScanError { get; init; } = "";
    public bool CanClean => HasValues && string.IsNullOrWhiteSpace(ScanError);
    public bool HasValues => !string.IsNullOrWhiteSpace(Title) || !string.IsNullOrWhiteSpace(Subject) || !string.IsNullOrWhiteSpace(Comments) || !string.IsNullOrWhiteSpace(Authors);
    public bool Selected { get => _selected; set { if (_selected == value) return; _selected = value; Raise(); } }
    public string Status { get => _status; set { if (_status == value) return; _status = value; Raise(); } }
    public event PropertyChangedEventHandler? PropertyChanged;
    private void Raise([CallerMemberName] string? property = null) => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(property));
}

[Flags]
public enum MetadataFields { None = 0, Title = 1, Subject = 2, Comments = 4, Authors = 8 }

public record MetadataCleanupResult(string FileName, bool Succeeded, string Message);
