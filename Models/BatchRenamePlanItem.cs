namespace VisualFolderExplorer.Models;

public sealed class BatchRenamePlanItem
{
    public required string SourcePath { get; init; }
    public required string DestinationPath { get; init; }
    public required string OldName { get; init; }
    public required string NewName { get; init; }
    public required bool HasConflict { get; init; }
    public bool IsChanged => !SourcePath.Equals(DestinationPath, StringComparison.OrdinalIgnoreCase);
}
