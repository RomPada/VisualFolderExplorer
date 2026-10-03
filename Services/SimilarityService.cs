using System.Numerics;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using VisualFolderExplorer.Models;

namespace VisualFolderExplorer.Services;

/// <summary>
/// Local perceptual image similarity. No API, model download, or network access is required.
/// A 63-bit pHash is built from low-frequency DCT coefficients of a 32x32 grayscale image.
/// </summary>
public static class SimilarityService
{
    private const int SampleSize = 32;
    private const int LowFrequencySize = 8;
    private const int HashBits = 63; // DC coefficient is excluded.
    private static readonly double[,] Cosine = BuildCosineTable();

    public static async Task<List<SimilarityHashResult>> AnalyzeAsync(
        IReadOnlyList<string> paths,
        IProgress<(int Done, int Total, int Failed)>? progress = null,
        CancellationToken cancellationToken = default)
    {
        var results = new SimilarityHashResult?[paths.Count];
        var done = 0;
        var failed = 0;
        var parallelOptions = new ParallelOptions
        {
            CancellationToken = cancellationToken,
            MaxDegreeOfParallelism = Math.Clamp(Environment.ProcessorCount / 2, 2, 6)
        };

        await Parallel.ForEachAsync(Enumerable.Range(0, paths.Count), parallelOptions, async (index, token) =>
        {
            try
            {
                var path = paths[index];
                var hash = await Task.Run(() => ComputePerceptualHash(path), token);
                results[index] = new SimilarityHashResult { FullPath = path, Hash = hash };
            }
            catch (OperationCanceledException) { throw; }
            catch
            {
                Interlocked.Increment(ref failed);
            }
            finally
            {
                var current = Interlocked.Increment(ref done);
                progress?.Report((current, paths.Count, Volatile.Read(ref failed)));
            }
        });

        return results.Where(x => x is not null).Select(x => x!).ToList();
    }

    public static List<SimilarityGroup> Group(IReadOnlyList<SimilarityHashResult> items, double thresholdPercent)
    {
        thresholdPercent = Math.Clamp(thresholdPercent, 55, 99);
        if (items.Count < 2) return [];

        // Build adjacency once. Dense seeds are processed first to reduce order sensitivity
        // while avoiding the long transitive chains typical of connected-component grouping.
        var adjacency = new List<int>[items.Count];
        for (var i = 0; i < adjacency.Length; i++) adjacency[i] = [];
        for (var i = 0; i < items.Count - 1; i++)
        {
            for (var j = i + 1; j < items.Count; j++)
            {
                if (GetSimilarityPercent(items[i].Hash, items[j].Hash) < thresholdPercent) continue;
                adjacency[i].Add(j);
                adjacency[j].Add(i);
            }
        }

        var seedOrder = Enumerable.Range(0, items.Count)
            .OrderByDescending(i => adjacency[i].Count)
            .ThenBy(i => i)
            .ToList();
        var assigned = new bool[items.Count];
        var groups = new List<SimilarityGroup>();

        foreach (var seed in seedOrder)
        {
            if (assigned[seed]) continue;
            var members = new List<int> { seed };
            members.AddRange(adjacency[seed].Where(i => !assigned[i]).OrderBy(i => i));
            if (members.Count < 2) continue;

            foreach (var member in members) assigned[member] = true;
            var similarityItems = new System.Collections.ObjectModel.ObservableCollection<SimilarityItem>(
                members.Select(i => new SimilarityItem { FullPath = items[i].FullPath, Hash = items[i].Hash }));

            groups.Add(new SimilarityGroup
            {
                GroupNumber = groups.Count + 1,
                Images = similarityItems,
                AverageSimilarity = CalculateAverageSimilarity(members, items)
            });
        }

        return groups;
    }

    public static double GetSimilarityPercent(ulong first, ulong second)
    {
        var distance = BitOperations.PopCount(first ^ second);
        return Math.Max(0, 100.0 * (1.0 - distance / (double)HashBits));
    }

    private static double CalculateAverageSimilarity(IReadOnlyList<int> members, IReadOnlyList<SimilarityHashResult> items)
    {
        if (members.Count < 2) return 100;
        double total = 0;
        var pairs = 0;
        for (var i = 0; i < members.Count - 1; i++)
        {
            for (var j = i + 1; j < members.Count; j++)
            {
                total += GetSimilarityPercent(items[members[i]].Hash, items[members[j]].Hash);
                pairs++;
            }
        }
        return pairs == 0 ? 100 : total / pairs;
    }

