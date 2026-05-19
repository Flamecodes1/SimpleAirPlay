using System.IO;

namespace SimpleAirPlay.Services;

/// <summary>
/// Centralized path management for MSIX sandbox compliance.
/// Install directory is READ-ONLY in MSIX. All writable data goes to LocalAppData.
/// </summary>
public static class AppPaths
{
    /// <summary>Read-only application install directory (contains exe + engine binaries)</summary>
    public static string InstallDir { get; } = AppDomain.CurrentDomain.BaseDirectory;

    /// <summary>Writable app data directory (config, mac, metadata, cover)</summary>
    public static string DataDir { get; }

    // --- Engine paths ---
    // Primary: structured engine\bin\ layout (for MSIX packaging)
    public static string EnginePath => Path.Combine(InstallDir, "engine", "bin", "uxplay.exe");
    public static string Engine32Path => Path.Combine(InstallDir, "engine_x86", "bin", "uxplay.exe");
    // Fallback: flat layout (uxplay.exe next to SimpleAirPlay.exe in build output)
    public static string FlatEnginePath => Path.Combine(InstallDir, "uxplay.exe");
    public static string GStreamerPluginPath => Path.Combine(InstallDir, "engine", "lib", "gstreamer-1.0");

    // --- Writable files (in AppData) ---
    public static string ConfigPath => Path.Combine(DataDir, "config.ini");
    public static string MacPath => Path.Combine(DataDir, "mac.txt");
    public static string MetadataPath => Path.Combine(DataDir, "metadata.txt");
    public static string CoverPath => Path.Combine(DataDir, "cover.jpg");
    public static string IconPath => Path.Combine(InstallDir, "app_icon.ico");

    static AppPaths()
    {
        DataDir = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "SimpleAirPlay"
        );
        Directory.CreateDirectory(DataDir);
    }
}
