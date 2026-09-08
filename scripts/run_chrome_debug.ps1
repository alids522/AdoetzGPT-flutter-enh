Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$flutter = if (Test-Path 'C:\flutter\bin\flutter.bat') { 'C:\flutter\bin\flutter.bat' } elseif (Test-Path 'C:\Users\abdur\flutter\bin\flutter.bat') { 'C:\Users\abdur\flutter\bin\flutter.bat' } else { 'flutter' }
$requestedPort = if ($env:ADOETZ_WEB_PORT) { [int]$env:ADOETZ_WEB_PORT } else { 5100 }
$port = $requestedPort

while (Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue) {
  $port++
}

if ($port -ne $requestedPort) {
  Write-Host "Port $requestedPort is already in use. Starting Flutter Chrome debug on port $port instead."
}

Set-Location $projectRoot
& $flutter run -d chrome --web-hostname=127.0.0.1 --web-port=$port
