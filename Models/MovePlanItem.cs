namespace VisualFolderExplorer.Models;

public sealed class MovePlanItem
{
    public required string SourcePath { get; init; }
    public required string DestinationPath { get; init; }
    public required bool AutoRenamed { get; init; }
    public string SourceName => Path.GetFileName(SourcePath);
    public string DestinationName => Path.GetFileName(DestinationPath);
}
