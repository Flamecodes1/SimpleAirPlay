Set objShell = CreateObject("Shell.Application")
scriptDir = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)
args = "-WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -STA -File """ & scriptDir & "\SimpleAirPlay.ps1"""
objShell.ShellExecute "powershell.exe", args, "", "runas", 0
