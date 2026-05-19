using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Windows;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Threading;
using H.NotifyIcon;
using SimpleAirPlay.Interop;
using SimpleAirPlay.Services;

namespace SimpleAirPlay;

/// <summary>
/// Simple AirPlay 5.0 — Dynamic Premium Edition (Microsoft Store)
/// Ported from SimpleAirPlay.ps1 to native C# WPF.
/// All Win32 tricks, Z-order management, and 60FPS video sync preserved.
/// </summary>
public partial class MainWindow : Window
{
    // --- Services ---
    private readonly ConfigManager _config = new();
    private readonly EngineManager _engine;
    private readonly MetadataWatcher _metadata = new();

    // --- Video sync state ---
    private IntPtr _vidHwnd = IntPtr.Zero;
    private int _lastVidX = -1, _lastVidY = -1, _lastVidW = -1, _lastVidH = -1;
    private IntPtr _lastVidZ = IntPtr.Zero;
    private bool _isPiP = true;
    private bool _lastPipState = true;

    // --- Timer ---
    private readonly DispatcherTimer _timer;

    // --- System Tray ---
    private TaskbarIcon? _trayIcon;

    public MainWindow()
    {
        InitializeComponent();

        // Load config
        _config.Load();
        TitleText.Text = _config.DeviceName;

        // Initialize engine
        _engine = new EngineManager(_config);
        _engine.EngineStarted += OnEngineStarted;
        _engine.EngineStopped += OnEngineStopped;
        _engine.Error += OnEngineError;

        // Volume control via mouse wheel on the pill
        MainBorder.MouseWheel += MainBorder_MouseWheel;

        // 60FPS video sync via CompositionTarget.Rendering
        CompositionTarget.Rendering += OnRendering;

        // Additional sync for aggressive dragging
        LocationChanged += (_, _) => SyncVideoPosition();
        SizeChanged += (_, _) => SyncVideoPosition();

        // 500ms timer for video window discovery, metadata, z-order
        _timer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(500) };
        _timer.Tick += Timer_Tick;
        _timer.Start();

        // Setup system tray
        SetupTrayIcon();

