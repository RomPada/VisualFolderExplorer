namespace VisualFolderExplorer.Models;

public sealed class SimilarityHashResult
{
    public required string FullPath { get; init; }
    public required ulong Hash { get; init; }
    public string Name => Path.GetFileName(FullPath);
}
