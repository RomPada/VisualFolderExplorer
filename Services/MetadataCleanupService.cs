using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using VisualFolderExplorer.Models;

namespace VisualFolderExplorer.Services;

/// <summary>
/// Reads and edits the same four Shell properties shown in Windows file Properties → Details.
/// Uses native IPropertyStore metadata handlers, not image/video re-encoding.
/// Some MP4/PNG codecs expose read-only stores; those files are never forced or remuxed.
/// </summary>
public static class MetadataCleanupService
{
    private static readonly HashSet<string> Extensions = new(StringComparer.OrdinalIgnoreCase)
    { ".jpg", ".jpeg", ".png", ".mp4", ".m4v", ".mov" };

    public static bool SupportsFile(string path) => Extensions.Contains(Path.GetExtension(path));

    private static readonly (MetadataFields Flag, string CanonicalName)[] Fields =
    [
        (MetadataFields.Title, "System.Title"),
        (MetadataFields.Subject, "System.Subject"),
        (MetadataFields.Comments, "System.Comment"),
        (MetadataFields.Authors, "System.Author")
    ];

    public static Task<List<MetadataCleanupRow>> ScanAsync(IReadOnlyList<string> paths,
        IProgress<(int Done, int Total)>? progress, CancellationToken cancellationToken)
        => RunStaAsync(() =>
        {
            var result = new List<MetadataCleanupRow>();
            for (var i = 0; i < paths.Count; i++)
            {
                cancellationToken.ThrowIfCancellationRequested();
                result.Add(ReadFile(paths[i]));
                progress?.Report((i + 1, paths.Count));
            }
            return result;
        });

    public static Task<List<MetadataCleanupResult>> CleanAsync(
        IReadOnlyList<MetadataCleanupRow> rows, MetadataFields selectedFields,
        IProgress<(int Done, int Total)>? progress, CancellationToken cancellationToken)
        => RunStaAsync(() =>
        {
            var result = new List<MetadataCleanupResult>();
            for (var i = 0; i < rows.Count; i++)
            {
                cancellationToken.ThrowIfCancellationRequested();
                var row = rows[i];
                // A short-lived working file is needed so a failed handler cannot corrupt
                // the original. It is always deleted; NO backup directory is created.
                var directory = Path.GetDirectoryName(row.Path) ?? throw new IOException("Invalid file path");
                var temporaryPath = Path.Combine(directory,
                    $".__vfe_work_{Guid.NewGuid():N}{Path.GetExtension(row.Path)}");
                try
                {
                    var candidate = ReadFile(row.Path);
                    if (!string.IsNullOrWhiteSpace(candidate.ScanError))
                        throw new IOException(candidate.ScanError);
                    if (candidate.OriginalLength != row.OriginalLength || candidate.LastWriteUtc != row.LastWriteUtc ||
                        candidate.CreationUtc != row.CreationUtc)
                        throw new IOException("File changed since preview. Rescan required.");

                    var populated = GetPopulatedFlags(candidate) & selectedFields;
                    if (populated == MetadataFields.None)
                    {
                        result.Add(new MetadataCleanupResult(row.FileName, true, "No matching values"));
                        continue;
                    }

                    File.Copy(row.Path, temporaryPath, overwrite: false);
                    if (!FilesEqualSha256(row.Path, temporaryPath))
                        throw new IOException("Temporary working copy verification failed.");

                    // Work only on the temporary file. For JPEG/PNG compare decoded pixels;
                    // for video use the OS property handler without transcoding.
                    var pixelsBefore = ComputeDecodedPixelHash(row.Path);
                    ClearProperties(temporaryPath, populated);
                    var pixelsAfter = ComputeDecodedPixelHash(temporaryPath);
                    if (pixelsBefore is not null && (pixelsAfter is null ||
                        !pixelsBefore.AsSpan().SequenceEqual(pixelsAfter)))
                        throw new IOException("Decoded image pixels changed; original was left untouched.");

                    var verified = ReadFile(temporaryPath);
                    if (!string.IsNullOrWhiteSpace(verified.ScanError) ||
                        (GetPopulatedFlags(verified) & populated) != MetadataFields.None)
                        throw new IOException("Properties could not be verified as cleared.");

                    // Do not overwrite a file that changed externally during processing.
                    var current = new FileInfo(row.Path);
                    if (!current.Exists || current.Length != row.OriginalLength ||
                        current.LastWriteTimeUtc != row.LastWriteUtc)
                        throw new IOException("Original file changed while processing. Rescan required.");

                    File.SetCreationTimeUtc(temporaryPath, row.CreationUtc);
                    File.SetLastWriteTimeUtc(temporaryPath, row.LastWriteUtc);
                    File.Move(temporaryPath, row.Path, overwrite: true);
                    result.Add(new MetadataCleanupResult(row.FileName, true, "Cleared and verified"));
                }
                catch (Exception ex)
                {
                    result.Add(new MetadataCleanupResult(row.FileName, false, ex.Message));
                }
                finally
                {
                    try { if (File.Exists(temporaryPath)) File.Delete(temporaryPath); }
                    catch { /* Best effort cleanup of a temporary working file. */ }
                }
                progress?.Report((i + 1, rows.Count));
            }
            return result;
        });

