# Simple AirPlay 4.5 - Dynamic Premium Edition
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Drawing, System.Windows.Forms

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
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
    
    public static int ScreenWidth() { return GetSystemMetrics(0); }  // SM_CXSCREEN
    public static int ScreenHeight() { return GetSystemMetrics(1); } // SM_CYSCREEN
}
"@

function Get-Brush($hex) {
    New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString($hex))
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# --- Config lesen ---
$iniPath = "$scriptDir\config.ini"
$deviceName = "Simple AirPlay"
$fps = "60"
$script:force32Bit = $false
if (Test-Path $iniPath) {
    $iniLines = Get-Content $iniPath
    foreach ($line in $iniLines) {
        if ($line -match "^DeviceName=(.*)") { $deviceName = $matches[1].Trim() }
        if ($line -match "^FPS=(.*)") { $fps = $matches[1].Trim() }
        if ($line -match "^Force32Bit=(.*)") { $script:force32Bit = [System.Convert]::ToBoolean($matches[1].Trim()) }
    }
}

function Kill-Zombies {
    Get-Process uxplay -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    if (Test-Path "$scriptDir\metadata.txt") { Remove-Item "$scriptDir\metadata.txt" -Force -ErrorAction SilentlyContinue }
    if (Test-Path "$scriptDir\cover.jpg") { Remove-Item "$scriptDir\cover.jpg" -Force -ErrorAction SilentlyContinue }
    # Removed runspace and time tracking cleanup
}
Kill-Zombies

$win = New-Object System.Windows.Window
$win.Title = "Simple AirPlay"
$win.Width = 380; $win.SizeToContent = "Height"
$win.WindowStyle = "None"; $win.AllowsTransparency = $true
$win.Background = [System.Windows.Media.Brushes]::Transparent
$win.WindowStartupLocation = "CenterScreen"; $win.Topmost = $true
$win.ShowInTaskbar = $false
[System.Windows.Media.TextOptions]::SetTextFormattingMode($win, "Display")
[System.Windows.Media.TextOptions]::SetTextRenderingMode($win, "ClearType")

$mainBorder = New-Object System.Windows.Controls.Border
$mainBorder.CornerRadius = 35
$mainBorder.Background = Get-Brush "#E6000000"
$mainBorder.BorderBrush = Get-Brush "#33FFFFFF"
$mainBorder.BorderThickness = 1; $mainBorder.Margin = 15
$shadow = New-Object System.Windows.Media.Effects.DropShadowEffect
$shadow.BlurRadius = 25; $shadow.ShadowDepth = 5; $shadow.Opacity = 0.6; $shadow.Color = [System.Windows.Media.Colors]::Black
$mainBorder.Effect = $shadow

# --- LAUTSTÄRKEREGELUNG (MAUSRAD) ---
$mainBorder.Add_MouseWheel({
    param($sender, $e)
    $wshell = New-Object -ComObject WScript.Shell
    if ($e.Delta -gt 0) {
        $wshell.SendKeys([char]175) # Volume Up
    } else {
        $wshell.SendKeys([char]174) # Volume Down
    }
})
$mainBorder.ToolTip = "Mausrad drehen, um die Windows-Lautstärke anzupassen"

$rootStack = New-Object System.Windows.Controls.StackPanel

# ================= TOP PILL =================
$topGrid = New-Object System.Windows.Controls.Grid
$topGrid.Height = 70; $topGrid.Background = [System.Windows.Media.Brushes]::Transparent
$topGrid.Add_MouseLeftButtonDown({ 
    $win.DragMove() 
    if ($script:vidHwnd -ne [IntPtr]::Zero) {
        $winH = New-Object System.Windows.Interop.WindowInteropHelper($win)
        [Win32]::SetWindowPos($winH.Handle, $script:vidHwnd, 0, 0, 0, 0, 0x0053) | Out-Null
    }
})
$topGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width="Auto"}))
$topGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width="*"}))
$topGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width="Auto"}))
$topGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width="Auto"}))
$topGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width="Auto"}))

