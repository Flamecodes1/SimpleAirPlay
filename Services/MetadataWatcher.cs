using System.IO;
using System.Text;
using System.Windows.Media.Imaging;

namespace SimpleAirPlay.Services;

/// <summary>
/// Watches metadata.txt and cover.jpg for changes.
/// Uses polling (same as PS1 timer) because FileSystemWatcher is unreliable
/// for files being rapidly rewritten by uxplay.
/// </summary>
public class MetadataWatcher
{
    private DateTime _lastMetaTime;
    private DateTime _lastCoverTime;
    private long _lastCoverSize;

    public string? Title { get; private set; }
    public string? Artist { get; private set; }
    public string? Album { get; private set; }
    public string? Genre { get; private set; }
    public BitmapImage? CoverArt { get; private set; }

    public event Action<string, string, string?>? TrackChanged;
    public event Action<BitmapImage>? CoverChanged;

    /// <summary>
    /// Poll for metadata changes. Called from DispatcherTimer (500ms).
    /// Returns true if metadata was updated.
    /// </summary>
    public bool PollMetadata()
    {
        var metaPath = AppPaths.MetadataPath;
        if (!File.Exists(metaPath)) return false;

        try
        {
            var fileInfo = new FileInfo(metaPath);
            if (fileInfo.LastWriteTime == _lastMetaTime) return false;

            _lastMetaTime = fileInfo.LastWriteTime;

            // Read with shared access (uxplay may be writing)
            string text;
            using (var fs = new FileStream(metaPath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
            using (var sr = new StreamReader(fs, Encoding.UTF8))
            {
                text = sr.ReadToEnd();
            }

            text = text.Replace("\0", "").Trim();
            if (text.StartsWith("no data", StringComparison.OrdinalIgnoreCase)) return false;

            string? title = null, artist = null, album = null, genre = null;
            foreach (var line in text.Split('\n'))
            {
                var cl = line.Trim();
                if (cl.StartsWith("Title:")) title = cl["Title:".Length..].Trim();
                else if (cl.StartsWith("Artist:")) artist = cl["Artist:".Length..].Trim();
                else if (cl.StartsWith("Album:")) album = cl["Album:".Length..].Trim();
                else if (cl.StartsWith("Genre:")) genre = cl["Genre:".Length..].Trim();
            }

            if (string.IsNullOrEmpty(title) && string.IsNullOrEmpty(artist)) return false;

            Title = title ?? "Unknown Track";
            Artist = artist ?? "Unknown Artist";
            Album = album;
            Genre = genre;

            // Build extra info line (Album • Genre)
            var extra = "";
            if (!string.IsNullOrEmpty(album)) extra += album;
            if (!string.IsNullOrEmpty(genre))
            {
                if (!string.IsNullOrEmpty(extra)) extra += " • ";
                extra += genre;
            }

            TrackChanged?.Invoke(Title, Artist, string.IsNullOrEmpty(extra) ? null : extra);
            return true;
        }
        catch { return false; }
    }

    /// <summary>
    /// Poll for cover art changes. Called from DispatcherTimer (500ms).
    /// Returns true if cover was updated.
    /// </summary>
    public bool PollCover()
    {
        var coverPath = AppPaths.CoverPath;
        if (!File.Exists(coverPath)) return false;

        try
        {
            var coverInfo = new FileInfo(coverPath);
            var coverSize = coverInfo.Length;
            var coverTime = coverInfo.LastWriteTime;

            if (coverTime == _lastCoverTime && coverSize == _lastCoverSize) return false;
            if (coverSize <= 200) return false; // Too small, still being written

            // Read with shared access
            using var fs = new FileStream(coverPath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
            using var mem = new MemoryStream();
            fs.CopyTo(mem);
            mem.Position = 0;

            var bmp = new BitmapImage();
            bmp.BeginInit();
            bmp.CacheOption = BitmapCacheOption.OnLoad;
            bmp.StreamSource = mem;
            bmp.DecodePixelWidth = 120;
            bmp.EndInit();
            bmp.Freeze(); // Thread-safe

            CoverArt = bmp;
            _lastCoverTime = coverTime;
            _lastCoverSize = coverSize;

            CoverChanged?.Invoke(bmp);
            return true;
        }
        catch { return false; }
    }

    public void Reset()
    {
        _lastMetaTime = default;
        _lastCoverTime = default;
        _lastCoverSize = 0;
        Title = null;
        Artist = null;
        Album = null;
        Genre = null;
        CoverArt = null;
    }
}
