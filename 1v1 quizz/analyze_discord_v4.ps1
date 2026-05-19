# Analyze Discord Opens Today

I'll check Discord logs and registry entries to determine how many times it was opened today (2026-02-25).

$today = Get-Date -Format "yyyy-MM-dd"
$out = "C:\Users\fritz\1v1 quizz\discord_analysis_v4.txt"
"--- DISCORD ANALYSIS v4 for $today ---" | Out-File -FilePath $out -Encoding utf8

# 1. Check Roaming Logs
$roamingLogs = Get-ChildItem "C:\Users\fritz\AppData\Roaming\discord\*.log" -Recurse -ErrorAction SilentlyContinue
foreach ($log in $roamingLogs) {
    $matches = Select-String -Path $log.FullName -Pattern "$today.*(Starting|Logging initialized|Ready|Modules)"
    if ($matches) {
        "Found in $($log.FullName):" | Out-File -FilePath $out -Append
        $matches | Select-Object -ExpandProperty Line | Out-File -FilePath $out -Append
    }
}

# 2. Check Local Logs
$localLogs = Get-ChildItem "C:\Users\fritz\AppData\Local\Discord\*.log" -Recurse -ErrorAction SilentlyContinue
foreach ($log in $localLogs) {
    $matches = Select-String -Path $log.FullName -Pattern "$today.*(Starting|Logging initialized|Ready|Modules)"
    if ($matches) {
        "Found in $($log.FullName):" | Out-File -FilePath $out -Append
        $matches | Select-Object -ExpandProperty Line | Out-File -FilePath $out -Append
    }
}

# 3. Check UserAssist Registry (Requires decoding ROT13)
function Decode-ROT13($text) {
    $chars = $text.ToCharArray()
    for ($i=0; $i -lt $chars.Count; $i++) {
        $c = [int]$chars[$i]
        if ($c -ge 65 -and $c -le 90) { $chars[$i] = [char](((($c - 65) + 13) % 26) + 65) }
        elseif ($c -ge 97 -and $c -le 122) { $chars[$i] = [char](((($c - 97) + 13) % 26) + 97) }
    }
    return -join $chars
}

"--- UserAssist Registry ---" | Out-File -FilePath $out -Append
$uaKeys = Get-ChildItem HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist
foreach ($uaKey in $uaKeys) {
    $countKey = Join-Path $uaKey.PSPath "Count"
    if (Test-Path $countKey) {
        $values = Get-ItemProperty $countKey
        foreach ($prop in $values.PSObject.Properties) {
            $decoded = Decode-ROT13 $prop.Name
            if ($decoded -like "*Discord.exe*") {
                "Decoded Name: $decoded" | Out-File -FilePath $out -Append
                $raw = $prop.Value
                if ($raw -is [byte[]]) {
                    $runCount = [BitConverter]::ToUInt32($raw, 4)
                    $fileTime = [BitConverter]::ToInt64($raw, 60)
                    if ($fileTime -gt 0) {
                        $lastRun = [DateTime]::FromFileTime($fileTime)
                        "Run Count: $runCount, Last Run: $lastRun" | Out-File -FilePath $out -Append
                    }
                }
            }
        }
    }
}
