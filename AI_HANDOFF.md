# Simple AirPlay 5.0 - AI Handoff & Ultimate Developer Guide

> [!IMPORTANT]
> **An die nächste KI (AI Agent):** Lies dieses Dokument vollständig, BEVOR du Code änderst. Es enthält die komprimierte Erfahrung und alle Workarounds aus vergangenen Sessions. Dieses Dokument ist deine "Single Source of Truth", um Token und Zeit zu sparen.

**Letztes Update:** 2026-05-19 — Komplett-Migration von PowerShell auf C# WPF für Microsoft Store (MSIX).

---

## 1. Projekt-Vision & Ziel

"Simple AirPlay" ist ein minimalistischer, hochperformanter AirPlay-Receiver für Windows. Er kombiniert die Stabilität der C/GStreamer-basierten `uxplay`-Engine mit einer modernen, dynamischen WPF-Oberfläche.
Das Ziel: Eine "Apple-like" User Experience (UX), die komplett ohne Konfiguration auskommt ("Zero-Config"), sich nahtlos in den Desktop einfügt (Dynamic Island / "Pille") und 60FPS Video ohne Rand anzeigt.

**NEU in v5.0:** Die gesamte App wurde von PowerShell nach C# WPF portiert, um MSIX-Packaging für den Microsoft Store zu ermöglichen. Kein Admin mehr nötig.

---

## 2. Datei-Struktur (v5.0 — C# WPF + MSIX)

```
SimpleAirPlayApp/
├── SimpleAirPlay.csproj        # Projekt — net9.0-windows10.0.19041.0, MSIX
├── Package.appxmanifest        # MSIX-Manifest (Firewall Rules, Capabilities)
├── App.xaml / App.xaml.cs      # Application Entry Point (Single Instance Mutex)
├── MainWindow.xaml             # Dynamic Pill UI (XAML)
├── MainWindow.xaml.cs          # Gesamte Logik (Video Sync, Z-Order, Tray, etc.)
├── Interop/
│   └── Win32.cs                # P/Invoke Deklarationen (SetWindowPos, etc.)
├── Services/
│   ├── AppPaths.cs             # Pfad-Management (InstallDir read-only, AppData writable)
│   ├── ConfigManager.cs        # config.ini + mac.txt Verwaltung
│   ├── EngineManager.cs        # uxplay.exe Prozess-Lifecycle
│   └── MetadataWatcher.cs      # metadata.txt + cover.jpg Polling
├── Assets/                     # Store-Logos (verschiedene Größen)
├── app_icon.ico                # App-Icon (System-Tray)
│
│ --- Engine Layout (3-Stufen Fallback in EngineManager) ---
│ Option A: Strukturiert (für MSIX-Paketierung)
├── engine/
│   └── bin/
│       └── uxplay.exe          # 64-Bit AirPlay-Engine
│ Option B: Flat (Dev/Build — uxplay.exe neben SimpleAirPlay.exe)
├── uxplay.exe                  # 64-Bit Engine direkt im Output-Ordner
├── lib*.dll                    # GStreamer-DLLs (flat neben der App)
│
├── engine_x86/ (optional)      # 32-Bit Engine
│   └── bin/uxplay.exe
│
│ --- Legacy (Inno Setup, v4.5 — unverändert) ---
├── SimpleAirPlay.ps1           # Alt: PowerShell-UI (v4.5)
├── SimpleAirPlay.vbs           # Alt: Admin-Launcher (v4.5)
├── SimpleAirPlay.bat           # Alt: Debug-Startskript
├── installer.iss               # Alt: Inno Setup Installer (v4.5)
└── BonjourPSSetup.exe          # Alt: Bonjour Installer
```

> [!NOTE]
> **Engine-Pfad Fallback-Kette:** `EngineManager.Start()` sucht in folgender Reihenfolge:
> 1. `engine\bin\uxplay.exe` (strukturiertes MSIX-Layout)
> 2. `uxplay.exe` flat neben `SimpleAirPlay.exe` (Dev-Build / Release-Output)
> 3. Wenn nicht gefunden → "Engine fehlt!" Fehler

---

## 3. Architektur-Vergleich (v4.5 → v5.0)

