using System.Collections.ObjectModel;

namespace VisualFolderExplorer.Models;

public sealed class SimilarityGroup
{
    public int GroupNumber { get; init; }
    public string Title { get; set; } = string.Empty;
    public required ObservableCollection<SimilarityItem> Images { get; init; }
    public double AverageSimilarity { get; init; }
    public int IncludedCount => Images.Count(x => x.IsIncluded);
}
