$ErrorActionPreference = "SilentlyContinue"
$outFile = "c:\Users\fritz\1v1 quizz\boot_fresh.txt"
$stream = [System.IO.StreamWriter]::new($outFile, $false, [System.Text.Encoding]::ASCII)

$os = Get-CimInstance Win32_OperatingSystem
$stream.WriteLine("CurrentTime: " + (Get-Date).ToString("yyyy-MM-dd HH:mm:ss"))
$stream.WriteLine("LastBoot: " + $os.LastBootUpTime.ToString("yyyy-MM-dd HH:mm:ss"))
$stream.WriteLine("Uptime: " + ((Get-Date) - $os.LastBootUpTime).ToString())

# ALL boot events in log
$allBoots = Get-WinEvent -FilterHashtable @{LogName = 'System'; ProviderName = 'Microsoft-Windows-Kernel-General'; Id = 12 } -ErrorAction SilentlyContinue
$stream.WriteLine("Total Boots (all time): " + $(if ($allBoots) { $allBoots.Count }else { 0 }))

# Earliest log entry
$earliest = Get-WinEvent -LogName System -Oldest -MaxEvents 1
$stream.WriteLine("Logs since: " + $earliest.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss"))

# Today's boots (March 1st)
$today = (Get-Date).Date
$todayBoots = Get-WinEvent -FilterHashtable @{LogName = 'System'; ProviderName = 'Microsoft-Windows-Kernel-General'; Id = 12; StartTime = $today } -ErrorAction SilentlyContinue
$stream.WriteLine("Boots today (01.03.): " + $(if ($todayBoots) { $todayBoots.Count }else { 0 }))
if ($todayBoots) { foreach ($e in $todayBoots) { $stream.WriteLine("  " + $e.TimeCreated.ToString("HH:mm:ss")) } }

# Yesterday's boots (Feb 28th)
$yesterday = $today.AddDays(-1)
$yesterdayBoots = Get-WinEvent -FilterHashtable @{LogName = 'System'; ProviderName = 'Microsoft-Windows-Kernel-General'; Id = 12; StartTime = $yesterday; EndTime = $today } -ErrorAction SilentlyContinue
$stream.WriteLine("Boots yesterday (28.02.): " + $(if ($yesterdayBoots) { $yesterdayBoots.Count }else { 0 }))
if ($yesterdayBoots) { foreach ($e in $yesterdayBoots) { $stream.WriteLine("  " + $e.TimeCreated.ToString("HH:mm:ss")) } }

# Shutdowns
$allShutdowns = Get-WinEvent -FilterHashtable @{LogName = 'System'; ProviderName = 'EventLog'; Id = 6006 } -ErrorAction SilentlyContinue
$stream.WriteLine("Total Clean Shutdowns: " + $(if ($allShutdowns) { $allShutdowns.Count }else { 0 }))
$allUnexpected = Get-WinEvent -FilterHashtable @{LogName = 'System'; Id = 6008 } -ErrorAction SilentlyContinue
$stream.WriteLine("Total Unexpected Shutdowns: " + $(if ($allUnexpected) { $allUnexpected.Count }else { 0 }))

$stream.Close()
