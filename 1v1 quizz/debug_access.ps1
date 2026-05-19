
$roaming = "C:\Users\fritz\AppData\Roaming"
$local = "C:\Users\fritz\AppData\Local"
$output = "C:\Users\fritz\1v1 quizz\debug_output.txt"

"Checking access..." > $output

if (Test-Path $roaming) {
    "Roaming exists." >> $output
    Get-ChildItem $roaming -Directory | Select-Object -First 20 | Out-String -Width 4096 >> $output
} else {
    "Roaming NOT found." >> $output
}

if (Test-Path $local) {
    "Local exists." >> $output
    Get-ChildItem $local -Directory | Select-Object -First 20 | Out-String -Width 4096 >> $output
} else {
    "Local NOT found." >> $output
}

"UserAssist check:" >> $output
$UserAssistPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist"
if (Test-Path $UserAssistPath) {
    "UserAssist key exists." >> $output
} else {
    "UserAssist key NOT found." >> $output
}