    private static ulong ComputePerceptualHash(string path)
    {
        var pixels = ReadScaledGrayPixels(path, SampleSize, SampleSize);
        var coefficients = new double[LowFrequencySize, LowFrequencySize];

        for (var u = 0; u < LowFrequencySize; u++)
        {
            for (var v = 0; v < LowFrequencySize; v++)
            {
                double sum = 0;
                for (var x = 0; x < SampleSize; x++)
                {
                    var cosX = Cosine[u, x];
                    for (var y = 0; y < SampleSize; y++)
                        sum += pixels[x, y] * cosX * Cosine[v, y];
                }
                var alphaU = u == 0 ? 1.0 / Math.Sqrt(2) : 1.0;
                var alphaV = v == 0 ? 1.0 / Math.Sqrt(2) : 1.0;
                coefficients[u, v] = 0.25 * alphaU * alphaV * sum;
            }
        }

        var lowFrequencies = new List<double>(HashBits);
        for (var u = 0; u < LowFrequencySize; u++)
            for (var v = 0; v < LowFrequencySize; v++)
                if (!(u == 0 && v == 0)) lowFrequencies.Add(coefficients[u, v]);

        var ordered = lowFrequencies.OrderBy(x => x).ToArray();
        var median = ordered[ordered.Length / 2];
        ulong hash = 0;
        for (var i = 0; i < lowFrequencies.Count; i++)
            if (lowFrequencies[i] > median) hash |= 1UL << i;
        return hash;
    }

    private static double[,] ReadScaledGrayPixels(string path, int targetWidth, int targetHeight)
    {
        using var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete);
        var image = new BitmapImage();
        image.BeginInit();
        image.CacheOption = BitmapCacheOption.OnLoad;
        image.DecodePixelWidth = 64;
        image.StreamSource = stream;
        image.EndInit();
        image.Freeze();

        BitmapSource source = image.Format == PixelFormats.Bgra32
            ? image
            : new FormatConvertedBitmap(image, PixelFormats.Bgra32, null, 0);
        if (source.CanFreeze) source.Freeze();

        var width = source.PixelWidth;
        var height = source.PixelHeight;
        if (width <= 0 || height <= 0) throw new InvalidDataException("Image has no pixels.");
        var stride = width * 4;
        var bytes = new byte[stride * height];
        source.CopyPixels(bytes, stride, 0);
        var output = new double[targetWidth, targetHeight];

        // Bilinear sampling. Stretching to a square is intentional for perceptual hashing.
        for (var tx = 0; tx < targetWidth; tx++)
        {
            var sx = targetWidth == 1 ? 0 : tx * (width - 1.0) / (targetWidth - 1.0);
            var x0 = (int)Math.Floor(sx);
            var x1 = Math.Min(width - 1, x0 + 1);
            var fx = sx - x0;
            for (var ty = 0; ty < targetHeight; ty++)
            {
                var sy = targetHeight == 1 ? 0 : ty * (height - 1.0) / (targetHeight - 1.0);
                var y0 = (int)Math.Floor(sy);
                var y1 = Math.Min(height - 1, y0 + 1);
                var fy = sy - y0;
                var g00 = Gray(bytes, stride, x0, y0);
                var g10 = Gray(bytes, stride, x1, y0);
                var g01 = Gray(bytes, stride, x0, y1);
                var g11 = Gray(bytes, stride, x1, y1);
                var top = g00 + (g10 - g00) * fx;
                var bottom = g01 + (g11 - g01) * fx;
                output[tx, ty] = top + (bottom - top) * fy;
            }
        }
        return output;
    }

    private static double Gray(byte[] bytes, int stride, int x, int y)
    {
        var index = y * stride + x * 4;
        var b = bytes[index];
        var g = bytes[index + 1];
        var r = bytes[index + 2];
        return 0.299 * r + 0.587 * g + 0.114 * b;
    }

    private static double[,] BuildCosineTable()
    {
        var table = new double[LowFrequencySize, SampleSize];
        for (var u = 0; u < LowFrequencySize; u++)
            for (var x = 0; x < SampleSize; x++)
                table[u, x] = Math.Cos((2 * x + 1) * u * Math.PI / (2.0 * SampleSize));
        return table;
    }
}
