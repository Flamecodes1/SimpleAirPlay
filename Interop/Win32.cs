using System.Runtime.InteropServices;

namespace SimpleAirPlay.Interop;

/// <summary>
/// Win32 P/Invoke declarations for window management.
/// Ported from SimpleAirPlay.ps1 Add-Type block.
/// </summary>
public static class Win32
{
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern IntPtr FindWindow(string? lpClassName, string lpWindowName);

    [DllImport("user32.dll")]
    public static extern int GetWindowLong(IntPtr hWnd, int nIndex);

    [DllImport("user32.dll")]
    public static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);

    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);

    [DllImport("user32.dll")]
    public static extern int GetSystemMetrics(int nIndex);

    [DllImport("user32.dll")]
    public static extern int SetWindowRgn(IntPtr hWnd, IntPtr hRgn, bool bRedraw);

    [DllImport("gdi32.dll")]
    public static extern IntPtr CreateRoundRectRgn(int x1, int y1, int x2, int y2, int cx, int cy);

    [DllImport("user32.dll")]
    public static extern bool IsWindow(IntPtr hWnd);

    // --- Constants ---

    // GetWindowLong index
    public const int GWL_STYLE = -16;

    // Window styles
    public const int WS_CAPTION    = 0x00C00000;
    public const int WS_THICKFRAME = 0x00040000;
    public const int WS_BORDER     = 0x00800000;
    public const int WS_DLGFRAME   = 0x00400000;

    // SetWindowPos flags
    /// <summary>SWP_SHOWWINDOW | SWP_NOACTIVATE — CRITICAL: always use NOACTIVATE to avoid breaking DragMove</summary>
    public const uint SWP_SHOW_NOACTIVATE = 0x0050;
    /// <summary>SWP_SHOWWINDOW | SWP_NOACTIVATE | SWP_NOMOVE | SWP_NOSIZE</summary>
    public const uint SWP_ZORDER_ONLY = 0x0053;
    /// <summary>SWP_NOMOVE | SWP_NOSIZE</summary>
    public const uint SWP_NOMOVE_NOSIZE = 0x0003;

    // SetWindowPos hWndInsertAfter
    public static readonly IntPtr HWND_TOPMOST    = new(-1);
    public static readonly IntPtr HWND_NOTOPMOST  = new(-2);

    // Screen metrics
    public static int ScreenWidth()  => GetSystemMetrics(0);  // SM_CXSCREEN
    public static int ScreenHeight() => GetSystemMetrics(1);  // SM_CYSCREEN
}
