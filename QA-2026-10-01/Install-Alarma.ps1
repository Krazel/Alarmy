param([switch]$CheckOnly)
$ErrorActionPreference = 'Stop'
$qaPythonPath = Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
if (-not (Test-Path -LiteralPath $qaPythonPath)) { throw 'No se encuentra Python del entorno de Codex.' }
$qaArguments = @((Join-Path $PSScriptRoot 'install-usb.py'))
if ($CheckOnly) { $qaArguments += '--help' }
& $qaPythonPath @qaArguments
if ($LASTEXITCODE -ne 0) { throw 'La instalación no se ha completado. Comprueba USB, desbloqueo, confianza y que el iPhone esté registrado.' }
