namespace VisualFolderExplorer.Models;

public sealed class DuplicateGroup
{
    public required int GroupNumber { get; init; }
    public required string Hash { get; init; }
    public required long Size { get; init; }
    public required IReadOnlyList<string> Files { get; init; }
}
