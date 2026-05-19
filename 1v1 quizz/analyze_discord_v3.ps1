
$out = "C:\Users\fritz\1v1 quizz\discord_analysis_today.txt"
"--- LOG ANALYSIS for 2026-02-06 ---" | Out-File -FilePath $out -Encoding utf8

$logs = Get-ChildItem 'C:\Users\fritz\AppData\Roaming\discord' -Recurse -Filter *.log
foreach ($log in $logs) {
    # Grep for today's date and relevant keywords
    # 2026-02-06
    # Keywords: Starting, Modules, Ready, Update
    $matches = Select-String -Path $log.FullName -Pattern "2026-02-06.*(Starting|Modules|Ready|Update)"
    if ($matches) {
        "File: $($log.Name)" | Out-File -FilePath $out -Encoding utf8 -Append
        $matches | Select-Object -ExpandProperty Line | Out-File -FilePath $out -Encoding utf8 -Append
        "---" | Out-File -FilePath $out -Encoding utf8 -Append
    }
}
