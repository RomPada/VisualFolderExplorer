namespace VisualFolderExplorer.Services;

public sealed class AppSettings
{
    public string Version { get; set; } = "1.0.0";
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
}