$iconPath = New-Object System.Windows.Shapes.Path
$iconPath.Data = [System.Windows.Media.Geometry]::Parse("M 4,4 L 28,4 C 29.1,4 30,4.9 30,6 L 30,22 C 30,23.1 29.1,24 28,24 L 21,24 L 16,18 L 11,24 L 4,24 C 2.9,24 2,23.1 2,22 L 2,6 C 2,4.9 2.9,4 4,4 Z M 16,19 L 23,28 L 9,28 Z")
$iconPath.Fill = [System.Windows.Media.Brushes]::White
$iconPath.Width = 22; $iconPath.Height = 20; $iconPath.Stretch = "Uniform"
$iconPath.VerticalAlignment = "Center"; $iconPath.Margin = "25,0,15,0"
$topGrid.Children.Add($iconPath) | Out-Null
[System.Windows.Controls.Grid]::SetColumn($iconPath, 0)

$textStack = New-Object System.Windows.Controls.StackPanel
$textStack.VerticalAlignment = "Center"
$titleTxt = New-Object System.Windows.Controls.TextBlock
$titleTxt.Text = $deviceName
$titleTxt.Foreground = [System.Windows.Media.Brushes]::White; $titleTxt.FontSize = 14; $titleTxt.FontWeight = "SemiBold"
$statusTxt = New-Object System.Windows.Controls.TextBlock
$statusTxt.Text = "Bereit"
$statusTxt.Foreground = Get-Brush "#A0FFFFFF"; $statusTxt.FontSize = 11
$textStack.Children.Add($titleTxt) | Out-Null; $textStack.Children.Add($statusTxt) | Out-Null
$topGrid.Children.Add($textStack) | Out-Null
[System.Windows.Controls.Grid]::SetColumn($textStack, 1)

$btnTemplate = @"
<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" TargetType="Button">
    <Border x:Name="border" Background="#15FFFFFF" CornerRadius="15">
        <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
    </Border>
    <ControlTemplate.Triggers>
        <Trigger Property="IsMouseOver" Value="True">
            <Trigger.EnterActions><BeginStoryboard><Storyboard>
                <ColorAnimation Storyboard.TargetName="border" Storyboard.TargetProperty="(Border.Background).(SolidColorBrush.Color)" To="#35FFFFFF" Duration="0:0:0.2"/>
            </Storyboard></BeginStoryboard></Trigger.EnterActions>
            <Trigger.ExitActions><BeginStoryboard><Storyboard>
                <ColorAnimation Storyboard.TargetName="border" Storyboard.TargetProperty="(Border.Background).(SolidColorBrush.Color)" To="#15FFFFFF" Duration="0:0:0.25"/>
            </Storyboard></BeginStoryboard></Trigger.ExitActions>
        </Trigger>
    </ControlTemplate.Triggers>
</ControlTemplate>
"@

# --- PICTURE IN PICTURE BUTTON ---
$pipBtn = New-Object System.Windows.Controls.Button
$pipBtn.Content = "Pille"; $pipBtn.Foreground = Get-Brush "#00D4FF"
$pipBtn.FontSize = 11; $pipBtn.FontWeight = "Bold"; $pipBtn.Cursor = [System.Windows.Input.Cursors]::Hand
$pipBtn.Margin = "0,0,10,0"; $pipBtn.Width = 40; $pipBtn.Height = 30; $pipBtn.BorderThickness = 0
$pipBtn.ToolTip = "Video in der Pille oder im Vollbild anzeigen"
$pipBtn.Template = [System.Windows.Markup.XamlReader]::Parse($btnTemplate)
$topGrid.Children.Add($pipBtn) | Out-Null
[System.Windows.Controls.Grid]::SetColumn($pipBtn, 2)

# --- TOPMOST BUTTON ---
$topBtn = New-Object System.Windows.Controls.Button
$topBtn.Content = "Pin"; $topBtn.Foreground = Get-Brush "#00D4FF"
$topBtn.FontSize = 11; $topBtn.FontWeight = "Bold"; $topBtn.Cursor = [System.Windows.Input.Cursors]::Hand
$topBtn.Margin = "0,0,10,0"; $topBtn.Width = 45; $topBtn.Height = 30; $topBtn.BorderThickness = 0
$topBtn.ToolTip = "Fenster immer im Vordergrund behalten"
$topBtn.Template = [System.Windows.Markup.XamlReader]::Parse($btnTemplate)
$topGrid.Children.Add($topBtn) | Out-Null
[System.Windows.Controls.Grid]::SetColumn($topBtn, 3)

