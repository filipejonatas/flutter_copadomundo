param(
  [string] $EnvFile = ".env",
  [string] $ApiBaseUrl,
  [string] $AppCheckWebRecaptchaSiteKey
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

if ([string]::IsNullOrWhiteSpace($AppCheckWebRecaptchaSiteKey)) {
  $AppCheckWebRecaptchaSiteKey = Read-DotEnvValue -Path $EnvFile -Key "APP_CHECK_WEB_RECAPTCHA_SITE_KEY"
}

if ([string]::IsNullOrWhiteSpace($ApiBaseUrl)) {
  throw "API_BASE_URL is required for web release builds."
}

if (-not $ApiBaseUrl.StartsWith("https://")) {
  throw "API_BASE_URL must start with https:// for web release builds."
}

if ([string]::IsNullOrWhiteSpace($AppCheckWebRecaptchaSiteKey)) {
  throw "APP_CHECK_WEB_RECAPTCHA_SITE_KEY is required for web release builds."
}

flutter build web `
  --release `
  "--dart-define=API_BASE_URL=$ApiBaseUrl" `
  "--dart-define=APP_CHECK_WEB_RECAPTCHA_SITE_KEY=$AppCheckWebRecaptchaSiteKey"
