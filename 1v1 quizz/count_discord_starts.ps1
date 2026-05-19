
$targetDate = Get-Date -Year 2026 -Month 2 -Day 6
$out = "C:\Users\fritz\1v1 quizz\discord_exact_count.txt"
"--- STARTUP EVENTS for $($targetDate.ToShortDateString()) ---" | Out-File -FilePath $out -Encoding utf8

$paths = @("C:\Users\fritz\AppData\Roaming\discord", "C:\Users\fritz\AppData\Local\Discord")
$events = @()

foreach ($path in $paths) {
    if (Test-Path $path) {
        $logs = Get-ChildItem $path -Recurse -Filter *.log -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime.Date -eq $targetDate.Date }
        
        foreach ($log in $logs) {
            # Simple grep for timestamps today
            # We look for lines starting with [2026-02-06 ...
            $matches = Select-String -Path $log.FullName -Pattern "\[2026-02-06.*Logging initialized"
            foreach ($m in $matches) {
                $events += [PSCustomObject]@{
                    Time = $m.Line.Substring(1, 19) # Extract timestamp roughly
                    File = $log.Name
                    Line = $m.Line
                }
            }
            
            # Also check for "Starting" in other log formats if different
            $matches2 = Select-String -Path $log.FullName -Pattern "\[2026-02-06.*Starting"
             foreach ($m in $matches2) {
                $events += [PSCustomObject]@{
                    Time = $m.Line.Substring(1, 19)
                    File = $log.Name
                    Line = $m.Line
                }
            }
        }
    }
}

$events | Sort-Object Time | Format-Table -AutoSize | Out-String | Out-File -FilePath $out -Encoding utf8 -Append
