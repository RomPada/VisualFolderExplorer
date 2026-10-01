using System.IO;
using System.Text.Json;

namespace VisualFolderExplorer.Services;

public sealed class SettingsService
{
    private readonly string _settingsPath;
    private readonly JsonSerializerOptions _options = new() { WriteIndented = true };

    public SettingsService()
    {
        var folder = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "VisualFolderExplorer");
        Directory.CreateDirectory(folder);
        _settingsPath = Path.Combine(folder, "settings.json");
    }

    public AppSettings Load()
    {
        try
        {
            if (!File.Exists(_settingsPath)) return new AppSettings();
            var json = File.ReadAllText(_settingsPath);
            return JsonSerializer.Deserialize<AppSettings>(json, _options) ?? new AppSettings();
        }
        catch
        {
            return new AppSettings();
        }
    }

    public void Save(AppSettings settings)
    {
        settings.Version = "1.0.0";
        File.WriteAllText(_settingsPath, JsonSerializer.Serialize(settings, _options));
    }
}
