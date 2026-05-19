@echo off
title UxPlay Engine Test
echo Starte UxPlay Engine...
set "PATH=C:\Program Files (x86)\uxplay-windows\_internal\bin;%PATH%"
set "GST_PLUGIN_PATH=C:\Program Files (x86)\uxplay-windows\_internal\lib\gstreamer-1.0"
"C:\Program Files (x86)\uxplay-windows\_internal\bin\uxplay.exe" -n "TestAirPlay"
echo.
echo UxPlay wurde beendet!
pause
