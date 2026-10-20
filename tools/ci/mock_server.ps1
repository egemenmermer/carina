<#
.SYNOPSIS
  -Start: starts tools/mock_server/bin/mock_server.dart in the background and
  waits until /mock/health answers. -Check: fails unless it still answers.
  Server output goes to mock-server.log in the current directory.

.EXAMPLE
  & tools/ci/mock_server.ps1 -Start -Url http://127.0.0.1:8787
  & tools/ci/mock_server.ps1 -Check -Url http://127.0.0.1:8787
#>
param(
  [switch] $Start,
  [switch] $Check,
  [string] $Url = 'http://127.0.0.1:8787',
  [int] $Port = 8787,
  [string] $Scale = 'small',
  [string] $Media = 'tools/mock_server/media',
  [string] $Log = 'mock-server.log',
  [int] $TimeoutSec = 60
)
$ErrorActionPreference = 'Stop'
$logPath = Join-Path (Get-Location).Path $Log

function Get-Health {
  try {
    $r = Invoke-WebRequest -Uri "$Url/mock/health" -UseBasicParsing -TimeoutSec 5
    if ($r.StatusCode -eq 200) { return [string]$r.Content }
  } catch { }
  return $null
}

function Show-Log {
  if (Test-Path $logPath) {
    Write-Host "--- $Log (last 60 lines)"
    Get-Content $logPath -Tail 60
  }
}

if ($Start) {
  $dart = Join-Path $env:FLUTTER_ROOT 'bin\cache\dart-sdk\bin\dart.exe'
  if (-not (Test-Path $dart)) { $dart = (Get-Command dart -ErrorAction Stop).Source }
  $dart = [System.IO.Path]::GetFullPath($dart)
  # cmd.exe writes the server output to the log file. The hidden window keeps
  # the server off the desktop screenshot and off this step's output pipe, so
  # the step can finish while the server keeps running for later steps.
  $cmdLine = "`"$dart`" run tools/mock_server/bin/mock_server.dart --port $Port --scale $Scale --media $Media > `"$logPath`" 2>&1"
  Start-Process -FilePath cmd.exe -ArgumentList "/d /s /c `"$cmdLine`"" `
    -WorkingDirectory (Get-Location).Path -WindowStyle Hidden
  $deadline = (Get-Date).AddSeconds($TimeoutSec)
  while (-not ($health = Get-Health)) {
    if ((Get-Date) -gt $deadline) {
      Show-Log
      throw "Mock server did not answer $Url/mock/health within $TimeoutSec s"
    }
    Start-Sleep -Seconds 2
  }
  Write-Host "Mock server is up at ${Url}: $health"
}

if ($Check) {
  $health = Get-Health
  if (-not $health) {
    Show-Log
    throw "Mock server is not answering at $Url/mock/health"
  }
  Write-Host "Mock server healthy: $health"
}
