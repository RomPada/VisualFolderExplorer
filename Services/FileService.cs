using System.Collections.Specialized;
using System.Security.Cryptography;
using System.Text;
using Microsoft.VisualBasic.FileIO;

namespace VisualFolderExplorer.Services;

public sealed class FileService
{
    public static readonly HashSet<string> ImageExtensions = new(StringComparer.OrdinalIgnoreCase)
    {
        ".jpg", ".jpeg", ".png", ".bmp", ".gif", ".tif", ".tiff", ".webp"
    };

    public static bool IsImage(string path) => ImageExtensions.Contains(Path.GetExtension(path));
    public static bool IsText(string path) => Path.GetExtension(path).Equals(".txt", StringComparison.OrdinalIgnoreCase) || Path.GetExtension(path).Equals(".md", StringComparison.OrdinalIgnoreCase);

    public static string GetUniqueDestinationPath(string destination)
    {
        if (!File.Exists(destination) && !Directory.Exists(destination)) return destination;

        var directory = Path.GetDirectoryName(destination) ?? string.Empty;
        var isDirectory = Directory.Exists(destination);
        var baseName = isDirectory ? Path.GetFileName(destination.TrimEnd(Path.DirectorySeparatorChar)) : Path.GetFileNameWithoutExtension(destination);
        var extension = isDirectory ? string.Empty : Path.GetExtension(destination);

        var index = 1;
        while (true)
        {
            var candidate = Path.Combine(directory, $"{baseName}_{index}{extension}");
            if (!File.Exists(candidate) && !Directory.Exists(candidate)) return candidate;
            index++;
        }
    }

    public static async Task MoveOrCopyAsync(IEnumerable<string> paths, string destinationFolder, bool cut, CancellationToken cancellationToken = default)
    {
        Directory.CreateDirectory(destinationFolder);
        foreach (var source in paths)
        {
            cancellationToken.ThrowIfCancellationRequested();
            var name = Path.GetFileName(source.TrimEnd(Path.DirectorySeparatorChar));
            var destination = Path.Combine(destinationFolder, name);
            if (Path.GetFullPath(source).Equals(Path.GetFullPath(destination), StringComparison.OrdinalIgnoreCase) && cut) continue;
            destination = GetUniqueDestinationPath(destination);

            await Task.Run(() =>
            {
                if (Directory.Exists(source))
                {
                    var sourceFull = Path.GetFullPath(source).TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar;
                    var destinationRoot = Path.GetFullPath(destinationFolder).TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar;
                    if (destinationRoot.StartsWith(sourceFull, StringComparison.OrdinalIgnoreCase))
                        throw new IOException("A folder cannot be pasted inside itself.");

                    if (cut)
                    {
                        try { Directory.Move(source, destination); }
                        catch (IOException)
                        {
                            CopyDirectory(source, destination);
                            Directory.Delete(source, true);
                        }
                    }
                    else CopyDirectory(source, destination);
                }
                else if (File.Exists(source))
                {
                    if (cut)
                    {
                        MoveFileSafe(source, destination);
                    }
                    else File.Copy(source, destination);
                }
            }, cancellationToken);
        }
    }

    public static void MoveFileSafe(string source, string destination)
    {
        try { File.Move(source, destination); }
        catch (IOException)
        {
            File.Copy(source, destination);
            File.Delete(source);
        }
    }

    public static void CopyDirectory(string source, string destination)
    {
        Directory.CreateDirectory(destination);
        foreach (var file in Directory.GetFiles(source))
            File.Copy(file, Path.Combine(destination, Path.GetFileName(file)));
        foreach (var directory in Directory.GetDirectories(source))
            CopyDirectory(directory, Path.Combine(destination, Path.GetFileName(directory)));
    }

    public static void SendToRecycleBin(string path)
    {
        if (File.Exists(path))
        {
            FileSystem.DeleteFile(path, UIOption.OnlyErrorDialogs, RecycleOption.SendToRecycleBin, UICancelOption.ThrowException);
        }
        else if (Directory.Exists(path))
        {
            FileSystem.DeleteDirectory(path, UIOption.OnlyErrorDialogs, RecycleOption.SendToRecycleBin, UICancelOption.ThrowException);
        }
    }

    public static void PutFilesOnClipboard(IEnumerable<string> paths, bool cut)
    {
        var collection = new StringCollection();
        foreach (var path in paths.Where(p => File.Exists(p) || Directory.Exists(p))) collection.Add(path);
        if (collection.Count == 0) return;

        var data = new System.Windows.DataObject();
        data.SetFileDropList(collection);
        var effect = cut ? new byte[] { 2, 0, 0, 0 } : new byte[] { 5, 0, 0, 0 };
        data.SetData("Preferred DropEffect", new MemoryStream(effect));
        System.Windows.Clipboard.SetDataObject(data, true);
    }

    public static (List<string> Paths, bool IsCut) ReadClipboardFiles()
    {
        try
        {
            var data = System.Windows.Clipboard.GetDataObject();
            if (data is null || !data.GetDataPresent(System.Windows.DataFormats.FileDrop)) return ([], false);
            var paths = System.Windows.Clipboard.GetFileDropList().Cast<string>().Where(p => File.Exists(p) || Directory.Exists(p)).ToList();
            var isCut = false;
            if (data.GetDataPresent("Preferred DropEffect"))
            {
                if (data.GetData("Preferred DropEffect") is MemoryStream stream)
                {
                    var bytes = stream.ToArray();
                    isCut = bytes.Length > 0 && (bytes[0] & 2) == 2;
                }
                else if (data.GetData("Preferred DropEffect") is byte[] bytes)
                {
                    isCut = bytes.Length > 0 && (bytes[0] & 2) == 2;
                }
            }
            return (paths, isCut);
        }
        catch
        {
            return ([], false);
        }
    }

    public static string ComputeCacheKey(string path)
    {
        var info = new FileInfo(path);
        var raw = $"{path}|{info.Length}|{info.LastWriteTimeUtc.Ticks}";
        return Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(raw))).ToLowerInvariant();
    }
}
