using System.Security.Cryptography;
using VisualFolderExplorer.Models;

namespace VisualFolderExplorer.Services;

public static class DuplicateService
{
    public static async Task<List<DuplicateGroup>> FindDuplicatesAsync(
        IReadOnlyList<string> paths,
        IProgress<(int Done, int Total)>? progress = null,
        CancellationToken cancellationToken = default)
    {
        var existing = paths.Where(File.Exists)
            .Select((path, index) => new { Path = path, Index = index, Info = new FileInfo(path) })
            .ToList();

        var candidates = existing
            .GroupBy(x => x.Info.Length)
            .Where(g => g.Count() > 1)
            .SelectMany(g => g)
            .OrderBy(x => x.Index)
            .ToList();

        if (candidates.Count == 0) return [];

        var hashes = new List<(string Path, int Index, long Size, string Hash)>();
        var done = 0;
        foreach (var candidate in candidates)
        {
            cancellationToken.ThrowIfCancellationRequested();
            var hash = await Task.Run(() => ComputeSha256(candidate.Path), cancellationToken);
            hashes.Add((candidate.Path, candidate.Index, candidate.Info.Length, hash));
            done++;
            progress?.Report((done, candidates.Count));
        }

        var groups = hashes
            .GroupBy(x => $"{x.Size}:{x.Hash}", StringComparer.OrdinalIgnoreCase)
            .Where(g => g.Count() > 1)
            .Select(g => g.OrderBy(x => x.Index).ToList())
            .OrderBy(g => g[0].Index)
            .ToList();

        var result = new List<DuplicateGroup>();
        for (var i = 0; i < groups.Count; i++)
        {
            var group = groups[i];
            result.Add(new DuplicateGroup
            {
                GroupNumber = i + 1,
                Hash = group[0].Hash,
                Size = group[0].Size,
                Files = group.Select(x => x.Path).ToList()
            });
        }
        return result;
    }

    private static string ComputeSha256(string path)
    {
        using var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read, 1024 * 1024, FileOptions.SequentialScan);
        using var sha = SHA256.Create();
        return Convert.ToHexString(sha.ComputeHash(stream));
    }
}
