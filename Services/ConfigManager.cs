using System.IO;

namespace SimpleAirPlay.Services;

/// <summary>
/// Manages config.ini and mac.txt in LocalAppData.
/// MAC persistence is critical for fast AirPlay discovery (iPhone caches by MAC).
/// </summary>
public class ConfigManager
{
    public string DeviceName { get; set; } = "Simple AirPlay";
    public string Fps { get; set; } = "60";
    public bool Force32Bit { get; set; } = false;

    public void Load()
    {
        if (!File.Exists(AppPaths.ConfigPath)) return;

        foreach (var line in File.ReadAllLines(AppPaths.ConfigPath))
        {
            if (line.StartsWith("DeviceName="))
                DeviceName = line["DeviceName=".Length..].Trim();
            else if (line.StartsWith("FPS="))
                Fps = line["FPS=".Length..].Trim();
            else if (line.StartsWith("Force32Bit="))
                Force32Bit = bool.TryParse(line["Force32Bit=".Length..].Trim(), out var v) && v;
        }
    }

    public void Save()
    {
        var lines = new[]
        {
            $"DeviceName={DeviceName}",
            $"FPS={Fps}",
            $"Force32Bit={Force32Bit}"
        };
        File.WriteAllLines(AppPaths.ConfigPath, lines);
    }

    /// <summary>
    /// Load or generate persistent MAC address.
    /// Apple devices cache AirPlay receivers by MAC — a persistent MAC means
    /// the iPhone finds us near-instantly instead of waiting for full mDNS discovery.
    /// </summary>
    public string GetOrCreateMac()
    {
        if (File.Exists(AppPaths.MacPath))
        {
            return File.ReadAllText(AppPaths.MacPath).Trim();
        }

        var rng = new Random();
        var bytes = new byte[6];
        rng.NextBytes(bytes);
        bytes[0] = (byte)((bytes[0] | 0x02) & 0xFE); // Locally administered, unicast
        var mac = string.Join(":", bytes.Select(b => b.ToString("X2")));
        File.WriteAllText(AppPaths.MacPath, mac);
        return mac;
    }
}
