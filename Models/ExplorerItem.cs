namespace VisualFolderExplorer.Models;

public enum ExplorerItemType
{
    ParentFolder,
    Folder,
    TextFile
}

public sealed class ExplorerItem
{
    public required string Name { get; init; }
    public required string FullPath { get; init; }
    public required ExplorerItemType Type { get; init; }
    public string Icon => Type switch
    {
        ExplorerItemType.Folder => "📁",
        ExplorerItemType.TextFile => "📄",
        _ => string.Empty
    };
    public string DisplayName => Type == ExplorerItemType.ParentFolder ? "..." : $"{Icon}  {Name}";
}
