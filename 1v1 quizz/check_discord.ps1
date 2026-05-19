
function Rot13($s) {
    $r = ""
    foreach ($c in $s.ToCharArray()) {
        $a = [int]$c
        if ($a -ge 65 -and $a -le 77) { $a += 13 }
        elseif ($a -ge 78 -and $a -le 90) { $a -= 13 }
        elseif ($a -ge 97 -and $a -le 109) { $a += 13 }
        elseif ($a -ge 110 -and $a -le 122) { $a -= 13 }
        $r += [char]$a
    }
    return $r
}

Write-Output "Checking UserAssist..."
$UserAssistPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist"
if (Test-Path $UserAssistPath) {
    Get-ChildItem $UserAssistPath | ForEach-Object {
        $countKey = Join-Path $_.PSPath "Count"
        if (Test-Path $countKey) {
            Get-ItemProperty $countKey | ForEach-Object {
                $_.PSObject.Properties | Where-Object { $_.Name -match '[A-Z]' } | ForEach-Object {
                    $decoded = Rot13 $_.Name
                    if ($decoded -like "*Discord*") {
                        # Value is binary. The starting 4 bytes usually contain the run count (UInt32)
                        # But format varies. Usually at offset 4.
                        # For Win7+:
                        # Offset 4: Run Count (4 bytes)
                        # Offset 60: Last Run Time (FILETIME, 8 bytes)? No, structure varies.
                        # Let's just output the raw bytes explanation if possible or just the raw bytes object
                        # We can try to parse the run count.
                        $bytes = $_.Value
                        if ($bytes.Length -ge 8) {
                             $runCount = [BitConverter]::ToUInt32($bytes, 4)
                             # Last execution time is often at offset 60 or similar
                             Write-Output "Found: $decoded | Run Count: $runCount"
                        } else {
                             Write-Output "Found: $decoded | (Bytes too short)"
                        }
                    }
                }
            }
        }
    }
}

Write-Output "Searching for Logs..."
$logPaths = @(
    "C:\Users\fritz\AppData\Roaming\discord\*.log",
    "C:\Users\fritz\AppData\Local\Discord\app-*\modules\*\discord_*.log",
    "C:\Users\fritz\AppData\Roaming\discord\check.log"
)
foreach ($p in $logPaths) {
    if (Test-Path $p) {
        Write-Output "Log found: $p"
        Get-ChildItem $p | Select-Object -First 5
    }
}
