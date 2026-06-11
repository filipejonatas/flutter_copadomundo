param(
  [string] $DeviceId,
  [string] $EnvFile = ".env",
  [string] $ApiBaseUrl,
  [ValidateSet("play_integrity", "debug")]
  [string] $AndroidAppCheckProvider
)

$ErrorActionPreference = "Stop"

function Read-DotEnvValue {
  param(
    [Parameter(Mandatory = $true)]
    [string] $Path,
    [Parameter(Mandatory = $true)]
    [string] $Key
  )

  if (-not (Test-Path $Path)) {
    return $null
  }

  foreach ($line in Get-Content $Path) {
    $trimmed = $line.Trim()
    if ($trimmed.Length -eq 0 -or $trimmed.StartsWith("#")) {
      continue
    }

    $parts = $trimmed.Split("=", 2)
    if ($parts.Length -eq 2 -and $parts[0].Trim() -eq $Key) {
      return $parts[1].Trim().Trim('"').Trim("'")
    }
  }

  return $null
}

if ([string]::IsNullOrWhiteSpace($ApiBaseUrl)) {
  $ApiBaseUrl = Read-DotEnvValue -Path $EnvFile -Key "API_BASE_URL"
}

if ([string]::IsNullOrWhiteSpace($AndroidAppCheckProvider)) {
  $AndroidAppCheckProvider = Read-DotEnvValue -Path $EnvFile -Key "APP_CHECK_ANDROID_PROVIDER"
}

if ([string]::IsNullOrWhiteSpace($ApiBaseUrl)) {
  throw "API_BASE_URL must be configured in $EnvFile or passed with -ApiBaseUrl."
}

if (-not $ApiBaseUrl.StartsWith("https://")) {
  throw "API_BASE_URL must start with https:// when running without the local API."
}

if ([string]::IsNullOrWhiteSpace($AndroidAppCheckProvider)) {
  $AndroidAppCheckProvider = "play_integrity"
}

$flutterArgs = @(
  "run",
  "--dart-define=API_BASE_URL=$ApiBaseUrl",
  "--dart-define=APP_CHECK_ANDROID_PROVIDER=$AndroidAppCheckProvider"
)

if (-not [string]::IsNullOrWhiteSpace($DeviceId)) {
  $flutterArgs += @("-d", $DeviceId)
}

flutter @flutterArgs
