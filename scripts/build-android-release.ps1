param(
  [Parameter(Mandatory = $true)]
  [string] $ApiBaseUrl,

  [string] $SplitDebugInfo = "build/symbols/android"
)

$ErrorActionPreference = "Stop"

if (-not $ApiBaseUrl.StartsWith("https://")) {
  throw "ApiBaseUrl must start with https://"
}

flutter build appbundle --release `
  --obfuscate `
  --split-debug-info=$SplitDebugInfo `
  --dart-define=API_BASE_URL=$ApiBaseUrl
