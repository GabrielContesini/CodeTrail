$ErrorActionPreference = "Stop"

function Get-AppVersionInfo {
  $versionLine = Get-Content ".\pubspec.yaml" |
    Where-Object { $_ -match '^version:\s*([^\s]+)$' } |
    Select-Object -First 1

  if (-not $versionLine) {
    throw "Nao foi possivel encontrar a versao no pubspec.yaml."
  }

  $rawVersion = (($versionLine -split ':\s*', 2)[1]).Trim()

  if ($rawVersion -notmatch '^(?<buildName>\d+\.\d+\.\d+)\+(?<buildNumber>\d+)$') {
    throw "A versao '$rawVersion' nao esta no formato esperado buildName+buildNumber."
  }

  return [PSCustomObject]@{
    BuildName = $Matches.buildName
    BuildNumber = $Matches.buildNumber
    FullVersion = "$($Matches.buildName)+$($Matches.buildNumber)"
  }
}

function Get-UniqueArtifactPath {
  param(
    [string]$Directory,
    [string]$BaseName,
    [string]$Extension
  )

  New-Item -ItemType Directory -Path $Directory -Force | Out-Null

  $candidate = Join-Path $Directory "$BaseName.$Extension"
  $revision = 1

  while (Test-Path $candidate) {
    $revision += 1
    $candidate = Join-Path $Directory "$BaseName-r$revision.$Extension"
  }

  return $candidate
}

$version = Get-AppVersionInfo
$artifactDir = ".\artifacts\debug"
$artifactName = "CodeTrail-$($version.FullVersion)-debug"
$versionedApk = Get-UniqueArtifactPath -Directory $artifactDir -BaseName $artifactName -Extension "apk"

& ".\flutter\bin\flutter.bat" build apk --debug `
  --build-name=$($version.BuildName) `
  --build-number=$($version.BuildNumber) `
  --dart-define-from-file=env/supabase.local.json

Copy-Item ".\build\app\outputs\flutter-apk\app-debug.apk" $versionedApk -Force

Write-Host "APK gerada em: $versionedApk"
