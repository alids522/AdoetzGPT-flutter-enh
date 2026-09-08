Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$flutter = if (Test-Path 'C:\flutter\bin\flutter.bat') { 'C:\flutter\bin\flutter.bat' } elseif (Test-Path 'C:\Users\abdur\flutter\bin\flutter.bat') { 'C:\Users\abdur\flutter\bin\flutter.bat' } else { 'flutter' }

Set-Location $projectRoot
& $flutter run -d android