        // Start engine BEFORE showing window (saves ~1 second perceived startup)
        _engine.Start();
    }

    // =================== ENGINE EVENTS ===================

    private void OnEngineStarted()
    {
        Dispatcher.Invoke(() =>
        {
            AirPlayIcon.Fill = new SolidColorBrush((System.Windows.Media.Color)System.Windows.Media.ColorConverter.ConvertFromString("#00D4FF"));
            StatusText.Text = _isPiP ? "Video in Pille" : "Video Vollbild";
            StatusText.Foreground = new SolidColorBrush((System.Windows.Media.Color)System.Windows.Media.ColorConverter.ConvertFromString("#00D4FF"));
            MainBorder.BorderBrush = new SolidColorBrush((System.Windows.Media.Color)System.Windows.Media.ColorConverter.ConvertFromString("#3300D4FF"));
        });
    }

    private void OnEngineStopped()
    {
        Dispatcher.Invoke(() =>
        {
            AirPlayIcon.Fill = System.Windows.Media.Brushes.White;
            StatusText.Text = "Bereit";
            StatusText.Foreground = new SolidColorBrush((System.Windows.Media.Color)System.Windows.Media.ColorConverter.ConvertFromString("#A0FFFFFF"));
            MainBorder.BorderBrush = new SolidColorBrush((System.Windows.Media.Color)System.Windows.Media.ColorConverter.ConvertFromString("#33FFFFFF"));
        });
    }

    private void OnEngineError(string message)
    {
        Dispatcher.Invoke(() =>
        {
            StatusText.Text = message;
            StatusText.Foreground = new SolidColorBrush((System.Windows.Media.Color)System.Windows.Media.ColorConverter.ConvertFromString("#FF4444"));
        });
    }

    // =================== VOLUME CONTROL (MOUSE WHEEL) ===================

    private void MainBorder_MouseWheel(object sender, MouseWheelEventArgs e)
    {
        // Send system volume up/down via WScript.Shell SendKeys
        // Using keybd_event is more reliable in MSIX context
        try
        {
            if (e.Delta > 0)
                SendVolumeKey(0xAF); // VK_VOLUME_UP
            else
                SendVolumeKey(0xAE); // VK_VOLUME_DOWN
        }
        catch { }
    }

    [System.Runtime.InteropServices.DllImport("user32.dll")]
    private static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);

    private static void SendVolumeKey(byte vk)
    {
        keybd_event(vk, 0, 0, UIntPtr.Zero);
        keybd_event(vk, 0, 0x0002, UIntPtr.Zero); // KEYEVENTF_KEYUP
    }

    // =================== DRAG + Z-ORDER FIX ===================

    private void TopGrid_MouseLeftButtonDown(object sender, MouseButtonEventArgs e)
    {
        DragMove();
        // After drag: push WPF behind video (Z-order fix for "dark background" bug)
        if (_vidHwnd != IntPtr.Zero)
        {
            var winH = new WindowInteropHelper(this);
            Win32.SetWindowPos(winH.Handle, _vidHwnd, 0, 0, 0, 0, Win32.SWP_ZORDER_ONLY);
        }
    }

    // =================== PIP / FULLSCREEN TOGGLE ===================

    private void PipButton_Click(object sender, RoutedEventArgs e)
    {
        _isPiP = !_isPiP;
        if (_isPiP)
        {
            PipButton.Foreground = HexBrush("#00D4FF");
            PipButton.Content = "Pille";
            if (_engine.IsRunning) StatusText.Text = "Video in Pille";
        }
        else
        {
            PipButton.Foreground = HexBrush("#66FFFFFF");
            PipButton.Content = "Vollbild";
            if (_engine.IsRunning) StatusText.Text = "Video Vollbild";
        }
    }

    // =================== TOPMOST TOGGLE ===================

    private void TopButton_Click(object sender, RoutedEventArgs e)
    {
        Topmost = !Topmost;
        if (Topmost)
        {
            TopButton.Foreground = HexBrush("#00D4FF");
            TopButton.Content = "Pin";
        }
        else
        {
            TopButton.Foreground = HexBrush("#66FFFFFF");
            TopButton.Content = "Normal";
        }

        var winHelper = new WindowInteropHelper(this);
        var insertAfter = Topmost ? Win32.HWND_TOPMOST : Win32.HWND_NOTOPMOST;
        Win32.SetWindowPos(winHelper.Handle, insertAfter, 0, 0, 0, 0, Win32.SWP_NOMOVE_NOSIZE);

        SyncVideoPosition();
    }

    // =================== CLOSE (HIDE TO TRAY) ===================

    private void CloseButton_Click(object sender, RoutedEventArgs e)
    {
        Hide();
    }

    // =================== 60FPS VIDEO SYNC (CompositionTarget.Rendering) ===================

    private void OnRendering(object? sender, EventArgs e)
    {
        if (_vidHwnd != IntPtr.Zero && _isPiP)
        {
            SyncVideoPosition();
        }
    }

    /// <summary>
    /// Synchronize the uxplay video window position to match the WPF placeholder.
    /// Uses SWP_NOACTIVATE (0x0050) to avoid stealing focus from DragMove.
    /// 
    /// CRITICAL: Never use 0x0040 without NOACTIVATE — it breaks dragging!
    /// </summary>
    private void SyncVideoPosition()
    {
        if (_vidHwnd == IntPtr.Zero || !IsLoaded) return;

        var zOrder = Topmost ? Win32.HWND_TOPMOST : Win32.HWND_NOTOPMOST;

        if (_isPiP)
        {
            try
            {
                var w = VideoPlaceholder.ActualWidth;
                var h = VideoPlaceholder.ActualHeight;
                if (w < 10 || h < 10)
                {
                    Win32.SetWindowPos(_vidHwnd, zOrder, -9999, -9999, 10, 10, Win32.SWP_SHOW_NOACTIVATE);
                    return;
                }

                var pt = VideoPlaceholder.PointToScreen(new System.Windows.Point(0, 0));
                var x = (int)pt.X;
                var y = (int)pt.Y;

                if (x != _lastVidX || y != _lastVidY || (int)w != _lastVidW || (int)h != _lastVidH || zOrder != _lastVidZ)
                {
                    Win32.SetWindowPos(_vidHwnd, zOrder, x, y, (int)w, (int)h, Win32.SWP_SHOW_NOACTIVATE);

                    // Only create new region on size change (prevent memory leak)
                    if ((int)w != _lastVidW || (int)h != _lastVidH)
                    {
                        var rgn = Win32.CreateRoundRectRgn(0, 0, (int)w, (int)h, 25, 25);
                        Win32.SetWindowRgn(_vidHwnd, rgn, true);
                    }

                    _lastVidX = x;
                    _lastVidY = y;
                    _lastVidW = (int)w;
                    _lastVidH = (int)h;
                    _lastVidZ = zOrder;
                }
            }
            catch { }
        }
        else
        {
            // Fullscreen mode
            if (_lastVidW != -2 || zOrder != _lastVidZ)
            {
                var sw = Win32.ScreenWidth();
                var sh = Win32.ScreenHeight();
                Win32.SetWindowPos(_vidHwnd, zOrder, 0, 0, sw, sh, Win32.SWP_SHOW_NOACTIVATE);
                Win32.SetWindowRgn(_vidHwnd, IntPtr.Zero, true);
                _lastVidW = -2; // Sentinel to avoid calling SetWindowPos 60x/sec
                _lastVidZ = zOrder;
            }
        }
    }

    // =================== TIMER TICK (500ms) ===================

    private void Timer_Tick(object? sender, EventArgs e)
    {
        if (!_engine.IsRunning) return;

        // 1. Video window discovery + chrome stripping
        var hWnd = _engine.FindVideoWindow();

        if (hWnd != IntPtr.Zero)
        {
            _vidHwnd = hWnd;
            var style = Win32.GetWindowLong(hWnd, Win32.GWL_STYLE);
            var needsStrip = (style & Win32.WS_CAPTION) == Win32.WS_CAPTION;

            if (needsStrip || _lastPipState != _isPiP)
            {
                // Strip window chrome (titlebar, borders)
                var newStyle = style & ~(Win32.WS_CAPTION | Win32.WS_THICKFRAME | Win32.WS_BORDER | Win32.WS_DLGFRAME);
                Win32.SetWindowLong(hWnd, Win32.GWL_STYLE, newStyle);

                if (_isPiP)
                {
                    // Animate placeholder to iPhone aspect ratio (340x736, 19.5:9)
                    AnimateHeight(VideoPlaceholder, 736, 0.4);
                }
                else
                {
                    AnimateHeight(VideoPlaceholder, 0, 0.3);
                }

                _lastPipState = _isPiP;
                _lastVidW = -1; // Force position update
            }

            if (!_isPiP)
            {
                SyncVideoPosition();
            }
        }
        else
        {
            _vidHwnd = IntPtr.Zero;
            if (VideoPlaceholder.Height > 0)
            {
                AnimateHeight(VideoPlaceholder, 0, 0.3);
            }
        }

        // 2. Metadata watcher
        _metadata.PollMetadata();
        _metadata.PollCover();

        // 3. Z-Order fix: WPF window always behind video in PiP mode
        if (_vidHwnd != IntPtr.Zero && _isPiP)
        {
            var winH = new WindowInteropHelper(this);
            Win32.SetWindowPos(winH.Handle, _vidHwnd, 0, 0, 0, 0, Win32.SWP_ZORDER_ONLY);
        }
    }

    // =================== METADATA EVENT HANDLERS ===================

    private void SetupMetadataEvents()
    {
        _metadata.TrackChanged += (title, artist, extra) =>
        {
            Dispatcher.Invoke(() =>
            {
                TrackTitle.Text = title;
                TrackArtist.Text = artist;

                if (!string.IsNullOrEmpty(extra))
                {
                    TrackAlbum.Text = extra;
                    TrackAlbum.Visibility = Visibility.Visible;
                }
                else
                {
                    TrackAlbum.Visibility = Visibility.Collapsed;
                }

                if (PlayerPanel.Visibility != Visibility.Visible)
                {
                    PlayerPanel.Visibility = Visibility.Visible;
                    MainBorder.CornerRadius = new CornerRadius(25);
                    var fade = new DoubleAnimation(0.0, 1.0, TimeSpan.FromSeconds(0.6));
                    PlayerPanel.BeginAnimation(OpacityProperty, fade);
                }
            });
        };

        _metadata.CoverChanged += (bmp) =>
        {
            Dispatcher.Invoke(() => CoverImage.Source = bmp);
        };
    }

    // =================== SYSTEM TRAY ===================

    private void SetupTrayIcon()
    {
        _trayIcon = new TaskbarIcon
        {
            ToolTipText = "Simple AirPlay"
        };

        // Load icon
        var iconPath = AppPaths.IconPath;
        if (File.Exists(iconPath))
        {
            _trayIcon.Icon = new Icon(iconPath);
        }
        else
        {
            _trayIcon.Icon = SystemIcons.Application;
        }

        // Context menu
        var menu = new System.Windows.Controls.ContextMenu();

        // 32-Bit Engine toggle
        var item32Bit = new System.Windows.Controls.MenuItem
        {
            Header = "32-Bit Engine erzwingen",
            IsCheckable = true,
            IsChecked = _config.Force32Bit
        };
        item32Bit.Click += (_, _) =>
        {
            _config.Force32Bit = item32Bit.IsChecked;
            _config.Save();
        };
        menu.Items.Add(item32Bit);

        // Toggle UI
        var itemToggle = new System.Windows.Controls.MenuItem { Header = "UI Anzeigen / Verstecken" };
        itemToggle.Click += (_, _) =>
        {
            if (Visibility == Visibility.Visible) Hide(); else Show();
        };
        menu.Items.Add(itemToggle);

        // About / Licenses
        var itemAbout = new System.Windows.Controls.MenuItem { Header = "Über / Lizenzen" };
        itemAbout.Click += (_, _) =>
        {
            var aboutWindow = new AboutWindow();
            aboutWindow.Show();
        };
        menu.Items.Add(itemAbout);

        // Stop AirPlay
        var itemStop = new System.Windows.Controls.MenuItem { Header = "AirPlay Stoppen" };
        itemStop.Click += (_, _) =>
        {
            _engine.Stop();
            _vidHwnd = IntPtr.Zero;
            ResetPlayerUI();
        };
        menu.Items.Add(itemStop);

        menu.Items.Add(new System.Windows.Controls.Separator());

        // Exit
        var itemExit = new System.Windows.Controls.MenuItem { Header = "Beenden" };
        itemExit.Click += (_, _) =>
        {
            _trayIcon.Dispose();
            _engine.Stop();
            Close();
        };
        menu.Items.Add(itemExit);

        _trayIcon.ContextMenu = menu;

        // Double-click: toggle UI
        _trayIcon.TrayMouseDoubleClick += (_, _) =>
        {
            if (Visibility == Visibility.Visible) Hide(); else Show();
        };
    }

    // =================== UI HELPERS ===================

    private void ResetPlayerUI()
    {
        if (PlayerPanel.Visibility != Visibility.Collapsed)
        {
            PlayerPanel.Visibility = Visibility.Collapsed;
            PlayerPanel.Opacity = 0;
            MainBorder.CornerRadius = new CornerRadius(35);
        }
        if (VideoPlaceholder.Height > 0)
        {
            AnimateHeight(VideoPlaceholder, 0, 0.3);
        }
    }

    private static void AnimateHeight(FrameworkElement element, double toHeight, double seconds)
    {
        var anim = new DoubleAnimation
        {
            To = toHeight,
            Duration = TimeSpan.FromSeconds(seconds)
        };
        element.BeginAnimation(HeightProperty, anim);
    }

    private static SolidColorBrush HexBrush(string hex)
    {
        return new SolidColorBrush((System.Windows.Media.Color)System.Windows.Media.ColorConverter.ConvertFromString(hex));
    }

    // =================== WINDOW LIFECYCLE ===================

    protected override void OnContentRendered(EventArgs e)
    {
        base.OnContentRendered(e);
        SetupMetadataEvents();
    }

    protected override void OnClosing(System.ComponentModel.CancelEventArgs e)
    {
        _timer.Stop();
        CompositionTarget.Rendering -= OnRendering;
        _trayIcon?.Dispose();
        _engine.Stop();
        base.OnClosing(e);
    }
}