using System.Diagnostics;
using System.IO;

namespace SimpleAirPlay.Services;

/// <summary>
/// Manages the uxplay.exe engine process lifecycle.
/// CRITICAL: Never redirect StandardOutput — causes pipe deadlock and engine crash.
/// </summary>
public class EngineManager
{
    private Process? _proc;
    private readonly ConfigManager _config;

    public bool IsRunning { get; private set; }

    public event Action? EngineStarted;
    public event Action? EngineStopped;
    public event Action<string>? Error;

    public EngineManager(ConfigManager config)
    {
        _config = config;
    }

    /// <summary>
    /// Start the uxplay engine. Does NOT require admin elevation.
    /// Bonjour check is advisory only — Windows 10/11 has built-in mDNS via Dnscache.
    /// </summary>
    public void Start()
    {
        if (IsRunning) return;

        // Resolve engine path — 3-step fallback chain:
        // 1. Structured: engine\bin\uxplay.exe (MSIX packaging)
        // 2. Flat: uxplay.exe next to SimpleAirPlay.exe (dev/build output)
        // 3. Legacy: uxplay.exe in install dir root
        var enginePath = _config.Force32Bit ? AppPaths.Engine32Path : AppPaths.EnginePath;

        if (!File.Exists(enginePath))
        {
            enginePath = AppPaths.FlatEnginePath;
        }

        if (!File.Exists(enginePath))
        {
            Error?.Invoke("Engine fehlt!");
            return;
        }

        // Advisory Bonjour check (non-blocking, no admin)
        CheckBonjourAdvisory();

        // Kill any zombie processes
        KillZombies();

        // Get or create persistent MAC
        var mac = _config.GetOrCreateMac();

        // Build process start info
        var engineDir = Path.GetDirectoryName(enginePath)!;
        var psi = new ProcessStartInfo
        {
            FileName = enginePath,
            Arguments = $"-n \"{_config.DeviceName}\" -p -m {mac} -fps {_config.Fps} " +
                        $"-md \"{AppPaths.MetadataPath}\" -ca \"{AppPaths.CoverPath}\"",
            UseShellExecute = false,
            CreateNoWindow = true,
            // CRITICAL: NEVER redirect stdout — causes pipe deadlock and engine crash!
            RedirectStandardOutput = false,
            RedirectStandardError = false,
            WorkingDirectory = engineDir
        };

        // Set environment variables for GStreamer
        psi.EnvironmentVariables["PATH"] = $"{engineDir};{Environment.GetEnvironmentVariable("PATH")}";

        if (Directory.Exists(AppPaths.GStreamerPluginPath))
        {
            psi.EnvironmentVariables["GST_PLUGIN_PATH"] = AppPaths.GStreamerPluginPath;
        }

        try
        {
            _proc = Process.Start(psi);
            IsRunning = true;
            EngineStarted?.Invoke();

            // Monitor process exit in background
            Task.Run(() =>
            {
                _proc?.WaitForExit();
                IsRunning = false;
                EngineStopped?.Invoke();
            });
        }
        catch (Exception ex)
        {
            Error?.Invoke($"Start fehlgeschlagen: {ex.Message}");
        }
    }

    public void Stop()
    {
        if (_proc != null && !_proc.HasExited)
        {
            try { _proc.Kill(); } catch { }
            try { _proc.WaitForExit(2000); } catch { }
        }
        _proc?.Dispose();
        _proc = null;
        KillZombies();
        IsRunning = false;
        EngineStopped?.Invoke();
    }

    public void KillZombies()
    {
        foreach (var p in Process.GetProcessesByName("uxplay"))
        {
            try { p.Kill(); } catch { }
        }

        try { if (File.Exists(AppPaths.MetadataPath)) File.Delete(AppPaths.MetadataPath); } catch { }
        try { if (File.Exists(AppPaths.CoverPath)) File.Delete(AppPaths.CoverPath); } catch { }
    }

    /// <summary>
    /// Find the uxplay video window handle using the same 3-method search from PS1.
    /// 1. Process.MainWindowHandle
    /// 2. Get-Process with partial title match
    /// 3. Win32 FindWindow fallback
    /// </summary>
    public IntPtr FindVideoWindow()
    {
        IntPtr hWnd = IntPtr.Zero;

        // Method 1: Direct process handle
        if (_proc != null && !_proc.HasExited)
        {
            try
            {
                _proc.Refresh();
                if (_proc.MainWindowHandle != IntPtr.Zero)
                    hWnd = _proc.MainWindowHandle;
            }
            catch { }
        }

        // Method 2: Search all uxplay processes for matching window title
        if (hWnd == IntPtr.Zero)
        {
            foreach (var p in Process.GetProcessesByName("uxplay"))
            {
                try
                {
                    var title = p.MainWindowTitle;
                    if (!string.IsNullOrEmpty(title) &&
                        (title.Contains("Direct3D", StringComparison.OrdinalIgnoreCase) ||
                         title.Contains("OpenGL", StringComparison.OrdinalIgnoreCase) ||
                         title.Contains("UxPlay", StringComparison.OrdinalIgnoreCase) ||
                         title.Contains("GStreamer", StringComparison.OrdinalIgnoreCase)))
                    {
                        if (p.MainWindowHandle != IntPtr.Zero)
                        {
                            hWnd = p.MainWindowHandle;
                            break;
                        }
                    }
                }
                catch { }
            }
        }

        // Method 3: Win32 FindWindow fallback with known titles
        if (hWnd == IntPtr.Zero)
        {
            string[] titles = {
                "Direct 3d11 renderer",
                "Direct3D11 renderer",
                "Direct3D renderer",
                "OpenGL renderer",
                "UxPlay",
                "GStreamer Direct3D11 sink"
            };
            foreach (var t in titles)
            {
                hWnd = Interop.Win32.FindWindow(null, t);
                if (hWnd != IntPtr.Zero) break;
            }
        }

        return hWnd;
    }

    /// <summary>
    /// Advisory check for Bonjour/mDNS. Does NOT attempt to start services (no admin needed).
    /// Windows 10/11 has built-in mDNS via Dnscache service — Bonjour is optional.
    /// </summary>
    private void CheckBonjourAdvisory()
    {
        // No-op: Windows 10/11 has built-in mDNS support via Dnscache.
        // Apple's Bonjour is no longer strictly required.
        // If mDNS discovery fails, the user should install Bonjour manually.
    }
}