$topBtn.Add_Click({
    $win.Topmost = -not $win.Topmost
    if ($win.Topmost) {
        $topBtn.Foreground = Get-Brush "#00D4FF"
        $topBtn.Content = "Pin"
    } else {
        $topBtn.Foreground = Get-Brush "#66FFFFFF"
        $topBtn.Content = "Normal"
    }
    $winHelper = New-Object System.Windows.Interop.WindowInteropHelper($win)
    if ($win.Topmost) {
        [Win32]::SetWindowPos($winHelper.Handle, [IntPtr]-1, 0, 0, 0, 0, 0x0003) | Out-Null
    } else {
        [Win32]::SetWindowPos($winHelper.Handle, [IntPtr]-2, 0, 0, 0, 0, 0x0003) | Out-Null
    }
    Sync-VideoPosition
})

$script:isPiP = $true # Standard: Video öffnet in der Pille
$script:lastPipState = $true

$pipBtn.Add_Click({
    $script:isPiP = -not $script:isPiP
    if ($script:isPiP) {
        $pipBtn.Foreground = Get-Brush "#00D4FF"
        $pipBtn.Content = "Pille"
        if ($script:engineRunning) { $statusTxt.Text = "Video in Pille" }
    } else {
        $pipBtn.Foreground = Get-Brush "#66FFFFFF"
        $pipBtn.Content = "Vollbild"
        if ($script:engineRunning) { $statusTxt.Text = "Video Vollbild" }
    }
})

$closeBtn = New-Object System.Windows.Controls.Button
$closeBtn.Content = [char]0x2715; $closeBtn.Width = 30; $closeBtn.Height = 30
$closeBtn.Foreground = Get-Brush "#66FFFFFF"; $closeBtn.BorderThickness = 0; $closeBtn.FontSize = 12; $closeBtn.Cursor = [System.Windows.Input.Cursors]::Hand
$closeBtn.Margin = "0,0,15,0"
$closeTemplate = @"
<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" TargetType="Button">
    <Border x:Name="border" Background="Transparent" CornerRadius="15">
        <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
    </Border>
    <ControlTemplate.Triggers>
        <Trigger Property="IsMouseOver" Value="True">
            <Trigger.EnterActions><BeginStoryboard><Storyboard>
                <ColorAnimation Storyboard.TargetName="border" Storyboard.TargetProperty="(Border.Background).(SolidColorBrush.Color)" To="#25FF4444" Duration="0:0:0.15"/>
            </Storyboard></BeginStoryboard></Trigger.EnterActions>
            <Trigger.ExitActions><BeginStoryboard><Storyboard>
                <ColorAnimation Storyboard.TargetName="border" Storyboard.TargetProperty="(Border.Background).(SolidColorBrush.Color)" To="Transparent" Duration="0:0:0.2"/>
            </Storyboard></BeginStoryboard></Trigger.ExitActions>
        </Trigger>
    </ControlTemplate.Triggers>
</ControlTemplate>
"@
$closeBtn.Template = [System.Windows.Markup.XamlReader]::Parse($closeTemplate)
$closeBtn.Add_Click({ 
    $win.Hide()
})
$topGrid.Children.Add($closeBtn) | Out-Null
[System.Windows.Controls.Grid]::SetColumn($closeBtn, 4)

# ================= VIDEO PLACEHOLDER =================
$videoPlaceholder = New-Object System.Windows.Controls.Border
$videoPlaceholder.Height = 0
$videoPlaceholder.Margin = "20,0,20,20"
$videoPlaceholder.CornerRadius = 15
$videoPlaceholder.Background = Get-Brush "#0AFFFFFF" # Leicht sichtbar als Rahmen

# ================= BOTTOM PLAYER =================
$playerPanel = New-Object System.Windows.Controls.Grid
$playerPanel.Visibility = "Collapsed"
$playerPanel.Opacity = 0
$playerPanel.Height = 70
$playerPanel.Margin = "20,0,20,15"
$playerPanel.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width="Auto"}))
$playerPanel.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width="*"}))

