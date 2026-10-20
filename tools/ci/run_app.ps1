<#
.SYNOPSIS
  Runs carina.exe (a GUI-subsystem app) with arguments, waits for it to exit
  and exits with the app's exit code. Kills the process tree on timeout.

.EXAMPLE
  & tools/ci/run_app.ps1 -Exe build\windows\x64\runner\Release\carina.exe `
      -Arguments '--smoke-test', '--mock-url', 'http://127.0.0.1:8787' -TimeoutSec 480
  if ($LASTEXITCODE -ne 0) { throw "smoke test failed" }
#>
param(
  [Parameter(Mandatory)] [string] $Exe,
  [string[]] $Arguments = @(),
  [int] $TimeoutSec = 300
)
$ErrorActionPreference = 'Stop'

$exePath = (Resolve-Path $Exe).Path
# Start-Process joins arguments verbatim, so quote the ones with spaces.
$quoted = foreach ($a in $Arguments) {
  if ($a -match '[\s"]') { '"' + ($a -replace '"', '\"') + '"' } else { $a }
}
$argLine = $quoted -join ' '
Write-Host "> $exePath $argLine"

$startArgs = @{ FilePath = $exePath; PassThru = $true; WorkingDirectory = (Get-Location).Path }
if ($argLine) { $startArgs.ArgumentList = $argLine }
$p = Start-Process @startArgs
$null = $p.Handle # keeps the handle open so ExitCode is readable after exit

if (-not $p.WaitForExit($TimeoutSec * 1000)) {
  $p.Kill($true)
  Write-Host "::error::$(Split-Path $exePath -Leaf) did not exit within $TimeoutSec s"
  exit 124
}
$p.WaitForExit()
Write-Host "Exit code: $($p.ExitCode)"
exit $p.ExitCode
