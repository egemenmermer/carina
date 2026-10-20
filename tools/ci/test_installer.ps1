<#
.SYNOPSIS
  Installs Carina silently for the current user, checks what the installer
  created (files, Start menu shortcut and its AppUserModelID, uninstall entry,
  toast registration), then uninstalls it and checks the cleanup.
#>
param(
  [Parameter(Mandatory)] [string] $Installer,
  [string] $ExpectedVersion = '',
  [string] $AppUserModelId = 'Carina.Carina',
  [string] $LogDir = '.'
)
$ErrorActionPreference = 'Stop'

$appDir = Join-Path $env:LOCALAPPDATA 'Programs\Carina'
$exe = Join-Path $appDir 'carina.exe'
$startMenuLnk = Join-Path ([Environment]::GetFolderPath('Programs')) 'Carina.lnk'
$desktopLnk = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Carina.lnk'
$uninstallKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{45CF6915-952D-41BC-9EBE-F6B4918BFA7A}_is1'
$aumidKey = "HKCU:\Software\Classes\AppUserModelId\$AppUserModelId"
$installLog = Join-Path (Resolve-Path $LogDir).Path 'install.log'
$uninstallLog = Join-Path (Resolve-Path $LogDir).Path 'uninstall.log'

function Wait-Until([scriptblock] $Condition, [int] $TimeoutSec, [string] $What) {
  $deadline = (Get-Date).AddSeconds($TimeoutSec)
  while (-not (& $Condition)) {
    if ((Get-Date) -gt $deadline) { throw "Timed out after $TimeoutSec s waiting for: $What" }
    Start-Sleep -Milliseconds 500
  }
}

Write-Host "==> Installing $Installer"
$p = Start-Process -FilePath (Resolve-Path $Installer).Path -PassThru -Wait `
  -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- /LOG=`"$installLog`""
if ($p.ExitCode -ne 0) { throw "Installer exited with code $($p.ExitCode) (log: $installLog)" }

if (-not (Test-Path $exe)) { throw "carina.exe missing at $exe" }
$files = @(Get-ChildItem $appDir -Recurse -File)
Write-Host "Installed $($files.Count) files to $appDir"
foreach ($f in 'flutter_windows.dll', 'data\app.so', 'data\icudtl.dat', 'unins000.exe') {
  if (-not (Test-Path (Join-Path $appDir $f))) { throw "Missing $f in $appDir" }
}
$exeVersion = (Get-Item $exe).VersionInfo
Write-Host "carina.exe: $($exeVersion.ProductName) $($exeVersion.ProductVersion) - $($exeVersion.FileDescription)"

if (-not (Test-Path $startMenuLnk)) { throw "Start menu shortcut missing: $startMenuLnk" }
if (Test-Path $desktopLnk) { throw "Desktop shortcut was created although the task is unchecked by default" }
$shell = New-Object -ComObject Shell.Application
$lnkItem = $shell.Namespace((Split-Path $startMenuLnk)).ParseName((Split-Path $startMenuLnk -Leaf))
$lnkAumid = $lnkItem.ExtendedProperty('System.AppUserModel.ID')
$lnkTarget = (New-Object -ComObject WScript.Shell).CreateShortcut($startMenuLnk).TargetPath
Write-Host "Start menu shortcut -> $lnkTarget (AppUserModelID '$lnkAumid')"
if ($lnkTarget -ne $exe) { throw "Shortcut points to '$lnkTarget', expected '$exe'" }
if ($lnkAumid -ne $AppUserModelId) { throw "Shortcut AppUserModelID is '$lnkAumid', expected '$AppUserModelId'" }

$entry = Get-ItemProperty $uninstallKey
Write-Host "Uninstall entry: $($entry.DisplayName) $($entry.DisplayVersion), icon $($entry.DisplayIcon)"
if ($ExpectedVersion -and $entry.DisplayVersion -ne $ExpectedVersion) {
  throw "Uninstall entry version is '$($entry.DisplayVersion)', expected '$ExpectedVersion'"
}
$toast = Get-ItemProperty $aumidKey
Write-Host "Toast registration: DisplayName '$($toast.DisplayName)', IconUri '$($toast.IconUri)'"
if (-not (Test-Path $toast.IconUri)) { throw "Toast icon missing: $($toast.IconUri)" }

Write-Host '==> Uninstalling'
$uninstaller = Join-Path $appDir 'unins000.exe'
$p = Start-Process -FilePath $uninstaller -PassThru -Wait `
  -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /LOG=`"$uninstallLog`""
if ($p.ExitCode -ne 0) { throw "Uninstaller exited with code $($p.ExitCode) (log: $uninstallLog)" }
# The uninstaller re-launches itself from %TEMP%, so wait for the real work.
Wait-Until { -not (Test-Path $exe) -and -not (Test-Path $uninstallKey) } 120 'uninstall to finish'
Wait-Until { -not (Test-Path $appDir) } 30 "$appDir to be removed"
if (Test-Path $startMenuLnk) { throw "Start menu shortcut left behind: $startMenuLnk" }
if (Test-Path $aumidKey) { throw "Toast registration left behind: $aumidKey" }
Write-Host 'Install and uninstall OK.'
