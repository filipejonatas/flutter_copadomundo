param(
  [Parameter(Mandatory = $true)]
  [string] $ApiBaseUrl,

  [ValidateSet("apk", "appbundle")]
  [string] $Target = "apk",

  [ValidateSet("play_integrity", "debug")]
  [string] $AndroidAppCheckProvider = "play_integrity",

  [string] $SplitDebugInfo = "build/symbols/android"
)

$ErrorActionPreference = "Stop"

if (-not $ApiBaseUrl.StartsWith("https://")) {
  throw "ApiBaseUrl must start with https://"
}

$flutterTarget = if ($Target -eq "apk") { "apk" } else { "appbundle" }

flutter build $flutterTarget --release `
  --obfuscate `
  --split-debug-info=$SplitDebugInfo `
  --dart-define=API_BASE_URL=$ApiBaseUrl `
  --dart-define=APP_CHECK_ANDROID_PROVIDER=$AndroidAppCheckProvider