# Cover art
$coverBorder = New-Object System.Windows.Controls.Border
$coverBorder.Width = 55; $coverBorder.Height = 55; $coverBorder.CornerRadius = 12
$coverBorder.Background = Get-Brush "#15FFFFFF"
$coverBorder.ClipToBounds = $true
$coverImage = New-Object System.Windows.Controls.Image
$coverImage.Stretch = "UniformToFill"
$coverImage.Width = 55; $coverImage.Height = 55
$coverBorder.Child = $coverImage
$playerPanel.Children.Add($coverBorder) | Out-Null
[System.Windows.Controls.Grid]::SetColumn($coverBorder, 0)

# Track info
$trackStack = New-Object System.Windows.Controls.StackPanel
$trackStack.VerticalAlignment = "Center"; $trackStack.Margin = "12,0,0,0"
$trackTitle = New-Object System.Windows.Controls.TextBlock
$trackTitle.Foreground = [System.Windows.Media.Brushes]::White
$trackTitle.FontSize = 13; $trackTitle.FontWeight = "SemiBold"
$trackTitle.TextTrimming = "CharacterEllipsis"
$trackArtist = New-Object System.Windows.Controls.TextBlock
$trackArtist.Foreground = Get-Brush "#99FFFFFF"
$trackArtist.FontSize = 11; $trackArtist.Margin = "0,2,0,0"
$trackArtist.TextTrimming = "CharacterEllipsis"

$trackAlbum = New-Object System.Windows.Controls.TextBlock
$trackAlbum.Foreground = Get-Brush "#66FFFFFF"
$trackAlbum.FontSize = 10; $trackAlbum.Margin = "0,2,0,0"
$trackAlbum.TextTrimming = "CharacterEllipsis"
$trackAlbum.Visibility = "Collapsed"

$trackTime = New-Object System.Windows.Controls.TextBlock
$trackTime.Foreground = Get-Brush "#00D4FF"
$trackTime.FontSize = 10; $trackTime.Margin = "0,2,0,0"
$trackTime.Visibility = "Collapsed"

$trackStack.Children.Add($trackTitle) | Out-Null
$trackStack.Children.Add($trackArtist) | Out-Null
$trackStack.Children.Add($trackAlbum) | Out-Null
$trackStack.Children.Add($trackTime) | Out-Null
$playerPanel.Children.Add($trackStack) | Out-Null
[System.Windows.Controls.Grid]::SetColumn($trackStack, 1)

$rootStack.Children.Add($topGrid) | Out-Null
$rootStack.Children.Add($videoPlaceholder) | Out-Null
$rootStack.Children.Add($playerPanel) | Out-Null
$mainBorder.Child = $rootStack; $win.Content = $mainBorder

# ================= ENGINE =================
$possiblePaths = @(
    (Join-Path $scriptDir "engine\bin\uxplay.exe"),
    (Join-Path $scriptDir "uxplay.exe"),
    "C:\Program Files (x86)\uxplay-windows\_internal\bin\uxplay.exe"
)
if ($script:force32Bit) {
    $possiblePaths = @(
        (Join-Path $scriptDir "engine_x86\bin\uxplay.exe"),
        (Join-Path $scriptDir "uxplay_x86.exe")
    ) + $possiblePaths
}
$engine = $null
foreach ($p in $possiblePaths) { if (Test-Path $p) { $engine = $p; break } }

$script:lastMetaTime = $null
$script:lastCoverTime = $null
$script:lastCoverSize = 0
$script:lastMetaContent = ""
$script:engineRunning = $false

