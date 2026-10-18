using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text.Json;
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
        IReadOnlyList<MetadataCleanupRow> rows, MetadataFields selectedFields, string backupFolder,
        IProgress<(int Done, int Total)>? progress, CancellationToken cancellationToken)
        => RunStaAsync(() =>
        {
            var result = new List<MetadataCleanupResult>();
            for (var i = 0; i < rows.Count; i++)
            {
                cancellationToken.ThrowIfCancellationRequested();
                var row = rows[i];
                var backupPath = Path.Combine(backupFolder, $"{i + 1:D5}_{row.FileName}");
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
                        result.Add(new MetadataCleanupResult(row.FileName, true, "No matching values", null));
                        continue;
                    }

                    // Backup first. A successful copy is verified before touching the source.
                    Directory.CreateDirectory(backupFolder);
                    File.Copy(row.Path, backupPath, overwrite: false);
                    if (new FileInfo(backupPath).Length != row.OriginalLength ||
                        !FilesEqualSha256(row.Path, backupPath))
                        throw new IOException("Backup verification failed. Original was not changed.");

                    try
                    {
                        // JPEG/PNG: verify actual decoded pixels remain identical.
                        // This is stronger than merely avoiding an explicit re-encode call.
                        var pixelHashBefore = ComputeDecodedPixelHash(backupPath);
                        ClearProperties(row.Path, populated);
                        var pixelHashAfter = ComputeDecodedPixelHash(row.Path);
                        if (pixelHashBefore is not null && (pixelHashAfter is null ||
                            !pixelHashBefore.AsSpan().SequenceEqual(pixelHashAfter)))
                            throw new IOException("Decoded image pixels changed. Original restored.");

                        // Verify with a *new* property store; avoid relying on the writer cache.
                        var verified = ReadFile(row.Path);
                        if (!string.IsNullOrWhiteSpace(verified.ScanError) ||
                            (GetPopulatedFlags(verified) & populated) != MetadataFields.None)
                            throw new IOException("Properties could not be verified as cleared.");

                        // Retain filesystem timestamps (not part of the user's requested edit).
                        File.SetCreationTimeUtc(row.Path, row.CreationUtc);
                        File.SetLastWriteTimeUtc(row.Path, row.LastWriteUtc);
                        result.Add(new MetadataCleanupResult(row.FileName, true, "Cleared and verified", backupPath));
                    }
                    catch
                    {
                        // Restore exactly the original bytes if the handler failed or verification failed.
                        File.Copy(backupPath, row.Path, overwrite: true);
                        File.SetCreationTimeUtc(row.Path, row.CreationUtc);
                        File.SetLastWriteTimeUtc(row.Path, row.LastWriteUtc);
                        throw;
                    }
                }
                catch (Exception ex)
                {
                    result.Add(new MetadataCleanupResult(row.FileName, false, ex.Message, File.Exists(backupPath) ? backupPath : null));
                }
                progress?.Report((i + 1, rows.Count));
            }

            // Map backups to original paths for manual restoration. No sensitive values in manifest.
            if (Directory.Exists(backupFolder))
            {
                var manifest = rows.Zip(result, (row, entry) => new
                {
                    OriginalPath = row.Path, entry.BackupPath, entry.Succeeded, entry.Message
                }).ToArray();
                try
                {
                    File.WriteAllText(Path.Combine(backupFolder, "restore-map.json"),
                        JsonSerializer.Serialize(manifest, new JsonSerializerOptions { WriteIndented = true }));
                }
                catch (IOException) { /* Backups already exist; manifest is optional. */ }
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
        // Backup file name preserves the source extension (e.g. 00001_photo.jpg).
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
