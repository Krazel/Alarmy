@echo off
echo Conecta el iPhone por USB, desbloquealo y acepta Confiar si lo pide.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-Alarma.ps1"
pause