function Start-Engine {
    if (-not $engine) { $statusTxt.Text = "Engine fehlt!"; $statusTxt.Foreground = Get-Brush "#FF4444"; return }
    if ($script:engineRunning) { return }

    # Check Bonjour service (required for AirPlay discovery)
    $bonjour = Get-Service "Bonjour Service" -ErrorAction SilentlyContinue
    if (-not $bonjour) {
        $statusTxt.Text = "Bonjour fehlt!"; $statusTxt.Foreground = Get-Brush "#FF4444"
        return
    }
    if ($bonjour.Status -ne "Running") {
        try { 
            Start-Service "Bonjour Service" -ErrorAction Stop 
        } catch {
            # Try elevating to start Bonjour
            $startProcess = New-Object System.Diagnostics.ProcessStartInfo
            $startProcess.FileName = "powershell.exe"
            $startProcess.Arguments = "-NoProfile -Command `"Start-Service 'Bonjour Service'`""
            $startProcess.Verb = "runAs"
            $startProcess.WindowStyle = "Hidden"
            try {
                $p = [System.Diagnostics.Process]::Start($startProcess)
                $p.WaitForExit()
            } catch {
                $statusTxt.Text = "Admin-Rechte fehlen!"
                $statusTxt.Foreground = Get-Brush "#FF4444"
                return
            }
        }
    }

    Kill-Zombies

    # MAC-Adresse laden oder generieren (Für extrem schnelles Bonjour-Caching auf dem iPhone)
    $macPath = "$scriptDir\mac.txt"
    if (-not (Test-Path $macPath)) {
        $rnd = New-Object Random
        $macBytes = New-Object byte[] 6
        $rnd.NextBytes($macBytes)
        $macBytes[0] = ($macBytes[0] -bor 0x02) -band 0xFE # Locally administered, unicast
        $mac = ($macBytes | ForEach-Object { "{0:X2}" -f $_ }) -join ":"
        [System.IO.File]::WriteAllText($macPath, $mac)
    }
    $mac = [System.IO.File]::ReadAllText($macPath).Trim()

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $engine
    $psi.Arguments = "-n `"$deviceName`" -p -m $mac -fps $fps -md `"$scriptDir\metadata.txt`" -ca `"$scriptDir\cover.jpg`""
    $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $false; $psi.RedirectStandardError = $false

    $dir = Split-Path -Parent $engine
    $psi.WorkingDirectory = $dir
    $psi.EnvironmentVariables["PATH"] = "$dir;$env:PATH"
    $lib = Join-Path (Split-Path -Parent $dir) "lib\gstreamer-1.0"
    if (Test-Path $lib) { $psi.EnvironmentVariables["GST_PLUGIN_PATH"] = $lib }

    $script:proc = [System.Diagnostics.Process]::Start($psi)
    
    $script:engineRunning = $true
    $iconPath.Fill = Get-Brush "#00D4FF"
    if ($script:isPiP) { $statusTxt.Text = "Video in Pille" } else { $statusTxt.Text = "Video Vollbild" }
    $statusTxt.Foreground = Get-Brush "#00D4FF"
    $mainBorder.BorderBrush = Get-Brush "#3300D4FF"
}

# Engine direkt VOR dem Rendern starten (spart ca. 1 Sekunde spürbare Wartezeit)
Start-Engine

# --- VIDEO POSITION SYNC LOGIC ---
$script:vidHwnd = [IntPtr]::Zero
$script:lastVidX = -1; $script:lastVidY = -1; $script:lastVidW = -1; $script:lastVidH = -1
$script:lastVidZ = [IntPtr]::Zero

function Sync-VideoPosition {
    if ($script:vidHwnd -eq [IntPtr]::Zero -or -not $win.IsLoaded) { return }
    
    $zOrder = if ($win.Topmost) { [IntPtr]-1 } else { [IntPtr]-2 }
    
    if ($script:isPiP) {
        try {
            $w = $videoPlaceholder.ActualWidth
            $h = $videoPlaceholder.ActualHeight
            if ($w -lt 10 -or $h -lt 10) { 
                [Win32]::SetWindowPos($script:vidHwnd, $zOrder, -9999, -9999, 10, 10, 0x0050) | Out-Null
                return 
            }
            $p0 = New-Object System.Windows.Point -ArgumentList 0,0
            $pt = $videoPlaceholder.PointToScreen($p0)
            $x = [int]$pt.X; $y = [int]$pt.Y
            
            if ($x -ne $script:lastVidX -or $y -ne $script:lastVidY -or [int]$w -ne $script:lastVidW -or [int]$h -ne $script:lastVidH -or $zOrder -ne $script:lastVidZ) {
                [Win32]::SetWindowPos($script:vidHwnd, $zOrder, $x, $y, [int]$w, [int]$h, 0x0050) | Out-Null
                
                # Nur neue Region erstellen, wenn sich die Größe ändert (Memory Leak verhindern!)
                if ([int]$w -ne $script:lastVidW -or [int]$h -ne $script:lastVidH) {
                    $rgn = [Win32]::CreateRoundRectRgn(0, 0, [int]$w, [int]$h, 25, 25)
                    [Win32]::SetWindowRgn($script:vidHwnd, $rgn, $true) | Out-Null
                }
                
                $script:lastVidX = $x; $script:lastVidY = $y
                $script:lastVidW = [int]$w; $script:lastVidH = [int]$h
                $script:lastVidZ = $zOrder
            }
        } catch {}
    } else {
        if ($script:lastVidW -ne -2 -or $zOrder -ne $script:lastVidZ) { # -2 is a dummy to avoid calling SetWindowPos 60fps
            $sw = [Win32]::ScreenWidth()
            $sh = [Win32]::ScreenHeight()
            [Win32]::SetWindowPos($script:vidHwnd, $zOrder, 0, 0, $sw, $sh, 0x0050) | Out-Null
            [Win32]::SetWindowRgn($script:vidHwnd, [IntPtr]::Zero, $true) | Out-Null
            $script:lastVidW = -2 
            $script:lastVidZ = $zOrder
        }
    }
}

# Hängt sich in den WPF Render-Loop für butterweiches 60FPS Dragging
[System.Windows.Media.CompositionTarget]::add_Rendering({
    if ($script:vidHwnd -and $script:isPiP) {
        Sync-VideoPosition
    }
})

# Zusätzliche Synchronisierung für absolut festes Dragging ohne Verzögerung
$win.Add_LocationChanged({ Sync-VideoPosition })
$win.Add_SizeChanged({ Sync-VideoPosition })

$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(500)
$timer.Add_Tick({
    if (-not $script:engineRunning) { return }

    # 1. Video PiP / Fullscreen Hack
    $hWnd = [IntPtr]::Zero
    
    # Methode 1: Über Process MainWindowHandle
    if ($script:proc -and -not $script:proc.HasExited) {
        try {
            $script:proc.Refresh()
            if ($script:proc.MainWindowHandle -ne [IntPtr]::Zero) {
                $hWnd = $script:proc.MainWindowHandle
            }
        } catch {}
    }
    
    # Methode 2: Über Get-Process mit partiellem Titel
    if ($hWnd -eq [IntPtr]::Zero) {
        $uxplayProc = Get-Process uxplay -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -match "Direct3D|OpenGL|UxPlay|GStreamer" } | Select-Object -First 1
        if ($uxplayProc -and $uxplayProc.MainWindowHandle -ne [IntPtr]::Zero) {
            $hWnd = $uxplayProc.MainWindowHandle
        }
    }

    # Methode 3: Fallback auf Win32 FindWindow
    if ($hWnd -eq [IntPtr]::Zero) {
        $titles = @("Direct 3d11 renderer","Direct3D11 renderer","Direct3D renderer","OpenGL renderer","UxPlay","GStreamer Direct3D11 sink")
        foreach ($t in $titles) {
            $hWnd = [Win32]::FindWindow($null, $t)
            if ($hWnd -ne [IntPtr]::Zero) { break }
        }
    }
    
    if ($hWnd -ne [IntPtr]::Zero) {
        $script:vidHwnd = $hWnd
        $style = [Win32]::GetWindowLong($hWnd, -16)
        $WS_CAPTION = 0x00C00000
        $needsStyleStrip = (($style -band $WS_CAPTION) -eq $WS_CAPTION)

        if ($needsStyleStrip -or ($script:lastPipState -ne $script:isPiP)) {
            $WS_THICKFRAME = 0x00040000
            $WS_BORDER = 0x00800000
            $WS_DLGFRAME = 0x00400000
            
            # Strip window chrome
            $newStyle = $style -band (-bnot ($WS_CAPTION -bor $WS_THICKFRAME -bor $WS_BORDER -bor $WS_DLGFRAME))
            [Win32]::SetWindowLong($hWnd, -16, $newStyle) | Out-Null
            
            if ($script:isPiP) {
                # Animate Placeholder to expand (Smartphone size 340x736 for iPhone aspect ratio)
                $videoAnim = New-Object System.Windows.Media.Animation.DoubleAnimation
                $videoAnim.To = 736
                $videoAnim.Duration = [TimeSpan]::FromSeconds(0.4)
                $videoPlaceholder.BeginAnimation([System.Windows.Controls.Border]::HeightProperty, $videoAnim)
            } else {
                # Close Placeholder
                $videoAnim = New-Object System.Windows.Media.Animation.DoubleAnimation
                $videoAnim.To = 0
                $videoAnim.Duration = [TimeSpan]::FromSeconds(0.3)
                $videoPlaceholder.BeginAnimation([System.Windows.Controls.Border]::HeightProperty, $videoAnim)
            }
            $script:lastPipState = $script:isPiP
            # Force dimension update for SetWindowPos logic
            $script:lastVidW = -1 
        }
        
        if (-not $script:isPiP) {
            Sync-VideoPosition # To snap to fullscreen if it changed
        }
    } else {
        $script:vidHwnd = [IntPtr]::Zero
        # Close Placeholder if video disappears
        if ($videoPlaceholder.Height -gt 0) {
            $videoAnim = New-Object System.Windows.Media.Animation.DoubleAnimation
            $videoAnim.To = 0
            $videoAnim.Duration = [TimeSpan]::FromSeconds(0.3)
            $videoPlaceholder.BeginAnimation([System.Windows.Controls.Border]::HeightProperty, $videoAnim)
        }
    }

    # 2. Metadata Watcher & Animation
    $metaPath = "$scriptDir\metadata.txt"
    if (Test-Path $metaPath) {
        $fileInfo = New-Object System.IO.FileInfo($metaPath)
        if ($fileInfo.LastWriteTime -ne $script:lastMetaTime) {
            $script:lastMetaTime = $fileInfo.LastWriteTime
            try {
                $fs = New-Object System.IO.FileStream($metaPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
                $sr = New-Object System.IO.StreamReader($fs, [System.Text.Encoding]::UTF8)
                $text = $sr.ReadToEnd()
                $sr.Close(); $fs.Close()

                $text = ($text -replace "`0", "").Trim()
                if ($text -match "^no data") { return }

                $lines = $text -split "`r?`n"
                $artist = ""; $title = ""; $album = ""; $genre = ""
                foreach ($line in $lines) {
                    $cl = $line.Trim()
                    if ($cl -match "^Title:\s*(.+)") { $title = $matches[1].Trim() }
                    if ($cl -match "^Artist:\s*(.+)") { $artist = $matches[1].Trim() }
                    if ($cl -match "^Album:\s*(.+)") { $album = $matches[1].Trim() }
                    if ($cl -match "^Genre:\s*(.+)") { $genre = $matches[1].Trim() }
                }

                if ($title -or $artist) {
                    if (-not $title) { $title = "Unknown Track" }
                    if (-not $artist) { $artist = "Unknown Artist" }

                    $trackTitle.Text = $title
                    $trackArtist.Text = $artist
                    
                    $extraInfo = ""
                    if ($album) { $extraInfo += $album }
                    if ($genre) { 
                        if ($extraInfo) { $extraInfo += " • " }
                        $extraInfo += $genre
                    }
                    if ($extraInfo) {
                        $trackAlbum.Text = $extraInfo
                        $trackAlbum.Visibility = "Visible"
                    } else {
                        $trackAlbum.Visibility = "Collapsed"
                    }

                    if ($playerPanel.Visibility -ne "Visible") {
                        $playerPanel.Visibility = "Visible"
                        $mainBorder.CornerRadius = 25
                        $fade = New-Object System.Windows.Media.Animation.DoubleAnimation
                        $fade.From = 0.0; $fade.To = 1.0; $fade.Duration = [TimeSpan]::FromSeconds(0.6)
                        $playerPanel.BeginAnimation([System.Windows.Controls.Grid]::OpacityProperty, $fade)
                    }
                }
            } catch {}
        }
    } else {
        if ($playerPanel.Visibility -ne "Collapsed") {
            $playerPanel.Visibility = "Collapsed"
            $playerPanel.Opacity = 0
            $mainBorder.CornerRadius = 35
        }
    }

    # Removed Live Time Watcher to prevent engine crash
    $trackTime.Visibility = "Collapsed"

    # 4. Cover Art Watcher
    $coverPath = "$scriptDir\cover.jpg"
    if (Test-Path $coverPath) {
        try {
            $coverInfo = New-Object System.IO.FileInfo($coverPath)
            $coverSize = $coverInfo.Length
            $coverTime = $coverInfo.LastWriteTime
            if (($coverTime -ne $script:lastCoverTime -or $coverSize -ne $script:lastCoverSize) -and $coverSize -gt 200) {
                $fs2 = New-Object System.IO.FileStream($coverPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
                $mem = New-Object System.IO.MemoryStream
                $fs2.CopyTo($mem)
                $fs2.Close()
                $mem.Position = 0

                $bmp = New-Object System.Windows.Media.Imaging.BitmapImage
                $bmp.BeginInit()
                $bmp.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
                $bmp.StreamSource = $mem
                $bmp.DecodePixelWidth = 120
                $bmp.EndInit()
                $bmp.Freeze()
                $mem.Close()

                $coverImage.Source = $bmp
                $script:lastCoverTime = $coverTime
                $script:lastCoverSize = $coverSize
            }
        } catch {}
    }

    # 5. Z-Order Fix: WPF-Fenster immer unterhalb des Video-Fensters platzieren
    if ($script:vidHwnd -ne [IntPtr]::Zero -and $script:isPiP) {
        $winH = New-Object System.Windows.Interop.WindowInteropHelper($win)
        [Win32]::SetWindowPos($winH.Handle, $script:vidHwnd, 0, 0, 0, 0, 0x0053) | Out-Null
    }
})
$timer.Start()

