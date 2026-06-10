param(
  [string] $HostName = "127.0.0.1",
  [int] $WebPort = 4200,
  [int] $ApiPort = 3000
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$apiDir = Join-Path $root "api"
$apiBaseUrl = "http://127.0.0.1:$ApiPort"
$corsOrigins = "http://127.0.0.1:$WebPort,http://localhost:$WebPort"
$apiOutLog = Join-Path $root "api_server.out.log"
$apiErrLog = Join-Path $root "api_server.err.log"

function Test-PortOpen {
  param([int] $Port)

  $connection = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
  return $null -ne $connection
}

if (-not (Test-PortOpen -Port $ApiPort)) {
  Set-Content -Path $apiOutLog -Value ""
  Set-Content -Path $apiErrLog -Value ""

  $backendCommand = @"
`$env:PORT='$ApiPort'
`$env:NODE_ENV='development'
`$env:CORS_ORIGINS='$corsOrigins'
`$env:FIREBASE_APP_CHECK_REQUIRED='false'
npm run start:dev
"@

  Start-Process `
    -FilePath "powershell.exe" `
    -ArgumentList "-NoProfile", "-Command", $backendCommand `
    -WorkingDirectory $apiDir `
    -WindowStyle Hidden `
    -RedirectStandardOutput $apiOutLog `
    -RedirectStandardError $apiErrLog

  Write-Host "Backend local iniciando em $apiBaseUrl ..."
  Start-Sleep -Seconds 4
} else {
  Write-Host "Backend local ja esta ouvindo na porta $ApiPort."
  Write-Host "Se ainda houver 401 de App Check, pare o processo antigo na porta $ApiPort e rode este script de novo."
}

Write-Host "Flutter web iniciando em http://$HostName`:$WebPort ..."
& (Join-Path $PSScriptRoot "run-web.ps1") `
  -HostName $HostName `
  -Port $WebPort `
  -ApiBaseUrl $apiBaseUrl `
  -AllowHttpApiUrl
