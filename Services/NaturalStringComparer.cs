using System.Text.RegularExpressions;

namespace VisualFolderExplorer.Services;

public sealed class NaturalStringComparer : IComparer<string>
{
    public static readonly NaturalStringComparer Instance = new();
    private static readonly Regex Parts = new(@"(\d+|\D+)", RegexOptions.Compiled);

    public int Compare(string? x, string? y)
    {
        if (ReferenceEquals(x, y)) return 0;
        if (x is null) return -1;
        if (y is null) return 1;
        var ax = Parts.Matches(x);
        var ay = Parts.Matches(y);
        var count = Math.Min(ax.Count, ay.Count);
        for (var i = 0; i < count; i++)
        {
            var a = ax[i].Value;
            var b = ay[i].Value;
            if (long.TryParse(a, out var na) && long.TryParse(b, out var nb))
            {
                var n = na.CompareTo(nb);
                if (n != 0) return n;
            }
            else
            {
                var n = StringComparer.CurrentCultureIgnoreCase.Compare(a, b);
                if (n != 0) return n;
            }
        }
        return ax.Count.CompareTo(ay.Count);
    }
}