    public static MetadataFields GetPopulatedFlags(MetadataCleanupRow row)
    {
        var flags = MetadataFields.None;
        if (!string.IsNullOrWhiteSpace(row.Title)) flags |= MetadataFields.Title;
        if (!string.IsNullOrWhiteSpace(row.Subject)) flags |= MetadataFields.Subject;
        if (!string.IsNullOrWhiteSpace(row.Comments)) flags |= MetadataFields.Comments;
        if (!string.IsNullOrWhiteSpace(row.Authors)) flags |= MetadataFields.Authors;
        return flags;
    }

    private static byte[]? ComputeDecodedPixelHash(string path)
    {
        var ext = Path.GetExtension(path).ToLowerInvariant();
        // Temporary working files retain the original extension for codec support.
        if (ext is not ".jpg" and not ".jpeg" and not ".png") return null;
        using var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete);
        var decoder = BitmapDecoder.Create(stream, BitmapCreateOptions.PreservePixelFormat, BitmapCacheOption.OnLoad);
        var frame = decoder.Frames[0];
        var normalized = new FormatConvertedBitmap(frame, PixelFormats.Bgra32, null, 0);
        var stride = checked(normalized.PixelWidth * 4);
        var data = new byte[checked(stride * normalized.PixelHeight)];
        normalized.CopyPixels(data, stride, 0);
        return SHA256.HashData(data);
    }

    private static bool FilesEqualSha256(string a, string b)
    {
        using var one = File.OpenRead(a);
        using var two = File.OpenRead(b);
        return SHA256.HashData(one).AsSpan().SequenceEqual(SHA256.HashData(two));
    }

    private static MetadataCleanupRow ReadFile(string path)
    {
        var info = new FileInfo(path);
        if (!info.Exists || !SupportsFile(path))
            return new MetadataCleanupRow { Path = path, ScanError = "File or format not supported" };

        IPropertyStore? store = null;
        try
        {
            store = OpenStore(path, writable: false);
            var values = Fields.Select(x => ReadProperty(store, x.CanonicalName)).ToArray();
            return new MetadataCleanupRow
            {
                Path = path, OriginalLength = info.Length, CreationUtc = info.CreationTimeUtc, LastWriteUtc = info.LastWriteTimeUtc,
                Title = values[0], Subject = values[1], Comments = values[2], Authors = values[3],
                Status = "Preview ready"
            };
        }
        catch (Exception ex)
        {
            return new MetadataCleanupRow { Path = path, OriginalLength = info.Length,
                CreationUtc = info.CreationTimeUtc, LastWriteUtc = info.LastWriteTimeUtc, ScanError = ex.Message, Status = ex.Message };
        }
        finally { if (store is not null) Marshal.ReleaseComObject(store); }
    }

    private static string ReadProperty(IPropertyStore store, string canonicalName)
    {
        var key = GetKey(canonicalName);
        Marshal.ThrowExceptionForHR(store.GetValue(ref key, out var value));
        try
        {
            if (value.VariantType is 0 or 1) return string.Empty;
            // Handles scalar strings (BSTR/LPWSTR/LPSTR) and vector-of-strings.
            var hr = PropVariantToStringAlloc(ref value, out var pText);
            if (hr >= 0)
            {
                try { return Marshal.PtrToStringUni(pText) ?? string.Empty; }
                finally { Marshal.FreeCoTaskMem(pText); }
            }
            if (value.VariantType == 0x101F && value.Pointer2 != IntPtr.Zero)
            {
                var words = new List<string>();
                for (int i = 0; i < Math.Min(value.VectorCount, 512); i++)
                {
                    var ptr = Marshal.ReadIntPtr(value.Pointer2, i * IntPtr.Size);
                    if (ptr != IntPtr.Zero) words.Add(Marshal.PtrToStringUni(ptr) ?? string.Empty);
                }
                return string.Join("; ", words);
            }
            // Unknown present type: do not silently treat as empty.
            return $"[Windows property type {value.VariantType}]";
        }
        finally { PropVariantClear(ref value); }
    }

    private static void ClearProperties(string path, MetadataFields flags)
    {
        IPropertyStore? store = null;
        try
        {
            store = OpenStore(path, writable: true);
            foreach (var (flag, canonicalName) in Fields)
            {
                if (!flags.HasFlag(flag)) continue;
                var key = GetKey(canonicalName);
                var empty = new PropVariant(); // VT_EMPTY removes the property (not an empty string).
                Marshal.ThrowExceptionForHR(store.SetValue(ref key, ref empty));
            }
            Marshal.ThrowExceptionForHR(store.Commit());
        }
        finally { if (store is not null) Marshal.ReleaseComObject(store); }
    }

    private static IPropertyStore OpenStore(string path, bool writable)
    {
        var iid = typeof(IPropertyStore).GUID;
        SHGetPropertyStoreFromParsingName(path, IntPtr.Zero, writable ? 0x2u : 0u,
            ref iid, out var store);
        return store;
    }

    private static PropertyKey GetKey(string canonicalName)
    {
        Marshal.ThrowExceptionForHR(PSGetPropertyKeyFromName(canonicalName, out var key));
        return key;
    }

    private static Task<T> RunStaAsync<T>(Func<T> work)
    {
        var completion = new TaskCompletionSource<T>(TaskCreationOptions.RunContinuationsAsynchronously);
        var thread = new Thread(() =>
        {
            try { completion.TrySetResult(work()); }
            catch (Exception ex) { completion.TrySetException(ex); }
        }) { IsBackground = true, Name = "VFE metadata property handler" };
        thread.SetApartmentState(ApartmentState.STA);
        thread.Start();
        return completion.Task;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct PropertyKey { public Guid FormatId; public uint PropertyId; }

    [StructLayout(LayoutKind.Explicit, Size = 24)]
    private struct PropVariant
    {
        [FieldOffset(0)] public ushort VariantType;
        [FieldOffset(8)] public IntPtr Pointer;
        [FieldOffset(8)] public int VectorCount;
        [FieldOffset(16)] public IntPtr Pointer2;
    }

    [ComImport, Guid("886d8eeb-8cf2-4446-8d02-cdba1dbdcf99"),
     InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IPropertyStore
    {
        [PreserveSig] int GetCount(out uint count);
        [PreserveSig] int GetAt(uint index, out PropertyKey key);
        [PreserveSig] int GetValue(ref PropertyKey key, out PropVariant value);
        [PreserveSig] int SetValue(ref PropertyKey key, ref PropVariant value);
        [PreserveSig] int Commit();
    }

    [DllImport("shell32.dll", CharSet = CharSet.Unicode, PreserveSig = false)]
    private static extern void SHGetPropertyStoreFromParsingName(
        [MarshalAs(UnmanagedType.LPWStr)] string path, IntPtr bindContext, uint flags,
        ref Guid interfaceId, [MarshalAs(UnmanagedType.Interface)] out IPropertyStore store);

    [DllImport("propsys.dll", CharSet = CharSet.Unicode)]
    private static extern int PSGetPropertyKeyFromName(string propertyName, out PropertyKey key);

    [DllImport("propsys.dll")]
    private static extern int PropVariantToStringAlloc(ref PropVariant value, out IntPtr result);

    [DllImport("ole32.dll")]
    private static extern int PropVariantClear(ref PropVariant value);
}
