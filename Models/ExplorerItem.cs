namespace VisualFolderExplorer.Models;

public enum ExplorerItemType
{
    Folder,
    TextFile
}

public sealed class ExplorerItem
{
    public required string Name { get; init; }
    public required string FullPath { get; init; }
    public required ExplorerItemType Type { get; init; }
    public string Icon => Type == ExplorerItemType.Folder ? "📁" : "📄";
    public string DisplayName => $"{Icon}  {Name}";
}
