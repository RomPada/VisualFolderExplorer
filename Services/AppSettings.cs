using System.Collections.Generic;
namespace VisualFolderExplorer.Services;

public sealed class AppSettings
{
    public string Version { get; set; } = "1.5.0";
    public string? RootFolder { get; set; }
    public string? CurrentFolder { get; set; }
    public List<string> History { get; set; } = [];
    public double WindowWidth { get; set; } = 1420;
    public double WindowHeight { get; set; } = 820;
    public string WindowState { get; set; } = "Normal";
    public string Language { get; set; } = "UA";
    public string ImageSortField { get; set; } = "Name";
    public bool ImageSortDescending { get; set; }
    public string? LastMoveDestination { get; set; }
    public string? LastSelectedImagePath { get; set; }
    public double SimilarityThreshold { get; set; } = 88;
    public double ExplorerPaneWidth { get; set; } = 280;
    public double PreviewPaneWidth { get; set; } = 430;
    public Dictionary<string, double> FolderScrollOffsets { get; set; } = new(StringComparer.OrdinalIgnoreCase);
    public Dictionary<string, string> FolderLastSelectedImages { get; set; } = new(StringComparer.OrdinalIgnoreCase);
}
