@echo off
cd /d "%~dp0"
start "GamePowerAuto Manager" powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0GamePowerManager.ps1"