| Aspekt | v4.5 (PowerShell) | v5.0 (C# WPF / MSIX) |
|--------|-------------------|----------------------|
| UI-Engine | PowerShell dynamisch | XAML + C# Code-Behind |
| Launcher | VBS + `runas` (Admin) | Direkt, kein Admin nötig |
| Packaging | Inno Setup (EXE Installer) | MSIX (Microsoft Store) |
| Firewall | `netsh` Befehle im Installer | `Package.appxmanifest` deklarativ |
| Bonjour | Separater Installer | Windows 10/11 built-in mDNS |
| Config/MAC | Schreibt in Install-Verzeichnis | `LocalAppData\SimpleAirPlay` |
| Tray Icon | `System.Windows.Forms.NotifyIcon` | `H.NotifyIcon.Wpf` (NuGet) |
| Single Instance | Nicht implementiert | Mutex-basiert |

---

## 4. Startvorgang (Lifecycle) — v5.0

1. `App.xaml.cs` → Mutex prüfen (Single Instance). 
   > [!IMPORTANT]
   > Der Mutex wird als statische Variable `_mutex` auf Klassen-Ebene gehalten, da er sonst von der Garbage Collection vorzeitig freigegeben wird.
2. `MainWindow` Konstruktor:
   a. `ConfigManager.Load()` — Config aus `LocalAppData`
   b. `EngineManager` + Events verdrahten
   c. Mouse Wheel Volume Control registrieren
   d. `CompositionTarget.Rendering` → 60FPS Video Sync
   e. `LocationChanged` / `SizeChanged` → Zusätzlicher Sync
   f. `DispatcherTimer` (500ms) → Video-Fenster-Suche, Metadata, Z-Order
   g. System Tray aufsetzen
   h. **`EngineManager.Start()` direkt aufrufen** (vor `ShowDialog` — spart ~1 Sek.)

---

## 5. Die "Dynamic Pill" (PiP) Architektur

**Identisch zu v4.5** — alle Win32-Tricks 1:1 portiert:

### 5.1 Window Chrome Stripping
3-Methoden-Suche für das uxplay-Videofenster:
1. `_proc.MainWindowHandle` → direkter Prozess-Handle
2. `Process.GetProcessesByName("uxplay")` → partielle Titelsuche
3. `Win32.FindWindow()` → Fallback auf bekannte Fenstertitel

### 5.2 60FPS Syncing
- `CompositionTarget.Rendering` Hook → Pixel-perfektes Dragging
- `LocationChanged` + `SizeChanged` → Sofort-Updates bei aggressivem Dragging
- `CreateRoundRectRgn` → 25px Rundungen im DirectX-Fenster
- iPhone Aspect Ratio → 736px Höhe (19.5:9)
- **`SWP_SHOW_NOACTIVATE` (0x0050)** für alle Sync-Calls

### 5.3 Z-Order Trick
WPF wird via `SetWindowPos` exakt eine Ebene unter das Video gezwungen.
→ Video bleibt immer 100% hell sichtbar.

---

## 6. MSIX / Microsoft Store Besonderheiten

### 6.1 Pfade (MSIX Sandbox)
- **Install-Verzeichnis ist READ-ONLY!** → `AppDomain.CurrentDomain.BaseDirectory`
- **Schreibbare Daten** → `Environment.GetFolderPath(LocalApplicationData)\SimpleAirPlay`
- Alle Pfade zentral in `Services/AppPaths.cs`

### 6.2 Firewall-Regeln
Deklariert in `Package.appxmanifest`:
```xml
<desktop2:FirewallRules Executable="engine\bin\uxplay.exe">
  <desktop2:Rule Direction="in" IPProtocol="UDP" LocalPortMin="5353" LocalPortMax="5353" Profile="all"/>
  <desktop2:Rule Direction="in" IPProtocol="TCP" LocalPortMin="7000" LocalPortMax="7001" Profile="all"/>
  <desktop2:Rule Direction="in" IPProtocol="TCP" LocalPortMin="7100" LocalPortMax="7100" Profile="all"/>
  <desktop2:Rule Direction="in" IPProtocol="UDP" LocalPortMin="6000" LocalPortMax="6001" Profile="all"/>
  <desktop2:Rule Direction="in" IPProtocol="UDP" LocalPortMin="7011" LocalPortMax="7011" Profile="all"/>
</desktop2:FirewallRules>
```
→ Automatisch bei Install, automatisch bei Uninstall entfernt.

### 6.3 Capabilities
- `runFullTrust` → Desktop Bridge (uxplay.exe als Subprocess)
- `internetClient` + `privateNetworkClientServer` → AirPlay Netzwerk

### 6.4 Kein Admin
- Kein `runas`, kein UAC
- Bonjour-Service wird NICHT mehr gestartet (Windows built-in mDNS)

---

## 7. Netzwerkanbindung & AirPlay Discovery

- **Persistent MAC (`mac.txt` in AppData):** iPhone findet den Receiver sofort wieder.
- **mDNS:** Windows 10/11 hat eingebauten mDNS-Support über `Dnscache`.
  Apple's Bonjour ist optional, aber kann die Zuverlässigkeit verbessern.
- **Engine-Argumente:** `-n "$deviceName" -p -m $mac -fps $fps -md "metadata.txt" -ca "cover.jpg"`

---

## 8. 🚫 KRITISCHE WARNUNGEN (Never Touch)

> [!CAUTION]
> **Lese NIEMALS die StandardOutput-Pipe von uxplay.exe!**
> `uxplay` flutet die Konsole mit `\r`-Zeichen → Pipe Deadlock → Engine crash.
> `RedirectStandardOutput = false` muss immer `false` bleiben.
> Metadaten werden über `metadata.txt` und `cover.jpg` gelesen.

> [!CAUTION]
> **Immer `SWP_NOACTIVATE` nutzen!**
> Alle `SetWindowPos`-Aufrufe MÜSSEN Flag `0x0050` nutzen.
> Ohne `NOACTIVATE` bricht `DragMove()` sofort ab.

> [!WARNING]
> **Fenstertitel sind variabel:** Die Engine gibt je nach GStreamer-Backend unterschiedliche Fenstertitel aus. Die 3-stufige Suchlogik muss erhalten bleiben.

> [!WARNING]
> **MSIX Install-Dir ist READ-ONLY!** Schreibe niemals in `AppDomain.CurrentDomain.BaseDirectory`. Nutze `AppPaths.DataDir` für alle schreibbaren Dateien.

> [!CAUTION]
> **Engine-Dateien lokal im Workspace halten!**
> Die `engine\`-Ordnerstruktur (mit `bin` und `lib` Unterordnern) muss zwingend im Projektverzeichnis existieren, da die Assets sonst beim Builden nicht kopiert werden. Wenn Dateien fehlen, kopiere sie aus dem Systempfad `C:\Program Files (x86)\uxplay-windows\_internal`.

---

## 9. UI-Aufbau (Button-Referenz)

Alle Buttons in `TopGrid` (5 Spalten, 70px hoch):

| Spalte | Element | Beschreibung |
|--------|---------|--------------|
| 0 | `AirPlayIcon` (Path) | AirPlay-Screen-Icon, wechselt zu `#00D4FF` wenn Engine läuft |
| 1 | Textstack (`TitleText`, `StatusText`) | Gerätename + Statustext |
| 2 | `PipButton` "Pille/Vollbild" | Toggle PiP ↔ Vollbild |
| 3 | `TopButton` "Pin/Normal" | Toggle `Topmost` + Z-Order |
| 4 | `CloseButton` "✕" | Versteckt Fenster (Server läuft weiter im Tray) |

---

## 10. System Tray (Kontextmenü)

Über `H.NotifyIcon.Wpf` (NuGet):
- **"32-Bit Engine erzwingen"** — Checkbox, persistiert in config.ini
- **"UI Anzeigen / Verstecken"** — Toggle Visibility
- **"AirPlay Stoppen"** — Kill Engine, UI Reset
- **"Beenden"** — Kill Engine + Tray, Close Window
- Doppelklick: Toggle UI

---

## 11. Build & Deployment

```bash
# Build
dotnet build

# Run (Debug)
dotnet run

# MSIX erstellen (Release)
dotnet publish -c Release
```

Für Microsoft Store Upload:
1. Microsoft Partner Center Account ($19 einmalig)
2. `Package.appxmanifest` → Publisher auf Store-Certificate anpassen
3. Visual Studio → Publish → Create App Package → Store Upload

---

## 12. Bekannte Einschränkungen

- **Live-Zeit nicht möglich** (Pipe Deadlock — siehe Warnung oben)
- **Screensharing ~0.5-1 Sek. Verzögerung** bis MainWindowHandle valid
- **Z-Order Flicker bei sehr schnellem Drag** (1-2 Frames, unvermeidlich)
- **Bonjour optional:** Falls mDNS-Discovery nicht klappt, muss der User Bonjour separat installieren
