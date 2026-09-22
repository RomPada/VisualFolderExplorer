using System.Collections.Concurrent;
using System.Windows.Media.Imaging;

namespace VisualFolderExplorer.Services;

public sealed class ThumbnailService
{
    private readonly string _cacheFolder;
    private readonly ConcurrentDictionary<string, BitmapSource> _memoryCache = new(StringComparer.OrdinalIgnoreCase);

    public ThumbnailService()
    {
        _cacheFolder = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "VisualFolderExplorer", "thumbcache");
        Directory.CreateDirectory(_cacheFolder);
    }

    public Task<BitmapSource?> GetThumbnailAsync(string path, int decodeWidth = 240, CancellationToken cancellationToken = default)
    {
        if (_memoryCache.TryGetValue(path, out var cached)) return Task.FromResult<BitmapSource?>(cached);

        return Task.Run<BitmapSource?>(() =>
        {
            cancellationToken.ThrowIfCancellationRequested();
            if (!File.Exists(path)) return null;

            try
            {
                var cachePath = Path.Combine(_cacheFolder, FileService.ComputeCacheKey(path) + ".png");
                BitmapSource bitmap;
                if (File.Exists(cachePath))
                {
                    bitmap = LoadBitmap(cachePath, 0);
                }
                else
                {
                    bitmap = LoadBitmap(path, decodeWidth);
                    TryWriteCache(bitmap, cachePath);
                }

                if (bitmap.CanFreeze) bitmap.Freeze();
                _memoryCache[path] = bitmap;
                return bitmap;
            }
            catch
            {
                return null;
            }
        }, cancellationToken);
    }

    public Task<BitmapSource?> GetPreviewAsync(string path, int decodeWidth = 1800, CancellationToken cancellationToken = default) =>
        Task.Run<BitmapSource?>(() =>
        {
            cancellationToken.ThrowIfCancellationRequested();
            if (!File.Exists(path)) return null;
            try
            {
                var bitmap = LoadBitmap(path, decodeWidth);
                if (bitmap.CanFreeze) bitmap.Freeze();
                return bitmap;
            }
            catch
            {
                return null;
            }
        }, cancellationToken);

    private static BitmapSource LoadBitmap(string path, int decodeWidth)
    {
        using var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete);
        var bitmap = new BitmapImage();
        bitmap.BeginInit();
        bitmap.CacheOption = BitmapCacheOption.OnLoad;
        if (decodeWidth > 0) bitmap.DecodePixelWidth = decodeWidth;
        bitmap.StreamSource = stream;
        bitmap.CreateOptions = BitmapCreateOptions.IgnoreColorProfile;
        bitmap.EndInit();
        return bitmap;
    }

    private static void TryWriteCache(BitmapSource source, string cachePath)
    {
        try
        {
            var encoder = new PngBitmapEncoder();
            encoder.Frames.Add(BitmapFrame.Create(source));
            using var stream = File.Create(cachePath);
            encoder.Save(stream);
        }
        catch
        {
            // Cache is an optimization only.
        }
    }
}
