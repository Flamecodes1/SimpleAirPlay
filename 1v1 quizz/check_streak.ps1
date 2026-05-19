$ErrorActionPreference = "SilentlyContinue"
$outFile = "c:\Users\fritz\1v1 quizz\streak_info.txt"
$stream = [System.IO.StreamWriter]::new($outFile, $false, [System.Text.Encoding]::ASCII)

# Get all 1074 events from today and yesterday evening, sorted by time
$yesterday = ([datetime]"2026-02-28 23:00:00")
$ev = Get-WinEvent -FilterHashtable @{LogName = 'System'; Id = 1074; StartTime = $yesterday } -ErrorAction SilentlyContinue

$stream.WriteLine("All shutdown/restart events (chronological):")
$stream.WriteLine("")

# Sort chronologically (oldest first)
$sorted = $ev | Sort-Object TimeCreated

$streak = 0
$maxStreak = 0
$currentStreakStart = $null
$maxStreakStart = $null
$maxStreakEnd = $null

foreach ($e in $sorted) {
    $msg = $e.Message
    $type = "shutdown"
    if ($msg -match "neu starten|restart|reboot") { $type = "restart" }
    
    $stream.WriteLine($e.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss") + " | " + $type)
    
    if ($type -eq "restart") {
        $streak++
        if ($streak -eq 1) { $currentStreakStart = $e.TimeCreated }
        if ($streak -gt $maxStreak) {
            $maxStreak = $streak
            $maxStreakStart = $currentStreakStart
            $maxStreakEnd = $e.TimeCreated
        }
    }
    else {
        $streak = 0
        $currentStreakStart = $null
    }
}

$stream.WriteLine("")
$stream.WriteLine("=== ERGEBNIS ===")
$stream.WriteLine("Aktueller Restart-Streak: " + $streak)
$stream.WriteLine("Laengster Restart-Streak: " + $maxStreak)
if ($maxStreakStart) {
    $stream.WriteLine("Streak Start: " + $maxStreakStart.ToString("yyyy-MM-dd HH:mm:ss"))
    $stream.WriteLine("Streak Ende: " + $maxStreakEnd.ToString("yyyy-MM-dd HH:mm:ss"))
}

$stream.Close()