# --- System Tray Icon ---
$notifyIcon = New-Object System.Windows.Forms.NotifyIcon
$iconFile = Join-Path $scriptDir "app_icon.ico"
if (Test-Path $iconFile) {
    $notifyIcon.Icon = New-Object System.Drawing.Icon($iconFile)
} else {
    $notifyIcon.Icon = [System.Drawing.SystemIcons]::Application
}
$notifyIcon.Text = "Simple AirPlay"
$notifyIcon.Visible = $true

$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip
$item32Bit = $contextMenu.Items.Add("32-Bit Engine erzwingen")
$item32Bit.CheckOnClick = $true
$item32Bit.Checked = $script:force32Bit
$item32Bit.Add_CheckedChanged({
    $script:force32Bit = $item32Bit.Checked
    $iniContent = @("DeviceName=$deviceName", "FPS=$fps", "Force32Bit=$script:force32Bit")
    [System.IO.File]::WriteAllLines($iniPath, $iniContent)
})
$itemToggle = $contextMenu.Items.Add("UI Anzeigen / Verstecken")
$itemToggle.Add_Click({
    if ($win.Visibility -eq "Visible") { $win.Hide() } else { $win.Show() }
})
$itemStop = $contextMenu.Items.Add("AirPlay Stoppen")
$itemStop.Add_Click({
    if ($script:proc) { try { $script:proc.Kill() } catch {} }
    Kill-Zombies
    $script:engineRunning = $false
    $iconPath.Fill = [System.Windows.Media.Brushes]::White
    $statusTxt.Text = "Bereit"
    $statusTxt.Foreground = Get-Brush "#A0FFFFFF"
    $mainBorder.BorderBrush = Get-Brush "#33FFFFFF"
})
$contextMenu.Items.Add("-") | Out-Null
$itemExit = $contextMenu.Items.Add("Beenden")
$itemExit.Add_Click({
    $notifyIcon.Visible = $false
    if ($script:proc) { try { $script:proc.Kill() } catch {} }
    Kill-Zombies
    $win.Close()
})
$notifyIcon.ContextMenuStrip = $contextMenu
$notifyIcon.Add_DoubleClick({
    if ($win.Visibility -eq "Visible") { $win.Hide() } else { $win.Show() }
})

$win.Add_Closing({
    $notifyIcon.Visible = $false
    $timer.Stop()
    if ($script:proc) { try { $script:proc.Kill() } catch {} }
    Kill-Zombies
})

$win.ShowDialog() | Out-Null
