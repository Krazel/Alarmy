@echo off
setlocal

set "PORT=4176"
set "HOST=0.0.0.0"
set "RULE_NAME=Alarma PWA 4176"
set "APP_DIR=%~dp0"
set "NODE_EXE=C:\Program Files\nodejs\node.exe"

net session >nul 2>&1
if not "%errorlevel%"=="0" (
  echo Solicitando permisos de administrador...
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

cd /d "%APP_DIR%"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop';" ^
  "$port='%PORT%'; $rule='%RULE_NAME%'; $app='%APP_DIR%'; $node='%NODE_EXE%';" ^
  "$ip=(ipconfig | Select-String 'IPv4|Direcci' | ForEach-Object { ($_ -split ':')[-1].Trim() } | Where-Object { $_ -match '^(192\.168|10\.|172\.)' } | Select-Object -First 1);" ^
  "try {" ^
  "  netsh advfirewall firewall delete rule name=$rule | Out-Null;" ^
  "  netsh advfirewall firewall add rule name=$rule dir=in action=allow protocol=TCP localport=$port | Out-Null;" ^
  "  Write-Host ''; Write-Host 'Firewall temporal abierto para el puerto' $port;" ^
  "  Write-Host ''; Write-Host 'App disponible en este PC:'; Write-Host ('  http://127.0.0.1:' + $port);" ^
  "  if ($ip) { Write-Host ''; Write-Host 'Abre en Safari del iPhone:'; Write-Host ('  http://' + $ip + ':' + $port) }" ^
  "  Write-Host ''; Write-Host 'Pulsa ENTER aqui para cerrar el servidor y borrar la regla temporal.'; Write-Host '';" ^
  "  $env:PORT=$port; $env:HOST='0.0.0.0';" ^
  "  $proc=Start-Process -FilePath $node -ArgumentList 'dev-server.cjs' -WorkingDirectory $app -PassThru -WindowStyle Hidden;" ^
  "  Read-Host | Out-Null;" ^
  "} finally {" ^
  "  if ($proc -and -not $proc.HasExited) { Stop-Process -Id $proc.Id -Force }" ^
  "  netsh advfirewall firewall delete rule name=$rule | Out-Null;" ^
  "  Write-Host 'Servidor cerrado y firewall temporal borrado.';" ^
  "}"

pause
