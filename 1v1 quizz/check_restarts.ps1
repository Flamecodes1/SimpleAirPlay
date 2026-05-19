$ErrorActionPreference = "SilentlyContinue"
$outFile = "c:\Users\fritz\1v1 quizz\restart_info.txt"
$stream = [System.IO.StreamWriter]::new($outFile, $false, [System.Text.Encoding]::ASCII)

$today = (Get-Date).Date
$yesterday = $today.AddDays(-1)

$stream.WriteLine("=== Event 1074 (Shutdown/Restart Reason) - Yesterday 28.02. ===")
$ev1074_yesterday = Get-WinEvent -FilterHashtable @{LogName = 'System'; Id = 1074; StartTime = $yesterday; EndTime = $today } -ErrorAction SilentlyContinue
if ($ev1074_yesterday) {
    foreach ($e in $ev1074_yesterday) {
        $msg = $e.Message
        $type = "unknown"
        if ($msg -match "Typ des Herunterfahrens:\s*(.+?)[\r\n]") { $type = $Matches[1] }
        elseif ($msg -match "shutdown type:\s*(.+?)[\r\n]") { $type = $Matches[1] }
        elseif ($msg -match "Neustart|restart|reboot") { $type = "restart" }
        elseif ($msg -match "Herunterfahren|shutdown|power off") { $type = "shutdown" }
        $stream.WriteLine($e.TimeCreated.ToString("HH:mm:ss") + " | Type: " + $type)
        # Also write first 200 chars of message for debugging
        $shortMsg = $msg.Substring(0, [Math]::Min(200, $msg.Length)).Replace("`r`n", " ").Replace("`n", " ")
        $stream.WriteLine("  MSG: " + $shortMsg)
    }
}
else {
    $stream.WriteLine("No events found")
}

$stream.WriteLine("")
$stream.WriteLine("=== Event 1074 (Shutdown/Restart Reason) - Today 01.03. ===")
$ev1074_today = Get-WinEvent -FilterHashtable @{LogName = 'System'; Id = 1074; StartTime = $today } -ErrorAction SilentlyContinue
if ($ev1074_today) {
    foreach ($e in $ev1074_today) {
        $msg = $e.Message
        $type = "unknown"
        if ($msg -match "Typ des Herunterfahrens:\s*(.+?)[\r\n]") { $type = $Matches[1] }
        elseif ($msg -match "shutdown type:\s*(.+?)[\r\n]") { $type = $Matches[1] }
        elseif ($msg -match "Neustart|restart|reboot") { $type = "restart" }
        elseif ($msg -match "Herunterfahren|shutdown|power off") { $type = "shutdown" }
        $stream.WriteLine($e.TimeCreated.ToString("HH:mm:ss") + " | Type: " + $type)
        $shortMsg = $msg.Substring(0, [Math]::Min(200, $msg.Length)).Replace("`r`n", " ").Replace("`n", " ")
        $stream.WriteLine("  MSG: " + $shortMsg)
    }
}
else {
    $stream.WriteLine("No events found")
}

$stream.WriteLine("")
$stream.WriteLine("=== Summary ===")
$allYesterday = @($ev1074_yesterday) | Where-Object { $_ -ne $null }
$allToday = @($ev1074_today) | Where-Object { $_ -ne $null }

# Count restarts vs shutdowns from messages
$restartCountYesterday = 0
$shutdownCountYesterday = 0
if ($ev1074_yesterday) {
    foreach ($e in $ev1074_yesterday) {
        if ($e.Message -match "Neustart|restart|reboot") { $restartCountYesterday++ }
        else { $shutdownCountYesterday++ }
    }
}
$restartCountToday = 0
$shutdownCountToday = 0
if ($ev1074_today) {
    foreach ($e in $ev1074_today) {
        if ($e.Message -match "Neustart|restart|reboot") { $restartCountToday++ }
        else { $shutdownCountToday++ }
    }
}

$stream.WriteLine("Yesterday (28.02.): Restarts=$restartCountYesterday, Shutdowns=$shutdownCountYesterday")
$stream.WriteLine("Today (01.03.): Restarts=$restartCountToday, Shutdowns=$shutdownCountToday")

$stream.Close()
