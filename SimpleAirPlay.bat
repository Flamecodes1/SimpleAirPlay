@echo off
title Simple AirPlay Receiver
:: This command launches the PowerShell script in a completely hidden window
start /b powershell -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0SimpleAirPlay.ps1"
exit
