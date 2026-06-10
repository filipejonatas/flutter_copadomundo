param(
  [string] $HostName = "127.0.0.1",
  [int] $Port = 4200,
  [string] $EnvFile = ".env",
  [string] $ApiBaseUrl,
  [switch] $AllowHttpApiUrl
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
$appCheckWebRecaptchaSiteKey = Read-DotEnvValue -Path $EnvFile -Key "APP_CHECK_WEB_RECAPTCHA_SITE_KEY"

$flutterArgs = @(
  "run",
  "-d", "web-server",
  "--web-hostname", $HostName,
  "--web-port", $Port
)

if (-not [string]::IsNullOrWhiteSpace($ApiBaseUrl)) {
  if (-not $ApiBaseUrl.StartsWith("https://") -and -not $AllowHttpApiUrl) {
    throw "API_BASE_URL must start with https://. Use -AllowHttpApiUrl only for local backend testing."
  }

  $flutterArgs += "--dart-define=API_BASE_URL=$ApiBaseUrl"
}

if (-not [string]::IsNullOrWhiteSpace($appCheckWebRecaptchaSiteKey)) {
  $flutterArgs += "--dart-define=APP_CHECK_WEB_RECAPTCHA_SITE_KEY=$appCheckWebRecaptchaSiteKey"
}

flutter @flutterArgs
