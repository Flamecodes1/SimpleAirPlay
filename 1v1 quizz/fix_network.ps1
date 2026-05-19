# Selbst-Elevierendes Skript - Startet neu als Admin falls nötig
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

Write-Host "== Netzwerkadapter Fix wird angewendet ==" -ForegroundColor Cyan

# Suche nach dem Realtek-Adapterkey in der Registry
$adapterKey = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002BE10318}\*" -ErrorAction SilentlyContinue |
    Where-Object { $_.DriverDesc -like "*Realtek*" } |
    Select-Object -First 1

if (-not $adapterKey) {
    Write-Host "Realtek Adapter nicht gefunden!" -ForegroundColor Red
    Pause
    exit
}

$path = $adapterKey.PSPath
Write-Host "Adapter gefunden: $($adapterKey.DriverDesc)" -ForegroundColor Green
Write-Host "Registry-Pfad: $path" -ForegroundColor Gray

# Energiespar- und Geschwindigkeitslimitierungen deaktivieren
$settings = @{
    "*EEE"              = 0   # Energy Efficient Ethernet aus
    "AdvancedEEE"       = 0   # Advanced EEE aus
    "EnableGreenEthernet" = 0 # Green Ethernet aus
    "GigaLite"          = 0   # Gigabit Lite aus (limitiert auf niedrigere Speed)
    "PowerSavingMode"   = 0   # Energiesparmodus aus
    "*SpeedDuplex"      = 0   # Auto-Negotiation (0 = Auto)
    "AutoDisableGigabit" = 0  # Gigabit nicht automatisch deaktivieren
}

foreach ($key in $settings.Keys) {
    try {
        Set-ItemProperty -Path $path -Name $key -Value $settings[$key] -ErrorAction Stop
        Write-Host "OK: $key = $($settings[$key])" -ForegroundColor Green
    } catch {
        Write-Host "FEHLER bei $key : $_" -ForegroundColor Yellow
    }
}

# Adapter neu starten
Write-Host "`nAdapter wird neu gestartet..." -ForegroundColor Cyan
Disable-NetAdapter -Name "Ethernet" -Confirm:$false -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Enable-NetAdapter -Name "Ethernet" -Confirm:$false -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3

# Ergebnis anzeigen
$speed = (Get-NetAdapter -Name "Ethernet" -ErrorAction SilentlyContinue).LinkSpeed
Write-Host "`n== Aktuelle Verbindungsgeschwindigkeit: $speed ==" -ForegroundColor Cyan

if ($speed -like "*1 Gbps*" -or $speed -like "*2.5 Gbps*") {
    Write-Host "ERFOLG! Volle Geschwindigkeit aktiv." -ForegroundColor Green
} else {
    Write-Host "Immer noch $speed. Bitte Kabel und Fritz!Box pruefen." -ForegroundColor Yellow
}

Pause
