
$logDir = "C:\Users\fritz\AppData\Roaming\discord"
$out = "C:\Users\fritz\1v1 quizz\discord_analysis.txt"
"--- LOG ANALYSIS ---" | Out-File -FilePath $out -Encoding utf8

$logs = Get-ChildItem $logDir -Recurse -Filter *.log | Where-Object { $_.LastWriteTime.Date -eq (Get-Date).Date }

if ($logs) {
    foreach ($log in $logs) {
        # Check first 50 lines for startup messages
        # We look for "Starting" or "Modules" or "ready"
        # Since reading all is slow, start with Select-String
        $matches = Select-String -Path $log.FullName -Pattern "Starting|Modules|Ready|Splash|Update" -Context 0,0 | Select-Object -First 20
        if ($matches) {
            "File: $($log.Name) ($($log.LastWriteTime))" | Out-File -FilePath $out -Encoding utf8 -Append
            $matches | Out-String | Out-File -FilePath $out -Encoding utf8 -Append
            "----------------" | Out-File -FilePath $out -Encoding utf8 -Append
        }
    }
} else {
    "No logs from today found." | Out-File -FilePath $out -Encoding utf8 -Append
}
