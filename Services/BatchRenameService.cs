using VisualFolderExplorer.Models;

namespace VisualFolderExplorer.Services;

public static class BatchRenameService
{
    public static List<BatchRenamePlanItem> BuildSequentialPlan(IReadOnlyList<string> paths, string prefix, int startNumber, int digits)
    {
        prefix = prefix.Trim();
        digits = Math.Clamp(digits, 1, 8);
        var proposed = new List<(string Source, string Destination, string OldName, string NewName)>();
        for (var i = 0; i < paths.Count; i++)
        {
            var source = paths[i];
            var directory = Path.GetDirectoryName(source) ?? string.Empty;
            var extension = Path.GetExtension(source);
            var number = (startNumber + i).ToString($"D{digits}");
            var stem = string.IsNullOrWhiteSpace(prefix) ? number : $"{prefix}_{number}";
            var newName = stem + extension;
            proposed.Add((source, Path.Combine(directory, newName), Path.GetFileName(source), newName));
        }
        return Validate(proposed, paths);
    }

    public static List<BatchRenamePlanItem> BuildFindReplacePlan(IReadOnlyList<string> paths, string find, string replace)
    {
        var proposed = new List<(string Source, string Destination, string OldName, string NewName)>();
        foreach (var source in paths)
        {
            var directory = Path.GetDirectoryName(source) ?? string.Empty;
            var extension = Path.GetExtension(source);
            var stem = Path.GetFileNameWithoutExtension(source);
            var newStem = string.IsNullOrEmpty(find) ? stem : ReplaceIgnoreCase(stem, find, replace);
            var newName = newStem + extension;
            proposed.Add((source, Path.Combine(directory, newName), Path.GetFileName(source), newName));
        }
        return Validate(proposed, paths);
    }

    public static void Apply(IReadOnlyList<BatchRenamePlanItem> plans)
    {
        var changed = plans.Where(p => p.IsChanged).ToList();
        if (changed.Count == 0) return;
        if (changed.Any(p => p.HasConflict)) throw new IOException("Batch rename contains unresolved name conflicts.");

        var temporary = new List<(BatchRenamePlanItem Plan, string TempPath)>();
        var finalized = new List<(BatchRenamePlanItem Plan, string TempPath)>();
        try
        {
            foreach (var plan in changed)
            {
                var directory = Path.GetDirectoryName(plan.SourcePath) ?? string.Empty;
                string tempPath;
                do
                {
                    tempPath = Path.Combine(directory, $".__vfe_tmp_{Guid.NewGuid():N}{Path.GetExtension(plan.SourcePath)}");
                } while (File.Exists(tempPath));

                File.Move(plan.SourcePath, tempPath);
                temporary.Add((plan, tempPath));
            }

            foreach (var item in temporary)
            {
                File.Move(item.TempPath, item.Plan.DestinationPath);
                finalized.Add(item);
            }
        }
        catch
        {
            foreach (var item in finalized.AsEnumerable().Reverse())
            {
                try
                {
                    if (File.Exists(item.Plan.DestinationPath) && !File.Exists(item.Plan.SourcePath))
                        File.Move(item.Plan.DestinationPath, item.Plan.SourcePath);
                }
                catch { }
            }
            foreach (var item in temporary.AsEnumerable().Reverse())
            {
                try
                {
                    if (File.Exists(item.TempPath) && !File.Exists(item.Plan.SourcePath))
                        File.Move(item.TempPath, item.Plan.SourcePath);
                }
                catch { }
            }
            throw;
        }
    }

    private static List<BatchRenamePlanItem> Validate(
        IReadOnlyList<(string Source, string Destination, string OldName, string NewName)> proposed,
        IReadOnlyList<string> selectedSources)
    {
        var selected = new HashSet<string>(selectedSources.Select(Path.GetFullPath), StringComparer.OrdinalIgnoreCase);
        var destinationCounts = proposed.GroupBy(p => Path.GetFullPath(p.Destination), StringComparer.OrdinalIgnoreCase)
            .ToDictionary(g => g.Key, g => g.Count(), StringComparer.OrdinalIgnoreCase);

        return proposed.Select(p =>
        {
            var destinationFull = Path.GetFullPath(p.Destination);
            var sourceFull = Path.GetFullPath(p.Source);
            var duplicateDestination = destinationCounts[destinationFull] > 1;
            var occupiedByUnselected = File.Exists(destinationFull) && !selected.Contains(destinationFull) && !sourceFull.Equals(destinationFull, StringComparison.OrdinalIgnoreCase);
            var invalidName = string.IsNullOrWhiteSpace(p.NewName) || p.NewName.IndexOfAny(Path.GetInvalidFileNameChars()) >= 0;
            return new BatchRenamePlanItem
            {
                SourcePath = p.Source,
                DestinationPath = p.Destination,
                OldName = p.OldName,
                NewName = p.NewName,
                HasConflict = duplicateDestination || occupiedByUnselected || invalidName
            };
        }).ToList();
    }

    private static string ReplaceIgnoreCase(string input, string search, string replacement)
    {
        if (string.IsNullOrEmpty(search)) return input;
        var index = 0;
        var result = new System.Text.StringBuilder();
        while (true)
        {
            var found = input.IndexOf(search, index, StringComparison.OrdinalIgnoreCase);
            if (found < 0)
            {
                result.Append(input, index, input.Length - index);
                break;
            }
            result.Append(input, index, found - index);
            result.Append(replacement);
            index = found + search.Length;
        }
        return result.ToString();
    }
}
