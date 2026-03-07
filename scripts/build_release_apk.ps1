$ErrorActionPreference = "Stop"

function Get-AppVersion {
  $versionLine = Get-Content ".\pubspec.yaml" |
    Where-Object { $_ -match '^version:\s*([^\s]+)$' } |
    Select-Object -First 1

  if (-not $versionLine) {
    throw "Nao foi possivel encontrar a versao no pubspec.yaml."
  }

  return (($versionLine -split ':\s*', 2)[1] -split '\+')[0]
}

function Get-NextArtifactVersion {
  param(
    [string[]]$SearchDirs,
    [string]$BaseVersion
  )

  $parts = $BaseVersion -split '\.'
  if ($parts.Count -ne 3) {
    return $BaseVersion
  }

  $major = [int]$parts[0]
  $minor = [int]$parts[1]
  $patch = [int]$parts[2]

  $existingPatches = @(
    foreach ($dir in $SearchDirs) {
      if (-not (Test-Path $dir)) {
        continue
      }

      Get-ChildItem $dir -Filter "CodeTrail-$major.$minor.*.apk" -File |
        ForEach-Object {
          if ($_.BaseName -match "^CodeTrail-$major\.$minor\.(\d+)$") {
            [int]$Matches[1]
          }
        }
    }
  ) | Where-Object { $_ -ge $patch }

  if (-not $existingPatches) {
    return $BaseVersion
  }

  $maxPatch = ($existingPatches | Measure-Object -Maximum).Maximum
  return "$major.$minor.$($maxPatch + 1)"
}

$version = Get-AppVersion
$artifactDir = ".\artifacts\release"
$legacyOutputDir = ".\build\releases\release"
$artifactVersion = Get-NextArtifactVersion -SearchDirs @($artifactDir, $legacyOutputDir) -BaseVersion $version
$versionedApk = Join-Path $artifactDir "CodeTrail-$artifactVersion.apk"
$legacyVersionedApk = Join-Path $legacyOutputDir "CodeTrail-$artifactVersion.apk"

& ".\flutter\bin\flutter.bat" build apk --release --dart-define-from-file=env/supabase.local.json

New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null
New-Item -ItemType Directory -Path $legacyOutputDir -Force | Out-Null
Copy-Item ".\build\app\outputs\flutter-apk\app-release.apk" $versionedApk -Force
Copy-Item ".\build\app\outputs\flutter-apk\app-release.apk" $legacyVersionedApk -Force

Write-Host "APK gerada em: $versionedApk"
