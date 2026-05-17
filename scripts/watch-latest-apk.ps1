param(
  [string]$Repo = "Krazel/Alarmy",
  [string]$WorkflowName = "Build Android APK",
  [string]$ArtifactName = "Alarma-android-apk",
  [string]$AppVersion = "1.0",
  [string]$Commit = "",
  [int]$IntervalSeconds = 60,
  [int]$MaxAttempts = 30
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$artifactDir = Join-Path $root "artifact"
$oldDir = Join-Path $artifactDir "old"
New-Item -ItemType Directory -Force -Path $artifactDir | Out-Null
New-Item -ItemType Directory -Force -Path $oldDir | Out-Null

if ([string]::IsNullOrWhiteSpace($Commit)) {
  $Commit = (git -C $root rev-parse HEAD).Trim()
}

$headers = @{
  "User-Agent" = "Alarma-Android-Artifact-Watcher"
  "Accept" = "application/vnd.github+json"
}

if ($env:GITHUB_TOKEN) {
  $headers["Authorization"] = "Bearer $env:GITHUB_TOKEN"
}

function Get-LatestRun {
  $runsUrl = "https://api.github.com/repos/$Repo/actions/runs?per_page=20"
  $runs = Invoke-RestMethod -Uri $runsUrl -Headers $headers
  return $runs.workflow_runs |
    Where-Object { $_.name -eq $WorkflowName -and ($_.head_sha -eq $Commit -or $_.head_sha.StartsWith($Commit)) } |
    Sort-Object created_at -Descending |
    Select-Object -First 1
}

function Move-CurrentArtifacts {
  Get-ChildItem -LiteralPath $artifactDir |
    Where-Object { $_.Name -ne "old" -and $_.Name -ne ".gitkeep" -and $_.Name -like "*Android*.apk" } |
    ForEach-Object { Move-Item -LiteralPath $_.FullName -Destination $oldDir -Force }
}

for ($attempt = 1; $attempt -le $MaxAttempts; $attempt += 1) {
  $run = Get-LatestRun

  if ($null -eq $run) {
    Write-Host "[$attempt/$MaxAttempts] Aun no hay run para $Commit."
  } elseif ($run.status -ne "completed") {
    Write-Host "[$attempt/$MaxAttempts] Build en curso: $($run.status)."
  } elseif ($run.conclusion -eq "success") {
    Write-Host "Build correcta: $($run.html_url)"
    $runDir = Join-Path $oldDir "Alarma-android-apk-run-$($run.id)"
    New-Item -ItemType Directory -Force -Path $runDir | Out-Null
    $versionedPath = Join-Path $artifactDir "Alarma-Android-v$AppVersion-build-$($run.run_number).apk"
    $downloadPath = Join-Path $runDir "Alarma-Android-latest.apk"
    $releaseUrl = "https://github.com/$Repo/releases/download/latest-android/Alarma-Android-latest.apk"

    Move-CurrentArtifacts
    try {
      Invoke-WebRequest -Uri $releaseUrl -Headers @{ "User-Agent" = "Alarma-Android-Artifact-Watcher" } -OutFile $downloadPath
      Copy-Item -LiteralPath $downloadPath -Destination $versionedPath -Force
    } catch {
      if (-not $env:GITHUB_TOKEN) {
        throw "La build termino, pero la release latest-android aun no esta disponible o requiere token. Reintenta en un minuto."
      }

      $artifactsUrl = "https://api.github.com/repos/$Repo/actions/runs/$($run.id)/artifacts"
      $artifacts = Invoke-RestMethod -Uri $artifactsUrl -Headers $headers
      $artifact = $artifacts.artifacts | Where-Object { $_.name -eq $ArtifactName -and -not $_.expired } | Select-Object -First 1
      if ($null -eq $artifact) {
        throw "Build correcta, pero no se encontro el artifact $ArtifactName."
      }
      $zipPath = Join-Path $runDir "Alarma-android-apk-run-$($run.id).zip"
      Invoke-WebRequest -Uri $artifact.archive_download_url -Headers $headers -OutFile $zipPath
      Expand-Archive -Path $zipPath -DestinationPath $runDir -Force
      $apkPath = Join-Path $runDir "Alarma-Android-latest.apk"
      if (!(Test-Path -LiteralPath $apkPath)) {
        throw "No se encontro Alarma-Android-latest.apk dentro del artifact."
      }
      Copy-Item -LiteralPath $apkPath -Destination $versionedPath -Force
    }

    Write-Host "APK descargado: $versionedPath"
    exit 0
  } else {
    Write-Error "Build fallida: $($run.conclusion) $($run.html_url)"
    exit 1
  }

  Start-Sleep -Seconds $IntervalSeconds
}

Write-Error "No se completo la build tras $MaxAttempts intentos."
exit 2
