Add-Type -AssemblyName PresentationFramework
$win = New-Object System.Windows.Window
$txt = New-Object System.Windows.Controls.TextBox
$win.Content = $txt
$proc = New-Object System.Diagnostics.Process
$proc.StartInfo.FileName = "cmd.exe"
$proc.StartInfo.Arguments = "/c echo Hello World && timeout 1 && echo Done"
$proc.StartInfo.RedirectStandardOutput = $true
$proc.StartInfo.UseShellExecute = $false
$proc.StartInfo.CreateNoWindow = $true
$proc.EnableRaisingEvents = $true

Register-ObjectEvent -InputObject $proc -EventName "OutputDataReceived" -Action {
    $data = $EventArgs.Data
    if ($data) {
        $txt.Dispatcher.Invoke([Action]{
            $txt.AppendText($data + "
")
        })
    }
} | Out-Null

$win.Add_Loaded({
    $proc.Start() | Out-Null
    $proc.BeginOutputReadLine()
})
$win.ShowDialog() | Out-Null
