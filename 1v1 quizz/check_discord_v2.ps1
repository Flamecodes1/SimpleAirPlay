
$out = "C:\Users\fritz\1v1 quizz\discord_logs.txt"
"--- SEARCH RESULTS ---" | Out-File -FilePath $out -Encoding utf8

function Log($msg) {
    $msg | Out-File -FilePath $out -Encoding utf8 -Append
}

Log "--- Roaming ---"
$roaming = "C:\Users\fritz\AppData\Roaming\discord"
if (Test-Path $roaming) {
    Log "Roaming path exists."
    $logs = Get-ChildItem $roaming -Recurse -Filter *.log -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 10
    if ($logs) {
        $logs | Select-Object LastWriteTime, FullName | Out-String | Out-File -FilePath $out -Encoding utf8 -Append
    } else {
        Log "No logs found in Roaming."
    }
} else {
    Log "Roaming path NOT found."
}

Log "--- Local ---"
$local = "C:\Users\fritz\AppData\Local\Discord"
if (Test-Path $local) {
    Log "Local path exists."
    $logs = Get-ChildItem $local -Recurse -Filter *.log -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 10
    if ($logs) {
        $logs | Select-Object LastWriteTime, FullName | Out-String | Out-File -FilePath $out -Encoding utf8 -Append
    } else {
        Log "No logs found in Local."
    }
} else {
    Log "Local path NOT found."
}

Log "--- UserAssist ---"
$UserAssistPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist"
if (Test-Path $UserAssistPath) {
    Get-ChildItem $UserAssistPath | ForEach-Object {
        $countKey = Join-Path $_.PSPath "Count"
        if (Test-Path $countKey) {
            Get-ItemProperty $countKey | ForEach-Object {
                $_.PSObject.Properties | Where-Object { $_.Name -match '[A-Z]' } | ForEach-Object {
                     $n = $_.Name
                     $d = -join ($n.ToCharArray() | % { 
                        $c = [int]$_; 
                        if (($c -ge 65 -and $c -le 77) -or ($c -ge 97 -and $c -le 109)) { [char]($c+13) }
                        elseif (($c -ge 78 -and $c -le 90) -or ($c -ge 110 -and $c -le 122)) { [char]($c-13) }
                        else { [char]$c }
                     })
                     if ($d -like "*Discord*") {
                         Log "Found: $d"
                         # Hex dump the value (first 16 bytes)
                         $hex = ($_.Value[0..15] | ForEach-Object { $_.ToString("X2") }) -join " "
                         Log "Val: $hex"
                     }
                }
            }
        }
    }
}
